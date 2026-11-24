# V0.2.0 渲染与兼容性测试

## 验证环境

Debian 13 x86_64，AMD EPYC 9V74 虚拟机，3 个逻辑核心，没有硬件 GPU 设备。Godot 4.7.2 稳定版，Blender 4.3.2，Android Build Tools 36.0.0，JDK 17。桌面使用 Mesa llvmpipe 的 OpenGL 4.5 和 Vulkan 1.4.305；浏览器使用 Chromium 软件 WebGL。没有连接 ARM64 Android 设备。

## 已执行

| 范围 | 结果 |
| --- | --- |
| 核心回归 | 39 项检查，包括步行、跳跃、视角、同按两个触点、车辆和手刹、驾车穿越延安东路隧道、轮渡、导航、NPC、降雨、存档和恢复。新增摄影进入及退出恢复断言。 |
| 无头稳定性 | 36,000 个物理模拟 tick、24 次跨区跳转和七种天气。最高常驻约 40 个地块。峰值 130.47 MiB 为 Godot 进程的无头静态内存样本，无移动显存数据。 |
| 渲染 | 通过 Compatibility 生成十张 1,280×720 实际游戏画面。Linux Vulkan Mobile 额外渲染三张 800×450 样本，包含东方明珠、外滩雨夜和黄浦江镜像。 |
| 摄影导出 | 在 Forward+ 场景调用游戏的独立摄影保存流程，读回真正的 1,920×1,080 PNG。退出后还原游戏画质。 |
| 前后对照 | 使用同一脚本和机位重新运行 V0.1，比较东方明珠街道、外滩雨夜驾驶和车辆近景。 |
| Web | Chromium 启动并接受游戏输入。缓存完成后断网重开通过。 |
| Android 静态签名 | apksigner 验证 v2/v3。与 V0.1 使用同一证书，包名 com.shanghai.openworld，versionCode 2，minSdk 24，targetSdk 36。 |
| Android 结构 | aapt 解析清单与 APK。声明 Mobile、可选 Vulkan、横屏、ARM64，权限仅振动。检查 141 个地图场景、ETC2 纹理、16 KiB ELF、ZIP CRC 和 SHA256。 |
| 导出器修正 | Godot 4.7 的预编译 APK 导出曾写入字符串型 Vulkan 可选声明。tools/fix_android_manifest.py 在最终签名之前将属性写为 Android 所需的布尔与整数类型。复测两项 features 均显示为 optional。 |

部分分支使用录制脚本推动车辆，再用暂停锁定镜头。图片由上述 Godot 场景产生。原始每镜头数据包含引擎报告的 Draw Calls、primitive 数、CPU/GPU 时间与内存，位于截图压缩包的 metrics.json。软件渲染下的 GPU 时间实际对应 CPU 实现上的图形工作，不能外推手机帧率。各渲染器和画质的采样点用于故障排查。

## 待实机和进一步验证

- ARM64 Android 安装、V0.1 覆盖安装与存档预留验证，原证书、包名和存档格式已保持一致。
- 骁龙 8s Gen 4 及其他设备的性能、温升、纹理压缩兼容、驱动回退、后台恢复、持续雨夜驾驶、输入延时和低内存压力。
- 量化 Mobile 镜像缓冲、局部探针、纹理档位和动态降分辨率的设备开销。当前将高质量镜像限定为极高及电影档，在近岸限频更新。
- 当前画面仍可辨识程序化建筑和人物分件。完整阴影光照贴图、手工历史立面、蒙皮角色及车内动画属于后续制作。

APK 校验值见 [SHA256SUMS](builds/v0.2/android/SHA256SUMS)。渲染差异和选项见 [渲染说明](docs/RENDERING-V0.2.md)。
