# V0.4 陆家嘴写实资产

示范区以环桥为中心，主要街景资产覆盖其周边约 200 × 200 米。东方明珠塔基是向北连接的独立地标。地图交互、道路图和原存档格式沿用原工程。

| 资产 | 近景面数 | 交通用面数 |
| --- | ---: | ---: |
| 轿车与出租车车身 | 67,702 | 7,658 |
| SUV | 68,061 | 10,101 |
| 跑车 | 73,434 | 9,230 |
| 公交车 | 34,909 | 11,435 |
| 主角 | 41,586 | — |
| 示范区行人 | 18,802 | — |
| 单棵近景树 | 8,612 | 远处使用项目原有的树冠和树干资源 |

## 模型与地图

车辆的 GLB 包含原模型的曲面、轮胎及轮毂。运行时载入独立交通 LOD，玩家车轮独立转动。车灯和车漆在项目中可控。原输入、车辆碰撞、悬挂、损坏数值和驾驶视角保留。以上/下车仍由既有交互处理，专用进出车舱动画和各车型的雨刷运动需要继续制作。

主角的皮肤和衣服模型绑定到导入骨骼，站立、走跑、跳跃和下蹲由 AnimationPlayer 混合。转身由动画和角色朝向控制配合。没有做基于路面的脚部 IK。示范区范围外的行人仍使用 V0.2 资源。

陆家嘴环桥使用 OSM 闭合中心线和五条接入线位。新桥面、玻璃栏杆、桥墩、楼梯和照明为原创 Blender 网格。台阶下使用连续斜坡碰撞，减少行走卡顿。实测了西北一条接入线。其他支路、外接连廊和扶梯驱动还有进一步工作。

区内六个 OSM 建筑外轮廓使用几何化层间带、立柱、内嵌玻璃和商业首层。实楼外立面细节仍有近似。东方明珠新增塔基店面玻璃、入口雨棚和结构细节，沿用项目的上海地标轮廓模型。上海中心、金茂、环球金融中心与外滩重点建筑保留现有模型，待逐栋重建。

路面及铺砖使用网站原始 1K 扫描贴图，保留旧项目的湿路材质路径。树、路灯、长椅和花槽来自 Poly Haven，以实例化方式批量放置。部分其它街具和远处资产仍沿用旧模型，路面高度和排水设施还有细化空间。

## 重制命令

- `python3 tools/fetch_polyhaven_v04.py` 下载街景数据并核对上游哈希。
- `tools/prepare_street_props_v04.sh` 使用 glTF Transform 4.5.1 和已下载的街具源文件制作 GLB。
- `blender -b -P tools/blender_skywalk_v04.py` 根据项目自带 OSM 重建环桥。
- `blender -b -P tools/blender_landmarks.py -- pearl` 重建东方明珠两个 LOD。
- `tools/rebuild_map.sh` 先重建 OSM 地图，再烘焙分块、立面、街具和碰撞。需要 X11/Wayland 或 xvfb-run。Godot 的无渲染后端不能保存 MultiMesh 实例缓冲区。
- `python3 tools/import_v04_textures.py` 更新新贴图的 Mipmap 和显存压缩选项，再由 Godot 编辑器导入。
- 摄像机和灯光在 `scripts/main.gd` 与 `systems/climate.gd`。摄影模式和第一人称保留。

模型已打包在工程中，可以离线运行和出包。更新车辆资产时，宝马使用 `tools/prepare_car_v04.py`，轿车和 SUV 使用 `tools/prepare_road_cars_v04.py`。公交先用 glTF Transform 解压和反量化，然后用 `tools/prepare_bus_v04.py` 和 Khronos KTX-Software 4.4.2 转换贴图。人物导出参数在 `tools/lujiazui_protagonist.json`，使用 Ara 3D Gen 的 medium 档。近景行人使用其 Detective low 档。
