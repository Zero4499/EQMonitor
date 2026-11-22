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

    return MapOperationQueueScope(
      child: MapLibreEventProvider(
        child: MapLibreMap(
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
                  language: language,
                ),
              );
            }
          },
          children: [BasemapLayers(), EpicenterLayer(events: events)],
        ),
      ),
    );
  }

  /// 点击地图：命中震中圆点就弹出该事件详情。
  Future<void> _onMapTap({
    required BuildContext context,
    required MapController? controller,
    required MapEventClick click,
    required List<UsgsEvent> events,
    required String language,
  }) async {
    if (controller == null || events.isEmpty) {
      return;
    }
    // 优先用渲染命中（点在圆点范围内时最准）。
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
  const new({required this.events, super.key});

  final List<UsgsEvent> events;

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
      'circle-opacity': 0.85,
      'circle-stroke-width': 0.8,
      'circle-stroke-color': '#FFFFFF',
    },
  );
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
