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
