import 'dart:async';
import 'dart:io' show File;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show Factory, kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:cross_file/cross_file.dart';
import '../models/location_history_entry.dart';
import '../providers/location_provider.dart';
import '../services/location_history_service.dart';
import '../models/geofence.dart';

// ── Date filter enum ──────────────────────────────────────────────────────────
enum _DateFilter { today, yesterday, week, custom }

/// Must have Geocoding API enabled in Google Cloud Console.
const String _kGeoApiKey = 'AIzaSyDkChnyB-Yn8wreq0nDv1eEqxdouLHwVqc';

class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends ConsumerState<LocationHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const Color _teal = Color(0xFF00897B);
  static const Color _tealLight = Color(0xFFE0F2F1);

  GoogleMapController? _mapController;
  bool _mapReady = false;
  late TabController _tabCtrl;

  // Satellite/hybrid toggle
  bool _isHybrid = false;

  // Date filter
  _DateFilter _activeFilter = _DateFilter.today;
  DateTime? _customStart;
  DateTime? _customEnd;

  // Replay state
  bool _isReplaying = false;
  int _replayIndex = 0;
  Timer? _replayTimer;
  double _replaySpeed = 1.0;

  // Export
  final Map<String, String> _geocodeCache = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    if (_mapReady) _mapController?.dispose();
    _mapController = null;
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────
  List<LocationHistoryEntry> _filterHistory(
      List<LocationHistoryEntry> history) {
    final now = DateTime.now();
    switch (_activeFilter) {
      case _DateFilter.today:
        return history
            .where((e) =>
                e.timestamp.year == now.year &&
                e.timestamp.month == now.month &&
                e.timestamp.day == now.day)
            .toList();
      case _DateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return history
            .where((e) =>
                e.timestamp.year == y.year &&
                e.timestamp.month == y.month &&
                e.timestamp.day == y.day)
            .toList();
      case _DateFilter.week:
        final cutoff = now.subtract(const Duration(days: 7));
        return history.where((e) => e.timestamp.isAfter(cutoff)).toList();
      case _DateFilter.custom:
        if (_customStart == null) return history;
        final end = _customEnd ?? now;
        return history
            .where((e) =>
                e.timestamp.isAfter(
                    _customStart!.subtract(const Duration(seconds: 1))) &&
                e.timestamp.isBefore(end.add(const Duration(days: 1))))
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(locationHistoryProvider);
    final geofenceState = ref.watch(geofenceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Location History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isHybrid ? Icons.map_outlined : Icons.satellite_alt_outlined,
              color: Colors.white,
            ),
            tooltip: _isHybrid ? 'Standard view' : 'Satellite + labels',
            onPressed: () => setState(() => _isHybrid = !_isHybrid),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export',
            onPressed: () => historyAsync
                .whenData((h) => _exportCsv(context, _filterHistory(h))),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
                text: 'Map & Replay',
                icon: Icon(Icons.play_circle_outline, size: 18)),
            Tab(text: 'Timeline', icon: Icon(Icons.timeline, size: 18)),
            Tab(text: 'Heatmap', icon: Icon(Icons.layers_outlined, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Quick filter bar ────────────────────────────────────────────
          _buildFilterBar(),
          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: historyAsync.when(
              data: (history) {
                final filtered = _filterHistory(history);
                if (filtered.isEmpty) return _buildEmpty();
                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildMapTab(filtered, geofenceState),
                    _buildTimelineTab(filtered, geofenceState),
                    _buildHeatmapTab(filtered),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _teal)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Filter Bar ────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: _teal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Today', _DateFilter.today),
            const SizedBox(width: 8),
            _filterChip('Yesterday', _DateFilter.yesterday),
            const SizedBox(width: 8),
            _filterChip('This Week', _DateFilter.week),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _pickCustomRange(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _activeFilter == _DateFilter.custom
                      ? Colors.white
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range,
                        size: 14,
                        color: _activeFilter == _DateFilter.custom
                            ? _teal
                            : Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _activeFilter == _DateFilter.custom &&
                              _customStart != null
                          ? '${_fmtDate(_customStart!)} – ${_fmtDate(_customEnd ?? DateTime.now())}'
                          : 'Custom Range',
                      style: TextStyle(
                        fontSize: 13,
                        color: _activeFilter == _DateFilter.custom
                            ? _teal
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _DateFilter filter) {
    final active = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? _teal : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context)
            .copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _activeFilter = _DateFilter.custom;
        _customStart = range.start;
        _customEnd = range.end;
      });
    }
  }

  // ── Map + Replay Tab ────────────────────────────────────────────────────────
  Widget _buildMapTab(
      List<LocationHistoryEntry> history, GeofenceState geofenceState) {
    final points = history.map((e) => LatLng(e.latitude, e.longitude)).toList();
    final totalDist = LocationHistoryService().calculateTotalDistance(history);
    final grouped = _groupByDate(history);

    final replayPos = _isReplaying && _replayIndex < history.length
        ? LatLng(
            history[_replayIndex].latitude, history[_replayIndex].longitude)
        : null;

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: _tealLight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(Icons.timeline, _fmtDist(totalDist), 'Total dist.'),
              _vDiv(),
              _summaryItem(
                  Icons.today, _fmtDist(_todayDistance(history)), 'Today'),
              _vDiv(),
              _summaryItem(Icons.date_range, '${grouped.length}', 'Days'),
              _vDiv(),
              _summaryItem(Icons.speed,
                  '${_avgSpeed(history).toStringAsFixed(1)} m/s', 'Avg speed'),
            ],
          ),
        ),
        // Map
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target:
                      LatLng(history.first.latitude, history.first.longitude),
                  zoom: 14,
                ),
                onMapCreated: (c) {
                  _mapController = c;
                  _mapReady = true;
                  if (points.length > 1) _fitBounds(points);
                },
                mapType: _isHybrid ? MapType.hybrid : MapType.normal,
                myLocationButtonEnabled: false,
                zoomControlsEnabled:
                    false, // Hide buttons since we have gestures

                // ✅ GESTURE RECOGNIZERS - Enable pinch/pan/tilt/rotate
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                }.cast<Factory<OneSequenceGestureRecognizer>>(),

                // ✅ INDIVIDUAL GESTURE CONTROLS
                zoomGesturesEnabled: true, // Pinch to zoom
                scrollGesturesEnabled: true, // Pan/drag map
                tiltGesturesEnabled: true, // Tilt with two-finger drag
                rotateGesturesEnabled: true, // Rotate with two-finger drag

                markers: {
                  Marker(
                    markerId: const MarkerId('latest'),
                    position: points.first,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed),
                    infoWindow: InfoWindow(
                        title: 'Latest',
                        snippet: _fmtDateTime(history.first.timestamp)),
                  ),
                  if (points.length > 1)
                    Marker(
                      markerId: const MarkerId('oldest'),
                      position: points.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed),
                      infoWindow: InfoWindow(
                          title: 'Oldest',
                          snippet: _fmtDateTime(history.last.timestamp)),
                    ),
                  if (replayPos != null)
                    Marker(
                      markerId: const MarkerId('replay'),
                      position: replayPos,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed),
                      infoWindow: InfoWindow(
                          title: '▶ Replaying',
                          snippet:
                              _fmtDateTime(history[_replayIndex].timestamp)),
                    ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: points,
                    color: _teal,
                    width: 3,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
                },
                circles: geofenceState.geofences
                    .where((f) => f.isActive)
                    .map((f) => Circle(
                          circleId: CircleId('zone_${f.id}'),
                          center: LatLng(f.centerLatitude, f.centerLongitude),
                          radius: f.radiusInMeters,
                          fillColor: _teal.withValues(alpha: 0.1),
                          strokeColor: _teal.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ))
                    .toSet(),
              ),
              if (_isReplaying && _replayIndex < history.length)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '▶ ${_fmtDateTime(history[_replayIndex].timestamp)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Replay controls with scrubbable bar
        _buildReplayControls(history, points),
      ],
    );
  }

  Widget _buildReplayControls(
      List<LocationHistoryEntry> history, List<LatLng> points) {
    final total = (history.length - 1).clamp(1, history.length);
    final progress = _replayIndex / total;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrubbable progress bar
          GestureDetector(
            onTapDown: (d) => _scrubTo(d.localPosition.dx,
                context.findRenderObject() as RenderBox?, history, points),
            onHorizontalDragUpdate: (d) => _scrubTo(d.localPosition.dx,
                context.findRenderObject() as RenderBox?, history, points),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(_teal),
                minHeight: 8,
              ),
            ),
          ),
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmtTimeOnly(history.last.timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              Text(_fmtTimeOnly(history.first.timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isReplaying ? Colors.orange : _teal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_isReplaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white, size: 20),
                label: Text(_isReplaying ? 'Pause' : 'Replay Route',
                    style: const TextStyle(color: Colors.white)),
                onPressed: () => _isReplaying
                    ? _pauseReplay()
                    : _startReplay(history, points),
              ),
              const SizedBox(width: 4),
              if (_isReplaying || _replayIndex > 0)
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.red),
                  tooltip: 'Stop',
                  onPressed: _stopReplay,
                ),
              // Speed control — wrapped in Expanded so the Row never overflows
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${_replaySpeed.toStringAsFixed(0)}x',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    Flexible(
                      child: Slider(
                        value: _replaySpeed,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        activeColor: _teal,
                        onChanged: (v) => setState(() => _replaySpeed = v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrubTo(double dx, RenderBox? box, List<LocationHistoryEntry> history,
      List<LatLng> points) {
    if (box == null || history.isEmpty) return;
    final frac = (dx / box.size.width).clamp(0.0, 1.0);
    final idx = (frac * (history.length - 1)).round();
    setState(() => _replayIndex = idx);
    if (idx < points.length) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(points[idx]));
    }
  }

  // ── Timeline Tab ────────────────────────────────────────────────────────────
  Widget _buildTimelineTab(
      List<LocationHistoryEntry> history, GeofenceState geofenceState) {
    final grouped = _groupByDate(history);

    return Column(
      children: [
        // Stats cards
        _buildStatsRow(history, geofenceState),
        // Timeline list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final date = grouped.keys.elementAt(index);
              final entries = grouped[date]!;
              final dayDist =
                  LocationHistoryService().calculateTotalDistance(entries);
              final events = _buildDayEvents(entries, geofenceState.geofences);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _fmtDateLabel(date),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${entries.length} pts · ${_fmtDist(dayDist)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        children:
                            events.map((e) => _buildTimelineRow(e)).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
      List<LocationHistoryEntry> history, GeofenceState geofenceState) {
    final totalDist = LocationHistoryService().calculateTotalDistance(history);
    final avgSpd = _avgSpeed(history);
    final longestStationary = _longestStationary(history);
    final zoneEvents = _countZoneEvents(history, geofenceState.geofences);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _statCard(Icons.straighten, _fmtDist(totalDist), 'Total distance',
                  Colors.blue.shade700),
              const SizedBox(width: 8),
              _statCard(Icons.speed, '${avgSpd.toStringAsFixed(1)} m/s',
                  'Avg speed', _teal),
              const SizedBox(width: 8),
              _statCard(
                  Icons.pause_circle_outline,
                  _fmtDuration(longestStationary),
                  'Longest rest',
                  Colors.orange.shade700),
              const SizedBox(width: 8),
              _statCard(Icons.swap_horiz, '$zoneEvents', 'Zone events',
                  Colors.purple.shade700),
            ],
          ),
          // Zone dwell doughnut
          if (geofenceState.geofences.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildZoneDwellChart(history, geofenceState.geofences),
          ],
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneDwellChart(
      List<LocationHistoryEntry> history, List<Geofence> zones) {
    final dwell = _calcZoneDwell(history, zones);
    if (dwell.isEmpty) return const SizedBox();

    return Row(
      children: [
        // Simple horizontal bar chart (no external packages needed)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time per zone',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              ...dwell.entries.map((e) {
                final pct = e.value / dwell.values.fold(0.0, (a, b) => a + b);
                final color = _zoneColor(dwell.keys.toList().indexOf(e.key));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 70,
                        child: Text(e.key,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(color),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_fmtDuration(Duration(minutes: e.value.toInt())),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Color _zoneColor(int index) {
    const colors = [
      Color(0xFF00897B),
      Color(0xFF1E88E5),
      Color(0xFFE53935),
      Color(0xFF8E24AA),
      Color(0xFFF4511E),
    ];
    return colors[index % colors.length];
  }

  // ── Heatmap Tab ─────────────────────────────────────────────────────────────
  Widget _buildHeatmapTab(List<LocationHistoryEntry> history) {
    final cells = _buildHeatCells(history);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: history.isNotEmpty
                ? LatLng(history.first.latitude, history.first.longitude)
                : const LatLng(0, 0),
            zoom: 14,
          ),
          onMapCreated: (c) {
            _mapController = c;
            _mapReady = true;
            if (history.length > 1) {
              _fitBounds(
                  history.map((e) => LatLng(e.latitude, e.longitude)).toList());
            }
          },
          mapType: _isHybrid ? MapType.hybrid : MapType.normal,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false, // Hide buttons since we have gestures

          // ✅ GESTURE RECOGNIZERS - Enable pinch/pan/tilt/rotate
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          }.cast<Factory<OneSequenceGestureRecognizer>>(),

          // ✅ INDIVIDUAL GESTURE CONTROLS
          zoomGesturesEnabled: true, // Pinch to zoom
          scrollGesturesEnabled: true, // Pan/drag map
          tiltGesturesEnabled: true, // Tilt with two-finger drag
          rotateGesturesEnabled: true, // Rotate with two-finger drag

          circles: cells,
        ),
        // Legend
        Positioned(
          bottom: 20,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('Less time ', style: TextStyle(fontSize: 11)),
                ...List.generate(5, (i) {
                  final alpha = 0.15 + i * 0.17;
                  return Container(
                    width: 16,
                    height: 16,
                    color: Colors.red.withValues(alpha: alpha),
                  );
                }),
                const Text(' More time', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Set<Circle> _buildHeatCells(List<LocationHistoryEntry> history) {
    // Bucket GPS points into ~50m grid cells
    const gridSize = 0.0005; // ~50m in degrees
    final buckets = <String, int>{};
    final positions = <String, LatLng>{};

    for (final e in history) {
      final cellLat = (e.latitude / gridSize).floor() * gridSize;
      final cellLng = (e.longitude / gridSize).floor() * gridSize;
      final key = '$cellLat:$cellLng';
      buckets[key] = (buckets[key] ?? 0) + 1;
      positions[key] = LatLng(cellLat, cellLng);
    }

    final maxCount = buckets.values.fold(1, (a, b) => b > a ? b : a).toDouble();

    return buckets.entries.map((e) {
      final intensity = e.value / maxCount;
      final alpha = 0.15 + intensity * 0.65;
      return Circle(
        circleId: CircleId(e.key),
        center: positions[e.key]!,
        radius: 30 + intensity * 40,
        fillColor: Colors.red.withValues(alpha: alpha),
        strokeWidth: 0,
      );
    }).toSet();
  }

  // ── Timeline event builder ──────────────────────────────────────────────────
  Widget _buildTimelineRow(_TimelineEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.icon, size: 14, color: event.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                if (event.detail != null)
                  Text(event.detail!,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(_fmtTimeOnly(event.time),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  List<_TimelineEvent> _buildDayEvents(
      List<LocationHistoryEntry> entries, List<Geofence> zones) {
    if (entries.isEmpty) return [];
    final events = <_TimelineEvent>[];
    final locationSvc = ref.read(locationServiceProvider);

    events.add(_TimelineEvent(
      icon: Icons.play_circle_outline,
      label: 'Started tracking',
      time: entries.first.timestamp,
      color: _teal,
    ));

    for (int i = 1; i < entries.length; i++) {
      final prev = entries[i - 1];
      final curr = entries[i];
      final dist = _haversineRaw(
          prev.latitude, prev.longitude, curr.latitude, curr.longitude);
      final timeDiff = curr.timestamp.difference(prev.timestamp).inMinutes;

      if (dist > 100 && timeDiff < 60) {
        final bearing = _bearing(
            prev.latitude, prev.longitude, curr.latitude, curr.longitude);
        events.add(_TimelineEvent(
          icon: Icons.pets,
          label: 'Moving ${_fmtDist(dist)} · heading $bearing',
          detail: '~${timeDiff}min',
          time: curr.timestamp,
          color: Colors.blue.shade700,
        ));
      }

      if (dist < 30 && timeDiff > 10) {
        events.add(_TimelineEvent(
          icon: Icons.pause_circle_outline,
          label: 'Stationary · stayed ~${timeDiff}min',
          time: curr.timestamp,
          color: Colors.orange.shade700,
        ));
      }

      for (final zone in zones.where((z) => z.isActive)) {
        final wasInside = locationSvc.isWithinGeofence(
          currentLat: prev.latitude,
          currentLng: prev.longitude,
          centerLat: zone.centerLatitude,
          centerLng: zone.centerLongitude,
          radiusInMeters: zone.radiusInMeters,
          geofence: zone,
        );
        final isNow = locationSvc.isWithinGeofence(
          currentLat: curr.latitude,
          currentLng: curr.longitude,
          centerLat: zone.centerLatitude,
          centerLng: zone.centerLongitude,
          radiusInMeters: zone.radiusInMeters,
          geofence: zone,
        );
        if (!wasInside && isNow) {
          events.add(_TimelineEvent(
            icon: Icons.login,
            label: 'Entered ${zone.name}',
            time: curr.timestamp,
            color: Colors.green.shade700,
          ));
        } else if (wasInside && !isNow) {
          events.add(_TimelineEvent(
            icon: Icons.logout,
            label: 'Left ${zone.name}',
            time: curr.timestamp,
            color: Colors.red.shade700,
          ));
        }
      }
    }

    events.add(_TimelineEvent(
      icon: Icons.stop_circle_outlined,
      label: 'Last recorded location',
      time: entries.last.timestamp,
      color: Colors.grey.shade700,
    ));

    return events;
  }

  // ── Replay logic ─────────────────────────────────────────────────────────────
  void _startReplay(List<LocationHistoryEntry> history, List<LatLng> points) {
    if (_replayIndex >= history.length - 1) _replayIndex = 0;
    setState(() => _isReplaying = true);
    _replayTimer = Timer.periodic(
      Duration(milliseconds: (500 / _replaySpeed).toInt()),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _replayIndex++;
          if (_replayIndex >= history.length) {
            _replayIndex = history.length - 1;
            _isReplaying = false;
            t.cancel();
          } else {
            _mapController
                ?.animateCamera(CameraUpdate.newLatLng(points[_replayIndex]));
          }
        });
      },
    );
  }

  void _pauseReplay() {
    _replayTimer?.cancel();
    setState(() => _isReplaying = false);
  }

  void _stopReplay() {
    _replayTimer?.cancel();
    setState(() {
      _isReplaying = false;
      _replayIndex = 0;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EXPORT SYSTEM
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String> _reverseGeocode(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_geocodeCache.containsKey(key)) return _geocodeCache[key]!;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&result_type=point_of_interest|establishment|park|neighborhood|route'
        '&key=$_kGeoApiKey',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        final components = first['address_components'] as List? ?? [];
        String? name;
        for (final c in components) {
          final types = (c['types'] as List).cast<String>();
          if (types.contains('establishment') ||
              types.contains('point_of_interest') ||
              types.contains('park')) {
            name = c['long_name'] as String?;
            break;
          }
        }
        name ??= first['formatted_address'] as String?;
        if (name != null) {
          final parts = name.split(',');
          name = parts.take(2).join(',').trim();
        }
        final result = name ?? 'Unknown location';
        _geocodeCache[key] = result;
        return result;
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  List<LocationHistoryEntry> _sampleWaypoints(
      List<LocationHistoryEntry> history) {
    if (history.isEmpty) return [];
    if (history.length <= 4) return history;

    final waypoints = <LocationHistoryEntry>[history.first];
    DateTime lastAdded = history.first.timestamp;

    for (int i = 1; i < history.length - 1; i++) {
      final e = history[i];
      final minsSinceLast = e.timestamp.difference(lastAdded).inMinutes.abs();
      final dist = _haversineRaw(waypoints.last.latitude,
          waypoints.last.longitude, e.latitude, e.longitude);
      if (minsSinceLast >= 15 || dist >= 500) {
        waypoints.add(e);
        lastAdded = e.timestamp;
      }
    }
    waypoints.add(history.last);
    return waypoints;
  }

  Future<String> _buildReport(
      List<LocationHistoryEntry> history, List<Geofence> zones) async {
    final sb = StringBuffer();
    final now = DateTime.now();
    final totalDist = LocationHistoryService().calculateTotalDistance(history);
    final avgSpd = _avgSpeed(history);
    final activeTime = history.length > 1
        ? history.first.timestamp.difference(history.last.timestamp).abs()
        : Duration.zero;

    sb.writeln('╔══════════════════════════════════════════════════╗');
    sb.writeln('║         PetGuard Pro — Location History Report   ║');
    sb.writeln('╚══════════════════════════════════════════════════╝');
    sb.writeln();
    sb.writeln('Generated : ${_fmtDateTime(now)}');
    sb.writeln('Period    : ${_fmtDateTime(history.last.timestamp)}');
    sb.writeln('          → ${_fmtDateTime(history.first.timestamp)}');
    sb.writeln('GPS points: ${history.length}');
    sb.writeln();
    sb.writeln('── SUMMARY ────────────────────────────────────────');
    sb.writeln('Total distance : ${_fmtDist(totalDist)}');
    sb.writeln('Active time    : ${_fmtDuration(activeTime)}');
    sb.writeln('Average speed  : ${avgSpd.toStringAsFixed(2)} m/s');
    sb.writeln('Longest rest   : ${_fmtDuration(_longestStationary(history))}');
    sb.writeln('Zone events    : ${_countZoneEvents(history, zones)}');
    sb.writeln();

    if (zones.isNotEmpty) {
      final dwell = _calcZoneDwell(history, zones);
      if (dwell.isNotEmpty) {
        sb.writeln('── TIME IN ZONES ───────────────────────────────────');
        dwell.forEach((zoneName, minutes) {
          final pct = (minutes / dwell.values.fold(0.0, (a, b) => a + b) * 100)
              .toStringAsFixed(1);
          sb.writeln(
              '  ${zoneName.padRight(20)} ${_fmtDuration(Duration(minutes: minutes.toInt()))} ($pct%)');
        });
        sb.writeln();
      }
    }

    sb.writeln('── JOURNEY LOG (key waypoints) ─────────────────────');
    final waypoints = _sampleWaypoints(history);

    for (int i = 0; i < waypoints.length; i++) {
      final e = waypoints[i];
      final place = await _reverseGeocode(e.latitude, e.longitude);
      final svc = ref.read(locationServiceProvider);
      final activeZones = zones
          .where((z) =>
              z.isActive &&
              svc.isWithinGeofence(
                currentLat: e.latitude,
                currentLng: e.longitude,
                centerLat: z.centerLatitude,
                centerLng: z.centerLongitude,
                radiusInMeters: z.radiusInMeters,
                geofence: z,
              ))
          .map((z) => z.name)
          .toList();
      final zoneStr =
          activeZones.isNotEmpty ? ' [inside: ${activeZones.join(', ')}]' : '';
      String movStr = '';
      if (i > 0) {
        final prev = waypoints[i - 1];
        final d = _haversineRaw(
            prev.latitude, prev.longitude, e.latitude, e.longitude);
        final mins = e.timestamp.difference(prev.timestamp).inMinutes.abs();
        movStr = '  → moved ${_fmtDist(d)} in ${mins}min\n';
      }
      sb.write(movStr);
      sb.writeln('${i + 1}. ${_fmtTimeOnly(e.timestamp)}  $place$zoneStr');
      if (e.accuracy != null) {
        sb.writeln('      GPS accuracy: ±${e.accuracy!.toStringAsFixed(1)}m');
      }
    }

    sb.writeln();
    sb.writeln('── RAW DATA ────────────────────────────────────────');
    sb.writeln('Time            Latitude      Longitude     Accuracy  Place');
    sb.writeln('─' * 75);

    final step = math.max(1, history.length ~/ 50);
    for (int i = 0; i < history.length; i += step) {
      final e = history[i];
      final place = await _reverseGeocode(e.latitude, e.longitude);
      final acc =
          e.accuracy != null ? '±${e.accuracy!.toStringAsFixed(0)}m' : '  N/A ';
      sb.writeln(_fmtTimeOnly(e.timestamp).padRight(16) +
          e.latitude.toStringAsFixed(5).padRight(14) +
          e.longitude.toStringAsFixed(5).padRight(14) +
          acc.padRight(10) +
          place);
    }

    sb.writeln();
    sb.writeln('── END OF REPORT ───────────────────────────────────');
    sb.writeln('Generated by PetGuard Pro');
    return sb.toString();
  }

  Future<String> _buildCsv(List<LocationHistoryEntry> history) async {
    final sb = StringBuffer();
    sb.writeln('timestamp,time,latitude,longitude,accuracy_m,place_name,zone');

    final svc = ref.read(locationServiceProvider);
    final zones = ref.read(geofenceProvider).geofences;
    final step = math.max(1, history.length ~/ 100);

    for (int i = 0; i < history.length; i += step) {
      final e = history[i];
      final place = await _reverseGeocode(e.latitude, e.longitude);
      final activeZone = zones
              .where((z) =>
                  z.isActive &&
                  svc.isWithinGeofence(
                    currentLat: e.latitude,
                    currentLng: e.longitude,
                    centerLat: z.centerLatitude,
                    centerLng: z.centerLongitude,
                    radiusInMeters: z.radiusInMeters,
                    geofence: z,
                  ))
              .map((z) => z.name)
              .firstOrNull ??
          '';
      final safeName = '"${place.replaceAll('"', "'")}"';
      sb.writeln('${e.timestamp.toIso8601String()},'
          '${_fmtTimeOnly(e.timestamp)},'
          '${e.latitude},'
          '${e.longitude},'
          '${e.accuracy?.toStringAsFixed(1) ?? ''},'
          '$safeName,'
          '$activeZone');
    }
    return sb.toString();
  }

  // ── Show export bottom sheet ────────────────────────────────────────────────
  void _exportCsv(BuildContext context, List<LocationHistoryEntry> history) {
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export for this period.')),
      );
      return;
    }

    final now = DateTime.now();
    final label =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final geofenceState = ref.read(geofenceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Export Location History Report',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${history.length} location entries · includes place names & zone info',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Color(0xFF00897B)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Requires internet. May take a few seconds!',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF00897B)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Option 1 — Full Report (.txt)
                _exportOption(
                  icon: Icons.description_outlined,
                  color: const Color(0xFF00897B),
                  title: 'Full Report (.txt)',
                  subtitle: 'Human-readable journey log',
                  onTap: () {
                    Navigator.pop(ctx);
                    _generateAndShare(
                      context: context,
                      future: _buildReport(history, geofenceState.geofences),
                      filename: 'petguard_report_$label.txt',
                      mime: 'text/plain',
                      successMsg: 'Report ready',
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Option 2 — Spreadsheet CSV
                _exportOption(
                  icon: Icons.table_chart_outlined,
                  color: Colors.green.shade700,
                  title: 'Spreadsheet CSV',
                  subtitle: 'Open in Excel or Sheets',
                  onTap: () {
                    Navigator.pop(ctx);
                    _generateAndShare(
                      context: context,
                      future: _buildCsv(history),
                      filename: 'petguard_history_$label.csv',
                      mime: 'text/csv',
                      successMsg: 'CSV ready',
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Option 3 — Copy to clipboard
                _exportOption(
                  icon: Icons.copy_outlined,
                  color: Colors.blue.shade700,
                  title: 'Copy Summary to Clipboard',
                  subtitle: 'Quick stats and journey logs',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLoadingSnack(context, 'Building Summary…');
                    _buildReport(history, geofenceState.geofences)
                        .then((report) {
                      Clipboard.setData(ClipboardData(text: report));
                      _snackDone(context, 'Summary Copied to Clipboard');
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndShare({
    required BuildContext context,
    required Future<String> future,
    required String filename,
    required String mime,
    required String successMsg,
  }) async {
    _showLoadingSnack(context, 'Building Report with Place Names…');
    try {
      final content = await future;
      if (kIsWeb) {
        Clipboard.setData(ClipboardData(text: content));
        _snackDone(context, '$successMsg — Copied to Clipboard (web)');
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/$filename';
        await _writeTempFile(path, content);
        await share_plus.Share.shareXFiles(
          [XFile(path)],
          subject: 'PetGuard Pro — Location Report',
        );
        _snackDone(context, successMsg);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _exportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<String> _writeTempFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content, flush: true);
    return path;
  }

  void _showLoadingSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        const SizedBox(width: 10),
        Text(msg),
      ]),
      backgroundColor: const Color(0xFF00897B),
      duration: const Duration(seconds: 15),
    ));
  }

  void _snackDone(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: const Color(0xFF00897B),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final filterLabel = {
      _DateFilter.today: 'today',
      _DateFilter.yesterday: 'yesterday',
      _DateFilter.week: 'this week',
      _DateFilter.custom: 'the selected range',
    }[_activeFilter]!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No history for $filterLabel',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _activeFilter = _DateFilter.week),
            child: const Text('Show this week instead'),
          ),
        ],
      ),
    );
  }

  // ── Utility widgets ───────────────────────────────────────────────────────────
  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: _teal, size: 18),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _vDiv() =>
      Container(width: 1, height: 32, color: Colors.teal.shade100);

  // ── Stat calculators ──────────────────────────────────────────────────────────
  double _todayDistance(List<LocationHistoryEntry> history) {
    final today = DateTime.now();
    final todayH = history
        .where((e) =>
            e.timestamp.year == today.year &&
            e.timestamp.month == today.month &&
            e.timestamp.day == today.day)
        .toList();
    return LocationHistoryService().calculateTotalDistance(todayH);
  }

  double _avgSpeed(List<LocationHistoryEntry> history) {
    if (history.length < 2) return 0;
    final totalDist = LocationHistoryService().calculateTotalDistance(history);
    final totalSeconds = history.first.timestamp
        .difference(history.last.timestamp)
        .inSeconds
        .abs();
    if (totalSeconds == 0) return 0;
    return totalDist / totalSeconds;
  }

  Duration _longestStationary(List<LocationHistoryEntry> history) {
    Duration longest = Duration.zero;
    for (int i = 1; i < history.length; i++) {
      final dist = _haversineRaw(history[i - 1].latitude,
          history[i - 1].longitude, history[i].latitude, history[i].longitude);
      if (dist < 30) {
        final d =
            history[i].timestamp.difference(history[i - 1].timestamp).abs();
        if (d > longest) longest = d;
      }
    }
    return longest;
  }

  int _countZoneEvents(
      List<LocationHistoryEntry> history, List<Geofence> zones) {
    int count = 0;
    final svc = ref.read(locationServiceProvider);
    for (int i = 1; i < history.length; i++) {
      for (final z in zones.where((z) => z.isActive)) {
        final was = svc.isWithinGeofence(
            currentLat: history[i - 1].latitude,
            currentLng: history[i - 1].longitude,
            centerLat: z.centerLatitude,
            centerLng: z.centerLongitude,
            radiusInMeters: z.radiusInMeters,
            geofence: z);
        final now = svc.isWithinGeofence(
            currentLat: history[i].latitude,
            currentLng: history[i].longitude,
            centerLat: z.centerLatitude,
            centerLng: z.centerLongitude,
            radiusInMeters: z.radiusInMeters,
            geofence: z);
        if (was != now) count++;
      }
    }
    return count;
  }

  Map<String, double> _calcZoneDwell(
      List<LocationHistoryEntry> history, List<Geofence> zones) {
    final dwell = <String, double>{};
    final svc = ref.read(locationServiceProvider);
    for (int i = 1; i < history.length; i++) {
      final minutes = history[i]
          .timestamp
          .difference(history[i - 1].timestamp)
          .inMinutes
          .abs()
          .toDouble();
      for (final z in zones.where((z) => z.isActive)) {
        final inside = svc.isWithinGeofence(
            currentLat: history[i].latitude,
            currentLng: history[i].longitude,
            centerLat: z.centerLatitude,
            centerLng: z.centerLongitude,
            radiusInMeters: z.radiusInMeters,
            geofence: z);
        if (inside) dwell[z.name] = (dwell[z.name] ?? 0) + minutes;
      }
    }
    return dwell;
  }

  // ── Map helpers ───────────────────────────────────────────────────────────────
  void _fitBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
          southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      60,
    ));
  }

  // ── Grouping ──────────────────────────────────────────────────────────────────
  Map<DateTime, List<LocationHistoryEntry>> _groupByDate(
      List<LocationHistoryEntry> history) {
    final grouped = <DateTime, List<LocationHistoryEntry>>{};
    for (final e in history) {
      final d = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      grouped.putIfAbsent(d, () => []).add(e);
    }
    return grouped;
  }

  // ── Format helpers ────────────────────────────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _fmtDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yest) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _fmtDateTime(DateTime dt) =>
      '${_fmtDateLabel(dt)} ${_fmtTimeOnly(dt)}';

  String _fmtTimeOnly(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDist(double m) {
    if (m < 1000) return '${m.toStringAsFixed(0)}m';
    return '${(m / 1000).toStringAsFixed(2)}km';
  }

  String _fmtDuration(Duration d) {
    if (d.inMinutes < 1) return '<1m';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  String _bearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = lng2 - lng1;
    final dLat = lat2 - lat1;
    final angle = math.atan2(dLng, dLat) * 180 / math.pi;
    final b = (angle + 360) % 360;
    if (b < 22.5 || b >= 337.5) return 'North';
    if (b < 67.5) return 'NE';
    if (b < 112.5) return 'East';
    if (b < 157.5) return 'SE';
    if (b < 202.5) return 'South';
    if (b < 247.5) return 'SW';
    if (b < 292.5) return 'West';
    return 'NW';
  }

  double _haversineRaw(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _TimelineEvent {
  final IconData icon;
  final String label;
  final String? detail;
  final DateTime time;
  final Color color;
  const _TimelineEvent({
    required this.icon,
    required this.label,
    this.detail,
    required this.time,
    required this.color,
  });
}
