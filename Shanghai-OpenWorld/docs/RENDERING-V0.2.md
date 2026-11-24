# V0.2 渲染系统

## 路径

| 平台 | 启动路径 | 画质功能 |
| --- | --- | --- |
| Android | Vulkan Mobile；项目启用 Compatibility 回退 | PBR、ACES、HDR 天空、动态太阳、可选 MSAA、动态渲染比例、局部 ReflectionProbe 和限频低分辨率江面反射 |
| 桌面开发 | Forward+ | 同一世界资源，高清起可启用 SSAO，电影档可启用 SSR；支持镜头景深 |
| Web 与 Compatibility | OpenGL / WebGL 2 | 同一 PBR 源码、HDR 天空着色、预计算接触暗角、局部光池和水面着色；以环境天空作为探针替代 |

开机后的实际渲染器显示在 F3 性能面板。Android APK 的 Manifest 记录 Mobile，Vulkan 声明为可选。真实 Android 驱动回退和热性能尚待设备验证。仅在 Forward+ 分支开启 SSAO、SSR 和 FXAA 后处理，桌面验证不代表手机已有这些效果。

## 场景和材质

- systems/quality.gd 管理流畅、均衡、高清、极高和电影五档。渲染比例在帧时间持续超过预算时逐步下调，增加连续压力后缩短分块与视距。按档控制几何 LOD、植被和阴影，可独立调整画质设置。
- tools/generate_map.py 和 tools/bake_map.gd 保留原 OSM 地形、街道与碰撞，在三个核心街区增设地面设施、服从道路方向的斑马线、近距离立面和屋顶细节。地块分别批量渲染建筑、道路、植被、积雨光池与预计算的墙脚遮蔽。
- assets/textures/pbr 保存 512 和 1,024 像素材质。线性 RMA 贴图储存粗糙度、AO 和位移，金属表面的蓝通道储存金属度。位移主要用于湿地表及微结构调制。Godot 生成 Mipmap 以及桌面和 Android 的 GPU 压缩版本。材质读取真实纹理，并用程序化低频变化减轻重复。
- tools/blender_landmarks.py 在 Blender 4.3 中生成东方明珠、上海中心、金茂、环球金融中心、国际会议中心、和平饭店、江海关和外白渡桥的近、远两套 GLB。基于真实高度和主要结构，建模细节继续采用原创近似。
- shaders/city.gdshader 区分地面、柏油、步道、标线、建筑和远景。现代幕墙、住宅和历史建筑的窗格尺度、窗框、亮灯颜色及密度不同。动态湿润粗糙度和纹理凹凸在无雨、降雨和水坑间连续过渡。
- systems/climate.gd 按上海纬度近似得出太阳高度和方位。程序云层结合 CC0 HDRI 辐射，环境和天空随时间变化。夜间用窄范围灯池与可复用路灯代替大批独立灯源。地标和窗户通过发光材质着色，暴雨或驾驶时联动车身和轮胎效果。
- 黄浦江有多组方向法线、岸边衰减、小尺度降雨波纹及渡轮尾迹。常规路径通过天空辐射和沿地标方向的倒影近似，高质量路径在岸边可限频渲染 416×236 镜像视图。反射摄像机排除水面与地面层，避免递归。
- 车辆几何包含轮拱、车灯、轮毂、后视镜、车牌、仪表区、雨刷及多层车漆。普通交通使用低细节模型。人物延续原骨骼与玩法，重做面部、服装和步态过渡。

## 摄影

从暂停菜单进入。暂停角色、车辆、行人及任务。桌面按右键拖动视角，WASD 加 Q/E 移动；触屏可拖动镜头并使用升降与推拉。调节 FOV、时间、天气、曝光和色调。支持对应渲染器的景深。截图由共享游戏世界的独立摄像机真正渲染为 1,920×1,080，桌面可选 2,560×1,440。退出时恢复时间、天气、曝光、相机和原画质。照片写入应用的 user://photos。

## 当前边界

建筑主体仍有程序化立面，角色为分件骨骼，服装蒙皮、脚部 IK 和可见连贯的上下车全身动画需要进一步制作。没有给整座城市生成多次反弹的光照贴图，当前使用环境辐射、墙脚 AO 和光池近似。场景未启用全局体积雾、运动模糊和镜头眩光，驾驶默认保持清晰。移动端额外反射、探针时延、内存压力及自动调档需结合实机优化。

## 重建视效资源

源包已携带导入资源的源图、GLB 及烘焙地块。重建地标和地块可运行以下命令。

    blender --background --python tools/blender_landmarks.py
    python3 tools/create_foliage.py
    tools/godot.sh --headless --editor --import
    python3 tools/texture_import_v02.py
    tools/godot.sh --headless --editor --import
    tools/rebuild_map.sh

如需重新生成 PBR 通道，从许可证清单中的 ambientCG 资产下载各自的 1K JPG ZIP，按资产 ID 命名并保存到 tools/downloads/v2。将 Poly Haven 的 1K EXR 以 industrial_sunset_02.exr 命名放入同目录，再运行 python3 tools/prepare_pbr.py。Android 重新签名使用工作区的原始密钥，流程见 [签名说明](SIGNING.md)。
