import 'dart:async';
import 'dart:convert';

import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/hook/use_map_operation_queue.dart';
import 'package:eqmonitor/core/util/map/map_geo_json_source_updater.dart';
import 'package:eqmonitor/core/util/map/remove_map_style_resources.dart';
import 'package:eqmonitor/feature/map/ui/map_operation_queue_scope.dart';
import 'package:eqmonitor/feature/map/ui/maplibre_event_provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maplibre/maplibre.dart';
import 'package:material_ui/material_ui.dart';

/// QuakePush 的 MapLibre 底图样式（免密钥的 OpenFreeMap Positron 矢量底图）。
String quakeMapStyleString() => 'https://tiles.openfreemap.org/styles/positron';

/// 首页背后的全球地震地图：底图 + 震中圆点图层。
///
/// 与 EQMonitor 首页结构一致：地图铺满屏幕，内容卡片浮在上面。
class QuakeMap extends ConsumerWidget {
  const new({super.key, this.minMagnitude = 0});

  final double minMagnitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onEvent: (event) {
            MapLibreEventProvider.maybeOf(context)?.emit(event);
          },
          children: [EpicenterLayer(events: events)],
        ),
      ),
    );
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
