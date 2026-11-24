#!/usr/bin/env python3
"""Validate the self-contained ARM64 Android export with Google's tools."""
import hashlib
import io
import os
import re
import struct
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile

root = Path(__file__).resolve().parents[1]
apk = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'builds/v0.2/android/Shanghai-OpenWorld-v0.2.0-arm64.apk'
sdk = Path(os.environ.get('ANDROID_SDK_ROOT', root / 'tools/android-sdk'))
tools = Path(os.environ.get('ANDROID_BUILD_TOOLS', sdk / 'build-tools/36.0.0'))

def query(tool, *args):
    return subprocess.check_output([str(tools / tool), *args], text=True)

signing = query('apksigner', 'verify', '--verbose', '--print-certs', str(apk))
assert 'APK Signature Scheme v2): true' in signing
assert 'APK Signature Scheme v3): true' in signing
certificate = (root / 'docs/android-release-certificate.sha256').read_text().strip()
assert f'certificate SHA-256 digest: {certificate}' in signing, 'V0.1 release certificate mismatch'
badging = query('aapt', 'dump', 'badging', str(apk))
assert "name='com.shanghai.openworld' versionCode='2' versionName='0.2.0'" in badging
assert "application-label:'魔都：自由都市'" in badging
assert "targetSdkVersion:'36'" in badging and "sdkVersion:'24'" in badging
assert "native-code: 'arm64-v8a'" in badging
permissions = re.findall(r"uses-permission(?:-sdk-23)?: name='([^']+)'", badging)
assert permissions == ['android.permission.VIBRATE'], permissions
manifest = query('aapt', 'dump', 'xmltree', str(apk), 'AndroidManifest.xml')
assert re.search(r'screenOrientation.*=\(type 0x10\)(?:0x6|0xb)\b', manifest)
with ZipFile(apk) as pack:
    assert pack.testzip() is None
    names = set(pack.namelist())
    for required in ['AndroidManifest.xml', 'classes.dex', 'assets/project.binary',
                     'assets/maps/city.json', 'assets/assets.sparsepck',
                     'assets/maps/chunks/skyline.scn']:
        assert required in names, required
    chunks = [name for name in names if name.startswith('assets/maps/chunks/') and name.endswith('.scn')]
    assert len(chunks) == 141, len(chunks)
    assert any(name.endswith('.etc2.ctex') and 'asphalt_albedo' in name for name in names)
    assert not any(name.endswith(('.p12','.jks','.keystore','/password')) for name in names)
    assert re.search(r'org\.godotengine\.rendering\.method[^\n]*\n\s+A: android:value[^=]*="mobile"', manifest)
    assert "uses-feature-not-required: name='android.hardware.vulkan.level'" in badging
    assert "uses-feature-not-required: name='android.hardware.vulkan.version'" in badging
    native = sorted(name for name in names if name.startswith('lib/') and name.endswith('.so'))
    assert native and all(lib.startswith('lib/arm64-v8a/') for lib in native)
    for lib in native:
        data = io.BytesIO(pack.read(lib))
        header = data.read(64)
        assert header[:6] == b'\x7fELF\x02\x01'
        assert struct.unpack_from('<H', header, 18)[0] == 183
        program_headers_at = struct.unpack_from('<Q', header, 32)[0]
        entry_size, entry_count = struct.unpack_from('<HH', header, 54)
        loads = []
        for i in range(entry_count):
            data.seek(program_headers_at + i * entry_size)
            segment = data.read(entry_size)
            if struct.unpack_from('<I', segment)[0] == 1:
                loads.append(struct.unpack_from('<Q', segment, 48)[0])
        assert loads and all(align >= 16384 for align in loads), (lib, loads)
        print(f'PASS {lib}: ARM64 and 16 KiB ELF segment alignment')
with apk.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
print('PASS original release signature, Android 16 target, landscape, permission allowlist, renderer routes, ETC2 texture and 141 city scenes')
print(f'SHA256 {digest}')
