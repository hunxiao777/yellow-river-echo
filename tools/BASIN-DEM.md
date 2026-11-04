# 全流域地形

`bake_basin_dem.py` 从 AWS Terrain Tiles / Mapzen Terrarium 公开高程瓦片重采样；经纬度范围 E95.6–120.4、N32.8–42.0。当前 Z7 共 50 瓦片，输出 257×129 离线高程网格，采样高程 0–5448 米。缓存和来源记录在 `.tmp/basin-dem/`，数据产物 `BasinElevation.ets` 随应用编译，不要求用户联网。

渲染采用原生 Canvas 高程浮雕，地形、河流、点击命中共用高程投影；垂直高度作视觉夸张。它不是可旋转的 WebGL 三维地球，也不是照片或高精度地形测绘。原有干流/支流仍是人工示意折线，尚未替换为精确河道数据。

壶口和上游峡谷的水帘、水沫、水雾采用艺术化粒子表现，不代表各站点实际泄洪、水位或统一的天然瀑布类型。水效继续服从应用流动/静水/关闭档位。旧公式生成山峰已移除。

数据来源与授权归属：
- https://registry.opendata.aws/terrain-tiles/
- https://github.com/tilezen/joerd/blob/master/docs/attribution.md
- 参考中国区域对应的 SRTM/GMTED 来源归属，不应将全部聚合数据统一宣称为公有领域。

编译记录：`.tmp/basin-dem-build.log`。
