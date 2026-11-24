#!/usr/bin/env python3
"""Repair Godot 4.7's prebuilt-template Vulkan feature attributes before signing.

The exporter encodes the two new uses-feature values as TYPE_STRING and omits
the framework ID for android:version. Compile-equivalent primitive values let
Android's PackageParser and both SDK badging tools read the optional features.
"""
import argparse
import struct
from zipfile import ZipFile

NO_STRING = 0xFFFFFFFF
ANDROID_NS = 'http://schemas.android.com/apk/res/android'
ATTRS = {'required': 16843406, 'version': 16844057}


def u16(buf, offset):
    return struct.unpack_from('<H', buf, offset)[0]


def u32(buf, offset):
    return struct.unpack_from('<I', buf, offset)[0]


def length8(buf, offset):
    first = buf[offset]
    return ((first & 127) << 8 | buf[offset+1], offset+2) if first & 128 else (first, offset+1)


def strings(pool):
    start = u32(pool, 20)
    header_size = u16(pool, 2)
    utf8 = bool(u32(pool, 16) & 0x100)
    result = []
    for index in range(u32(pool, 8)):
        pos = start + u32(pool, header_size + index*4)
        if utf8:
            _, size_pos = length8(pool, pos)
            size, pos = length8(pool, size_pos)
            result.append(pool[pos:pos+size].decode('utf-8'))
        else:
            size = u16(pool, pos)
            pos += 2
            if size & 0x8000:
                size = ((size & 0x7fff) << 16) | u16(pool, pos)
                pos += 2
            result.append(pool[pos:pos+size*2].decode('utf-16-le'))
    return result


def type_features(xml):
    assert u16(xml, 0) == 3 and u32(xml, 4) == len(xml), 'Unexpected binary XML envelope'
    start = u16(xml, 2)
    chunks = []
    pos = start
    while pos < len(xml):
        header = u16(xml, pos+2)
        length = u32(xml, pos+4)
        assert 8 <= header <= length and pos + length <= len(xml)
        chunks.append(bytearray(xml[pos:pos+length]))
        pos += length
    assert pos == len(xml)
    pool = strings(next(chunk for chunk in chunks if u16(chunk, 0) == 1))
    resource_map = next(i for i, chunk in enumerate(chunks) if u16(chunk, 0) == 0x180)
    chunk = chunks[resource_map]
    names = list(struct.unpack_from('<' + 'I'*((len(chunk)-8)//4), chunk, 8))
    seen = set()
    for chunk in chunks:
        if u16(chunk, 0) != 0x102 or pool[u32(chunk, 20)] != 'uses-feature':
            continue
        first = 16 + u16(chunk, 24)
        stride = u16(chunk, 26)
        entries = {}
        for i in range(u16(chunk, 28)):
            at = first + i*stride
            namespace, name, raw = struct.unpack_from('<III', chunk, at)
            if namespace == NO_STRING or pool[namespace] != ANDROID_NS:
                continue
            entries[pool[name]] = (at, name, raw)
        if 'name' not in entries:
            continue
        at, _, raw = entries['name']
        name = pool[raw if raw != NO_STRING else u32(chunk, at+16)]
        if name not in ('android.hardware.vulkan.level', 'android.hardware.vulkan.version'):
            continue
        seen.add(name)
        for attr, value_type in [('required', 0x12), ('version', 0x11 if name.endswith('.version') else 0x10)]:
            offset, label, raw = entries[attr]
            assert u16(chunk, offset+12) == 8
            data = u32(chunk, offset+16)
            if chunk[offset+15] == 3:
                incoming = pool[raw if raw != NO_STRING else data]
                if attr == 'required':
                    assert incoming in ('false','true')
                    data = NO_STRING if incoming == 'true' else 0
                else:
                    data = int(incoming, 0)
            struct.pack_into('<I', chunk, offset+8, NO_STRING)
            struct.pack_into('<HBBI', chunk, offset+12, 8, 0, value_type, data)
            if label >= len(names):
                names += [0]*(label - len(names)+1)
            assert names[label] in (0, ATTRS[attr]), 'Unexpected framework resource ID'
            names[label] = ATTRS[attr]
    assert seen == {'android.hardware.vulkan.level', 'android.hardware.vulkan.version'}
    mapping = struct.pack('<HHI',0x180,8,8+4*len(names)) + struct.pack('<'+'I'*len(names),*names)
    chunks[resource_map] = mapping
    data = bytearray(xml[:start]) + b''.join(chunks)
    struct.pack_into('<I',data,4,len(data))
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input')
    parser.add_argument('output')
    args = parser.parse_args()
    with ZipFile(args.input) as source, ZipFile(args.output,'w') as target:
        for item in source.infolist():
            data = source.read(item)
            if item.filename == 'AndroidManifest.xml':
                data = type_features(data)
            target.writestr(item,data)


if __name__ == '__main__':
    main()
