# 数据与素材来源

| 使用内容 | 来源和许可 |
| --- | --- |
| 上海地理快照和由它处理出的可重用地图数据 | © OpenStreetMap contributors，Open Database License 1.0。源快照在 maps/source/shanghai.osm，生成的可重用地图在 maps/city.json 与 maps/source/chunks/，保留数据许可和署名。菜单、地图和关于页显示署名。[OSM 版权](https://www.openstreetmap.org/copyright) |
| 简体中文字体 | Noto Sans CJK SC Regular，SIL Open Font License 1.1。使用系统字体集合中的简中字体生成字形子集，上游版权和完整许可随附于 assets/textures/Noto-LICENSE.txt。[Noto CJK](https://github.com/notofonts/noto-cjk) |
| Godot 4.7.2 | Godot Engine MIT 源代码许可，采用官方引擎构建和导出模板。[Godot 许可](https://godotengine.org/license/) · [官方构建](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) |
| 地图工具 | Shapely 2.1.2，BSD-3-Clause，通过 Shapely 使用 GEOS；Pillow 用于离线图像生成。二者为构建期依赖。[Shapely](https://github.com/shapely/shapely) · [Pillow](https://github.com/python-pillow/Pillow) |
| Android 工具 | Google Android SDK Build Tools 36.0.0、Platform 36、platform-tools 官方分发，仅用于本地构建及检查。[Android SDK](https://developer.android.com/tools/releases/build-tools) |
| Java | Eclipse Temurin JDK 17.0.17+10，官方 OpenJDK 发行版，仅用于本地打包。[Eclipse Temurin](https://adoptium.net/) |

地图通过 OpenStreetMap API 0.6 的 /map 接口下载，边界为 121.480,31.225,121.515,31.247。采集日期为 2026-11-24。快照 SHA256 为 e33d40c56e526bda7febdc4155fc2588cd49751ee62e2ae1331598f4e2680232。

角色、车辆、地标网格、界面、图标、启动画面、材质与合成音频由此工程生成。游戏未引入 GTA 代码、美术、音乐或其它 GTA 专有素材。地图、音画资源随游戏打包，原始地图和字体许可证随源码包交付。

## V0.2 纹理和建模参考

以下实际使用的 ambientCG 纹理采用 CC0 1.0。工程仅从发行 ZIP 提取图像，未载入其中的 Blender、USD 或 Godot 材质文件。各表面原图经缩放和通道打包，布料提高了基底亮度以供服装配色。相关脚本为 tools/prepare_pbr.py。[ambientCG 许可](https://docs.ambientcg.com/license/)

| 材质用途 | 上游资产 |
| --- | --- |
| 沥青、混凝土和人行铺砖 | [Asphalt012](https://ambientcg.com/view?id=Asphalt012)、[Concrete034](https://ambientcg.com/view?id=Concrete034)、[PavingStones036](https://ambientcg.com/view?id=PavingStones036) |
| 金属、木材、草地和布料 | [Metal032](https://ambientcg.com/view?id=Metal032)、[Wood051](https://ambientcg.com/view?id=Wood051)、[Grass001](https://ambientcg.com/view?id=Grass001)、[Fabric030](https://ambientcg.com/view?id=Fabric030) |
| 1K HDR 辐射环境 | [Poly Haven Industrial Sunset 02](https://polyhaven.com/a/industrial_sunset_02)，CC0 1.0。[Poly Haven 资产许可](https://polyhaven.com/license) |

V0.2 的 Blender 地标、车辆车身、角色几何、叶片图集和 Shader 源码为项目原创。公开建筑资料用于核对比例和辨识特征，资料中的图片未打包。[上海市政府东方明珠资料](https://english.shanghai.gov.cn/en-ScenicSpots/20231205/19a5f5184eca45728fd57a4d4c8efc61.html) · [Gensler 上海中心大厦立面资料](https://www.gensler.com/uploads/document/242/file/Shanghai_Tower_Facade_Design_Process_11_10_2011.pdf)

金茂大厦的高度和退台节奏参考设计团队的项目资料。[SOM Jinmao Tower](https://www.som.com/projects/jin-mao-tower/)

## V0.4 写实资产

V0.4 角色、车辆及一部分街景采用独立授权资产。各资源作者、上游链接、修改内容和许可证随 APK 的 [V04-ASSET-CREDITS.txt](assets/licenses/V04-ASSET-CREDITS.txt) 发布。完整签名私钥不属于源码交付物。

| 内容 | 来源 |
| --- | --- |
| 跑车 | 𝙎𝙍𝙏 𝙋𝙚𝙧𝙛𝙤𝙢𝙖𝙣𝙘𝙚™，CC BY 4.0，经授权标注的镜像取得 GLB，源文件 SHA256 与镜像记录一致。[作品](https://sketchfab.com/3d-models/bmw-m4-competition-m-package-5c0a2dafb1ad408d9fc9eeef9aee531b) · [镜像署名和哈希](https://github.com/lukaizj/car-mod-saas/blob/main/public/models/ATTRIBUTION.md) |
| 轿车、出租车 | RBLXSupercars，存档发布者 brandonleong28，CC BY 4.0，采用原 GLB 内嵌的许可及镜像署名。出租车使用相同车身与换色及顶灯。[源文件说明](https://github.com/aditano/tesla-studio/blob/main/public/models/highland/CREDITS.md) |
| SUV | BloxBloger，CC BY-NC 4.0。保留此限制，适用于本项目的个人非商业用途。[模型](https://sketchfab.com/3d-models/2025-tesla-model-y-619601e7800d418da5922c4fa7833f74) · [镜像署名](https://github.com/aditano/tesla-studio/blob/main/public/models/juniper/CREDITS.md) |
| 公交车 | tevy，CC0 1.0。解压网格并转换贴图后接入。[模型与许可](https://tevy.dev/models/city-bus) |
| 主角和示范区行人 | MakeHuman CC0 骨骼、人体、服装及贴图。Ara 3D Gen 导出器附带关键帧动画。[MakeHuman 素材授权](https://github.com/TuriaArt/3d-gen-TU/blob/main/scripts/ASSETS_LICENSE.txt) · [导出器许可](assets/licenses/ARA-3D-GEN-MIT.txt) |
| 道路、铺砖、树、路灯、长椅、花槽 | Poly Haven CC0 1.0 资源，具体名称见随包署名。[Poly Haven 许可](https://polyhaven.com/license) |
| 陆家嘴环桥 | OpenStreetMap 闭合中心线及五个出入口线位。钢结构截面、栏杆、铺装及台阶是按公开参考制作的项目近似模型。[OSM 环桥](https://www.openstreetmap.org/way/48876367) · [森大厦公开参考](https://www.mori.co.jp/_mori_assets/files/assets/3f2dbd9a710d4daaaa8451a27e512959/c1dd9429a89e4972a1471e26f019dfec/131029.pdf) |
