# Android ARM64 APK 下载

[直接下载完整 APK](https://media.githubusercontent.com/media/forlorinna/shanghai/main/Shanghai-OpenWorld/builds/v0.4/android/Shanghai-OpenWorld-v0.4.0-arm64.apk)（约 151 MiB）。

## 分卷下载

如需分卷，下载以下六个文件到同一个目录。

- [APK 第 1 部分](Shanghai-OpenWorld-v0.4.0-arm64.apk.part01?raw=true)
- [APK 第 2 部分](Shanghai-OpenWorld-v0.4.0-arm64.apk.part02?raw=true)
- [APK 第 3 部分](Shanghai-OpenWorld-v0.4.0-arm64.apk.part03?raw=true)
- [APK 第 4 部分](Shanghai-OpenWorld-v0.4.0-arm64.apk.part04?raw=true)
- [合并脚本](assemble-apk.py?raw=true)
- [SHA256 校验文件](SHA256SUMS?raw=true)

在该目录运行 `python assemble-apk.py`。脚本会合并四部分并核对 SHA256，然后生成原始签名的 `Shanghai-OpenWorld-v0.4.0-arm64.apk`。需要 Python 3.8 或更新版本。

应用沿用原包名 `com.shanghai.openworld` 和原签名，版本号为 4。真机覆盖安装仍待验证。
