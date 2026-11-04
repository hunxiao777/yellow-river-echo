# 黄河流域离线河网

数据：HydroRIVERS version 1，Lehner, B. & Grill, G. (2013), Global river hydrography and network routing, Hydrological Processes 27(15), 2171–2186, https://doi.org/10.1002/hyp.9740 。

官方说明与许可：https://www.hydrosheds.org/products/hydrorivers 。数据按 HydroSHEDS 许可使用，保留来源署名。官方数据基于 15 角秒水文网格；不代表每条现实中的季节性小沟渠，也不作为导航或测绘依据。

提取脚本：`tools/bake_basin_network.py`。亚洲公开 ArcGIS 镜像中以 `MAIN_RIV=40417973` 选择黄河连通流域，共 37,229 个河段。干流从入海口逆向沿最大上游距离追踪，支流保留 35,689 个河段。按 Strahler 河流级别显示；全流域显示三级及以上，放大逐步显示二级、一级。这里的河段数不是命名河流条数。

资源：`entry/src/main/resources/rawfile/basin-network.json`，约 3.2 MB，随应用离线打包。河线做轻量折线简化，保留每段的端点。地图使用统一平面经纬度投影，没有 DEM、高度偏移、山峰或沙盘底座。湖面轮廓与城市/遗址位置仍为导览示意。

五处半透明标注：青海源区、兰州、河套平原、壶口瀑布、东营入海口。源区与平原是区域性提示点，非区域边界。细引线指向地图中的对应经纬位置。遗址打卡数据与原来的二十处遗址不变。

渲染：按河级预建原生 Path2D；静态河网缓存，金色干流与点击水花独立绘制。地图平移、缩放、预设切换、遗址点选及原水效设置继续使用原有交互。
