import 'dart:async';
import 'dart:convert';

import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/hook/use_map_operation_queue.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/util/map/map_geo_json_source_updater.dart';
import 'package:eqmonitor/core/util/map/remove_map_style_resources.dart';
import 'package:eqmonitor/feature/map/ui/map_operation_queue_scope.dart';
import 'package:eqmonitor/feature/map/ui/maplibre_event_provider.dart';
import 'package:eqmonitor/page/event_detail_sheet.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maplibre/maplibre.dart';
import 'package:material_ui/material_ui.dart';

/// QuakePush 的底图：与 EQMonitor 首页同类的浅色矢量底图。
///
/// 之前试过 OSM 官方栅格，但栅格瓦片把各国语言文字全画在同一张图上（俄文、日文、
/// 越南文混在一起），观感很糟。这里回到矢量的 Positron 样式：只保留国界、淡灰陆地
/// 与少量拉丁地名，放大后才会出现细节文字，视觉与 EQMonitor 一致。
///
/// 样式由 OpenFreeMap 提供（基于 OpenStreetMap 数据，免密钥），署名写在首页面板底部。
const _mapStyleUrl = 'https://tiles.openfreemap.org/styles/positron';

String quakeMapStyleString() => _mapStyleUrl;

/// 首页背后的全球地震地图：底图 + 震中圆点图层。
///
/// 与 EQMonitor 首页结构一致：地图铺满屏幕，内容卡片浮在上面。
/// 点一下震中点即可弹出该事件的详情（与列表里点条目是同一个弹窗）。
class QuakeMap extends HookConsumerWidget {
  const QuakeMap({super.key, this.minMagnitude = 0});

  final double minMagnitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerRef = useRef<MapController?>(null);
    final isEnglish = ref.watch(appLocaleProvider).languageCode == 'en';
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
                  isEnglish: isEnglish,
                ),
              );
            }
          },
          children: [EpicenterLayer(events: events)],
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
    required bool isEnglish,
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
    await showUsgsEventDetail(context, target, isEnglish: isEnglish);
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
  const EpicenterLayer({required this.events, super.key});

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
