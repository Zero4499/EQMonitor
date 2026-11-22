/// QuakePush 的地震底图：USGS 官网同款的 USGS Topo 栅格瓦片
/// （National Map，免密钥，不需要 Mapbox/MapLibre 令牌）。
///
/// 样式直接在本地拼成 JSON 交给 MapLibre：一个栅格源 + 背景色，
/// 不再走 OpenFreeMap 矢量样式（那套自带多语地名标注，低倍镜下会把
/// 各国文字叠在一起，也有地图口径问题）。
const _usgsTopoTile =
    'https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/{z}/{y}/{x}';

const usgsBasemapStyleJson = '''
{
  "version": 8,
  "sources": {
    "usgs-topo": {
      "type": "raster",
      "tiles": ["$_usgsTopoTile"],
      "tileSize": 256,
      "maxZoom": 16,
      "attribution": "USGS National Map"
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": { "background-color": "#E7E2D6" }
    },
    {
      "id": "usgs-topo",
      "type": "raster",
      "source": "usgs-topo"
    }
  ]
}
''';

String quakeBasemapStyleString() => usgsBasemapStyleJson;

/// 地质板块边界（USGS Plate_Boundaries_GHSC，1175 条线），随包内置，离线可用。
const plateBoundaryAsset = 'assets/plate_boundaries.json';
const plateBoundarySourceId = 'quakepush-plate-boundaries';
const plateBoundaryLayerId = 'quakepush-plate-boundaries-line';
