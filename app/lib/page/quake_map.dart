import 'dart:async';
import 'dart:convert';

import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/hook/use_map_operation_queue.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/provider/log/talker.dart';
import 'package:eqmonitor/core/util/map/map_geo_json_source_updater.dart';
import 'package:eqmonitor/core/util/map/quake_basemap.dart';
import 'package:eqmonitor/core/util/map/remove_map_style_resources.dart';
import 'package:eqmonitor/feature/map/ui/map_operation_queue_scope.dart';
import 'package:eqmonitor/feature/map/ui/maplibre_event_provider.dart';
import 'package:eqmonitor/page/event_detail_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maplibre/maplibre.dart';
import 'package:material_ui/material_ui.dart';

/// QuakePush 的地震底图：USGS 官网同款的 USGS Topo 栅格瓦片。
///
/// 样式由 [quakeBasemapStyleString] 在本地拼好（栅格源 + 背景色），
/// 地质板块边界由 [BasemapLayers] 在样式加载后画上去。
String quakeMapStyleString() => quakeBasemapStyleString();

/// 首页背后的全球地震地图：底图 + 震中圆点图层。
///
/// 与 EQMonitor 首页结构一致：地图铺满屏幕，内容卡片浮在上面。
/// 点一下震中点即可弹出该事件的详情（与列表里点条目是同一个弹窗）。
class QuakeMap extends HookConsumerWidget {
  const new({super.key, this.minMagnitude = 0});

  final double minMagnitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerRef = useRef<MapController?>(null);
    final language = ref.watch(appLocaleProvider).languageCode;
    final eventsAsync = ref.watch(usgsEventsProvider);
    final events = (eventsAsync.value ?? const <UsgsEvent>[])
        .where((e) => e.hasLocation)
        .where((e) => (e.magnitude ?? 0) >= minMagnitude)
        .toList(growable: false);
    final bulletins = (ref.watch(tsunamiBulletinsProvider).value ??
            const <TsunamiBulletin>[])
        .where((b) => b.hasLocation)
        .toList(growable: false);
    // 同一次事件常被两个海啸中心（PHEB / PAAQ）各发一条公报，坐标几乎重合。
    // 逐条渲染会让环和浪叠在一起、看着像一坨，所以地图上按位置合并。
    final mapBulletins = collapseBulletinsForMap(bulletins);
    // 海啸公报是异步拉下来的，首帧建图时多半还是空的，所以不能只在 initCenter
    // 里定视角：等数据到齐后再把相机移过去一次。默认的东亚视角里海啸发生在
    // 太平洋另一侧，用户得自己一路拖过去才能看见，等于没显示。
    final autoFocused = useRef(false);
    final primaryBulletin = _primaryBulletin(mapBulletins);
    final mapController = controllerRef.value;
    useEffect(() {
      if (autoFocused.value || mapController == null) {
        return null;
      }
      final lat = primaryBulletin?.latitude;
      final lon = primaryBulletin?.longitude;
      if (lat == null || lon == null) {
        return null;
      }
      autoFocused.value = true;
      unawaited(
        mapController.animateCamera(
          center: Geographic(lon: lon, lat: lat),
          zoom: 4.2,
        ),
      );
      return null;
    }, [mapController, primaryBulletin]);

    return MapOperationQueueScope(
      child: MapLibreEventProvider(
        child: Stack(
          children: [
            MapLibreMap(
              options: MapOptions(
                initCenter: const Geographic(lon: 120, lat: 22),
                initZoom: 2.4,
                initStyle: quakeMapStyleString(),
                maxZoom: 18,
                gestures: MapGestures.all(),
              ),
              onMapCreated: (controller) => controllerRef.value = controller,
              onEvent: (event) {
                MapLibreEventProvider.maybeOf(context)?.emit(event);
                if (event is MapEventClick) {
                  unawaited(
                    _onMapTap(
                      context: context,
                      controller: controllerRef.value,
                      click: event,
                      events: events,
                      bulletins: bulletins,
                      language: language,
                    ),
                  );
                }
              },
              children: [
                BasemapLayers(),
                EpicenterLayer(events: events, bulletinPoints: mapBulletins),
                TsunamiLayer(bulletins: mapBulletins),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 地图渲染用的海啸公报合并：同一次事件常由 PHEB / PAAQ 两个中心各发一条，
  /// 坐标差个零点几度（各自定了一次震中）。逐条渲染会叠出两层环、两层浪，
  /// 看上去像一坨点，所以把 0.2°（约 22 km）内的公报合并成一条，只留严重度
  /// 最高的一条，同级则保留更新更晚的那条。
  ///
  /// 这里用邻居距离而不是四舍五入的网格：网格聚类在 -13.55 / -13.45 这种刚好
  /// 骑在格线上的坐标上会漏合并，坐标再差一点就又叠出两个环。
  static List<TsunamiBulletin> collapseBulletinsForMap(
    List<TsunamiBulletin> source,
  ) {
    final merged = <TsunamiBulletin>[];
    for (final bulletin in source) {
      final latitude = bulletin.latitude;
      final longitude = bulletin.longitude;
      if (latitude == null || longitude == null) {
        continue;
      }
      var absorbed = false;
      for (var i = 0; i < merged.length; i++) {
        final kept = merged[i];
        final keptLatitude = kept.latitude;
        final keptLongitude = kept.longitude;
        if (keptLatitude == null || keptLongitude == null) {
          continue;
        }
        if ((latitude - keptLatitude).abs() > 0.2 ||
            (longitude - keptLongitude).abs() > 0.2) {
          continue;
        }
        final rank = _bulletinRank(bulletin);
        final keptRank = _bulletinRank(kept);
        if (rank > keptRank) {
          merged[i] = bulletin;
        } else if (rank == keptRank) {
          final updated = bulletin.updated;
          final keptUpdated = kept.updated;
          if (updated != null &&
              (keptUpdated == null || updated.isAfter(keptUpdated))) {
            merged[i] = bulletin;
          }
        }
        absorbed = true;
        break;
      }
      if (!absorbed) {
        merged.add(bulletin);
      }
    }
    return merged;
  }

  static int _bulletinRank(TsunamiBulletin bulletin) =>
      switch (bulletin.category) {
        .warning => 3,
        .advisory => 2,
        .info => 1,
        .unknown => 0,
      };

  /// 挑出最该被相机对准的那条海啸公报：严重度最高，同级取更新更晚的。
  static TsunamiBulletin? _primaryBulletin(List<TsunamiBulletin> bulletins) {
    if (bulletins.isEmpty) {
      return null;
    }
    var best = bulletins.first;
    for (final bulletin in bulletins.skip(1)) {
      final rank = _bulletinRank(bulletin);
      final bestRank = _bulletinRank(best);
      if (rank > bestRank) {
        best = bulletin;
        continue;
      }
      if (rank == bestRank) {
        final updated = bulletin.updated;
        final bestUpdated = best.updated;
        if (updated != null &&
            (bestUpdated == null || updated.isAfter(bestUpdated))) {
          best = bulletin;
        }
      }
    }
    return best;
  }


  /// 点击地图：先命中海啸标记，再命中震中圆点，弹出对应详情。
  Future<void> _onMapTap({
    required BuildContext context,
    required MapController? controller,
    required MapEventClick click,
    required List<UsgsEvent> events,
    required List<TsunamiBulletin> bulletins,
    required String language,
  }) async {
    if (controller == null) {
      return;
    }
    // 优先用渲染命中（点在标记范围内时最准）。
    final tsunamiHits = controller.featuresAtPoint(
      click.screenPoint,
      layerIds: [TsunamiLayer.layerId],
    );
    if (tsunamiHits.isNotEmpty) {
      final hitId = tsunamiHits.first.properties['id']?.toString();
      for (final bulletin in bulletins) {
        if (bulletin.id == hitId) {
          if (!context.mounted) return;
          await showTsunamiBulletinDetail(
            context,
            bulletin,
            language: language,
          );
          return;
        }
      }
    }
    if (events.isEmpty) {
      return;
    }
    final hits = controller.featuresAtPoint(
      click.screenPoint,
      layerIds: [EpicenterLayer.layerId],
    );
    UsgsEvent? target;
    if (hits.isNotEmpty) {
      final hitId = hits.first.properties['id']?.toString();
      for (final event in events) {
        if (event.id == hitId) {
          target = event;
          break;
        }
      }
    }
    // 兜底：按屏幕距离找最近的震中，指头落点偏一点也能选中。
    target ??= _nearestByScreen(controller, click.screenPoint, events);
    if (target == null || !context.mounted) {
      return;
    }
    await showUsgsEventDetail(context, target, language: language);
  }

  /// 找出离点击位置最近、且在 44 逻辑像素以内的震中。
  UsgsEvent? _nearestByScreen(
    MapController controller,
    Offset tap,
    List<UsgsEvent> events,
  ) {
    const maxDistance = 44.0;
    UsgsEvent? nearest;
    var nearestDistance = double.infinity;
    for (final event in events) {
      final Offset screen;
      try {
        screen = controller.toScreenLocation(
          Geographic(lon: event.longitude!, lat: event.latitude!),
        );
      } on Object {
        continue;
      }
      final distance = (screen - tap).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = event;
      }
    }
    return nearestDistance <= maxDistance ? nearest : null;
  }
}

/// 震中圆点图层（MapLibre circle 图层，按震级着色与缩放）。
class EpicenterLayer extends HookConsumerWidget {
  const new({
    required this.events,
    this.bulletinPoints = const [],
    super.key,
  });

  final List<UsgsEvent> events;

  /// 已经画了海啸公报的位置：这些震中不再画圆点，
  /// 否则大震级圆点会把海啸环整个盖住，看上去一堆点糊在一起。
  final List<TsunamiBulletin> bulletinPoints;

  static const sourceId = 'quakepush-usgs-epicenter';
  static const layerId = 'quakepush-usgs-epicenter-circle';
  static const _emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styleController = MapController.maybeOf(context)?.style;
    final enqueue = useMapOperationQueue();
    final lifecycleToken = useRef<Object?>(null);
    final initialization = useRef<Future<void>?>(null);
    final isLayerInitialized = useRef(false);
    final geoJsonUpdater = useMemoized(MapGeoJsonSourceUpdater.new);

    final geoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final event in events)
          if (!_coveredByBulletin(event))
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [event.longitude, event.latitude],
              },
              'properties': {
                'id': event.id,
                'magnitude': event.magnitude ?? 0.0,
                'tsunami': event.tsunami,
              },
            },
      ],
    });

    useEffect(() {
      if (styleController == null) {
        return null;
      }
      final token = Object();
      lifecycleToken.value = token;
      isLayerInitialized.value = false;
      geoJsonUpdater.reset();
      initialization.value = enqueue(() async {
        if (lifecycleToken.value != token) {
          return;
        }
        await styleController.addSource(
          const GeoJsonSource(id: sourceId, data: _emptyGeoJson),
        );
      });
      return () {
        if (lifecycleToken.value == token) {
          lifecycleToken.value = null;
        }
        geoJsonUpdater.reset();
        unawaited(
          enqueue(
            () => MapStyleResourceRemover.remove(
              styleController: styleController,
              layerIds: const [layerId],
              sourceIds: const [sourceId],
            ),
          ),
        );
      };
    }, [styleController]);

    useEffect(() {
      final token = lifecycleToken.value;
      final initialized = initialization.value;
      if (styleController == null || token == null || initialized == null) {
        return null;
      }
      unawaited(
        enqueue(() async {
          await initialized;
          if (lifecycleToken.value != token) {
            return;
          }
          if (isLayerInitialized.value) {
            await styleController.removeLayer(layerId);
          }
          if (lifecycleToken.value != token) {
            return;
          }
          await styleController.addLayer(_buildStyleLayer());
          isLayerInitialized.value = true;
        }),
      );
      return null;
    }, [styleController]);

    useEffect(() {
      final token = lifecycleToken.value;
      if (styleController == null || token == null) {
        return null;
      }
      unawaited(
        enqueue(
          () => geoJsonUpdater.update(
            styleController: styleController,
            sourceId: sourceId,
            geoJson: geoJson,
            initialization: initialization.value,
            isDisposed: () => lifecycleToken.value != token,
          ),
        ),
      );
      return null;
    }, [styleController, geoJson]);

    return const SizedBox.shrink();
  }

  /// 该震中是否已经有海啸公报标记（0.2° ≈ 22 km 内视为同一次事件）。
  ///
  /// 阈值不能太小：海啸公报的震中和 USGS 的震中本来就是两家机构各定一次的
  /// 位置，实测同一场 M6.5（瓦努阿图）纬度差 0.085°、经度差 0.03°，用 0.08°
  /// 卡的话就漏判，结果大震级实心圆把海啸环整个包住，又变回一坨。
  bool _coveredByBulletin(UsgsEvent event) {
    final lat = event.latitude;
    final lon = event.longitude;
    if (lat == null || lon == null) {
      return false;
    }
    for (final bulletin in bulletinPoints) {
      final bulletinLat = bulletin.latitude;
      final bulletinLon = bulletin.longitude;
      if (bulletinLat == null || bulletinLon == null) {
        continue;
      }
      if ((lat - bulletinLat).abs() <= 0.2 &&
          (lon - bulletinLon).abs() <= 0.2) {
        return true;
      }
    }
    return false;
  }

  CircleStyleLayer _buildStyleLayer() => const CircleStyleLayer(
    id: layerId,
    sourceId: sourceId,
    paint: {
      'circle-color': [
        'interpolate',
        ['linear'],
        ['get', 'magnitude'],
        0,
        '#8FA3B8',
        1.5,
        '#2FA8E1',
        3.5,
        '#22B07D',
        4.5,
        '#E0B32A',
        5.5,
        '#F5A623',
        6.5,
        '#F0603C',
        7.5,
        '#D62828',
      ],
      'circle-radius': [
        'interpolate',
        ['linear'],
        ['get', 'magnitude'],
        1,
        4,
        4,
        8,
        7,
        16,
      ],
      // 缩得很小时（全球视角）USGS all_day 里的 M1~M2 小震会在同一片区域
      // 糊成一大团，把海啸环和真正的大震盖住，所以按缩放分级只留够看的：
      // 全球视角 M4+，放到洲级 M2.5+，再放大才全部显示。
      'circle-opacity': [
        'case',
        ['>=', ['zoom'], 5.0], 0.85,
        ['>=', ['get', 'magnitude'], 4.0], 0.85,
        ['all', ['>=', ['zoom'], 3.2], ['>=', ['get', 'magnitude'], 2.5]], 0.85,
        0,
      ],
      // 带海啸标记（USGS tsunami=1）的地震加一圈细蓝边，与独立海啸公报区分。
      'circle-stroke-width': [
        'match',
        ['get', 'tsunami'],
        1,
        2.2,
        0.8,
      ],
      'circle-stroke-color': [
        'match',
        ['get', 'tsunami'],
        1,
        '#1565C0',
        '#FFFFFF',
      ],
    },
  );
}

/// 海啸公报标记图层：有坐标的公报落空心彩色圆环 + 中心白色波浪图标，与地震实心圆点区分。
class TsunamiLayer extends HookConsumerWidget {
  const TsunamiLayer({required this.bulletins, super.key});

  final List<TsunamiBulletin> bulletins;

  static const sourceId = 'quakepush-tsunami-marker';
  static const layerId = 'quakepush-tsunami-marker-circle';
  static const symbolLayerId = 'quakepush-tsunami-marker-symbol';
  static const _waveIconId = 'tsunami-wave';
  static const _emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styleController = MapController.maybeOf(context)?.style;
    final enqueue = useMapOperationQueue();
    final lifecycleToken = useRef<Object?>(null);
    final initialization = useRef<Future<void>?>(null);
    final isLayerInitialized = useRef(false);
    final geoJsonUpdater = useMemoized(MapGeoJsonSourceUpdater.new);

    final geoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final bulletin in bulletins)
          if (bulletin.hasLocation)
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [bulletin.longitude, bulletin.latitude],
              },
              'properties': {
                'id': bulletin.id,
                'category': bulletin.category.name,
              },
            },
      ],
    });

    useEffect(() {
      if (styleController == null) {
        return null;
      }
      final token = Object();
      lifecycleToken.value = token;
      isLayerInitialized.value = false;
      geoJsonUpdater.reset();
      initialization.value = enqueue(() async {
        if (lifecycleToken.value != token) {
          return;
        }
        await styleController.addImageFromCanvas(
          id: _waveIconId,
          width: 48,
          height: 48,
          painter: _paintWaveGlyph,
        );
        await styleController.addSource(
          const GeoJsonSource(id: sourceId, data: _emptyGeoJson),
        );
      });
      return () {
        geoJsonUpdater.reset();
        unawaited(
          enqueue(() => MapStyleResourceRemover.remove(
            styleController: styleController,
            layerIds: const [layerId, symbolLayerId],
            sourceIds: const [sourceId],
          )),
        );
      };
    }, [styleController]);

    useEffect(() {
      final token = lifecycleToken.value;
      final initialized = initialization.value;
      if (styleController == null || token == null || initialized == null) {
        return null;
      }
      unawaited(
        enqueue(() async {
          await initialized;
          if (lifecycleToken.value != token) {
            return;
          }
          if (isLayerInitialized.value) {
            await styleController.removeLayer(layerId);
            await styleController.removeLayer(symbolLayerId);
          }
          if (lifecycleToken.value != token) {
            return;
          }
          await styleController.addLayer(_buildRingLayer());
          await styleController.addLayer(_buildSymbolLayer());
          isLayerInitialized.value = true;
        }),
      );
      return null;
    }, [styleController]);

    useEffect(() {
      final token = lifecycleToken.value;
      if (styleController == null || token == null) {
        return null;
      }
      unawaited(
        enqueue(() => geoJsonUpdater.update(
          styleController: styleController,
          sourceId: sourceId,
          geoJson: geoJson,
          initialization: initialization.value,
          isDisposed: () => lifecycleToken.value != token,
        )),
      );
      return null;
    }, [styleController, geoJson]);

    return const SizedBox.shrink();
  }

  /// 海啸标记外圈：空心圆环（透明填充 + 分级色描边），与地震实心圆点区分。
  /// 尺寸刻意贴近中等震级圆点，避免海啸标记比震中更抢眼。
  CircleStyleLayer _buildRingLayer() => const CircleStyleLayer(
        id: layerId,
        sourceId: sourceId,
        paint: {
          'circle-color': 'rgba(0,0,0,0)',
          'circle-radius': 10,
          'circle-opacity': 0,
          'circle-stroke-width': 2.6,
          'circle-stroke-color': [
            'match',
            ['get', 'category'],
            'warning',
            '#D62828',
            'advisory',
            '#F5A623',
            '#2FA8E1',
          ],
        },
      );

  /// 海啸标记中心：白色三道波浪图标，紧贴圆环内径。
  SymbolStyleLayer _buildSymbolLayer() => const SymbolStyleLayer(
        id: symbolLayerId,
        sourceId: sourceId,
        layout: {
          'icon-image': _waveIconId,
          'icon-size': 0.3,
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
        },
      );

  /// 自绘波浪图标：三根粗描边正弦波，比 Material 的 waves 字形更实、更贴近圆环内径，
  /// 缩到 12dp 左右仍然认得出是浪。
  static void _paintWaveGlyph(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.6
      ..strokeCap = StrokeCap.round;
    for (final centerY in const [12.0, 24.0, 36.0]) {
      final path = Path()..moveTo(7, centerY);
      var x = 7.0;
      var crest = true;
      while (x < 41) {
        final nextX = x + 11.5;
        final dy = crest ? -6.4 : 6.4;
        path.cubicTo(
          x + 3.8,
          centerY + dy,
          nextX - 3.8,
          centerY - dy,
          nextX,
          centerY,
        );
        x = nextX;
        crest = !crest;
      }
      canvas.drawPath(path, paint);
    }
  }
}

/// 板块边界图层：样式加载完之后，把内置的 USGS 板块边界 GeoJSON 画到
/// 栅格底图之上、震中图层之下。
///
/// 样式加载是异步的，这里排队等地图操作队列，再加源、加图层；
/// 失败时打日志，不影响震中圆点图层。
class BasemapLayers extends HookConsumerWidget {
  const BasemapLayers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styleController = MapController.maybeOf(context)?.style;
    final enqueue = useMapOperationQueue();

    useEffect(() {
      if (styleController == null) {
        return null;
      }
      unawaited(enqueue(() => _addPlateBoundaries(styleController)));
      return null;
    }, [styleController]);

    return const SizedBox.shrink();
  }

  Future<void> _addPlateBoundaries(StyleController controller) async {
    try {
      final data = await rootBundle.loadString(plateBoundaryAsset);
      await controller.addSource(
        GeoJsonSource(id: plateBoundarySourceId, data: data),
      );
      await controller.addLayer(
        const LineStyleLayer(
          id: plateBoundaryLayerId,
          sourceId: plateBoundarySourceId,
          paint: {
            'line-color': '#B5471F',
            'line-width': [
              'interpolate',
              ['linear'],
              ['zoom'],
              1,
              0.8,
              4,
              1.5,
              8,
              2.6,
            ],
            'line-opacity': 0.85,
          },
        ),
      );
    } on Object catch (e, s) {
      talker.handle(e, s, '板块边界图层加载失败');
    }
  }
}

/// 地图标记本身（实心圆点 / 空心环 + 波浪）已能区分地震与海啸，按用户要求
/// 不再在地图右上角放图例，避免遮挡地图内容。

