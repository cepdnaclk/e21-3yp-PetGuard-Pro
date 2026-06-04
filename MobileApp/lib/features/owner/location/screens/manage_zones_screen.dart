import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/location_provider.dart';
import '../models/geofence.dart';
import '../models/pet_location.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Schedule helper — centralised so both UI and service use the same logic.
//  If GeofenceSchedule already has isActiveNow in your model file, remove this
//  extension and just call zone.schedule.isActiveNow everywhere.
// ─────────────────────────────────────────────────────────────────────────────
extension GeofenceScheduleX on GeofenceSchedule {
  /// True when breach detection should run right now.
  /// If isScheduled == false the zone is always considered active.
  bool get isActiveNow {
    if (!isScheduled) return true;
    final now = DateTime.now();
    // activeDays[0] = Monday … activeDays[6] = Sunday
    // DateTime.weekday: 1=Mon … 7=Sun  →  subtract 1 for 0-based index
    final dayIdx = now.weekday - 1;
    if (dayIdx < 0 || dayIdx >= activeDays.length) return false;
    if (!activeDays[dayIdx]) return false;

    final nowMins = now.hour * 60 + now.minute;
    final fromMins = fromHour * 60 + fromMinute;
    final toMins = toHour * 60 + toMinute;

    if (fromMins <= toMins) {
      // Normal range e.g. 08:00–18:00
      return nowMins >= fromMins && nowMins <= toMins;
    } else {
      // Overnight range e.g. 22:00–06:00
      return nowMins >= fromMins || nowMins <= toMins;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Manage Zones Screen
// ─────────────────────────────────────────────────────────────────────────────
class ManageZonesScreen extends ConsumerStatefulWidget {
  const ManageZonesScreen({super.key});
  @override
  ConsumerState<ManageZonesScreen> createState() => _ManageZonesScreenState();
}

class _ManageZonesScreenState extends ConsumerState<ManageZonesScreen>
    with SingleTickerProviderStateMixin {
  static const Color _teal = Color(0xFF00897B);
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geofenceState = ref.watch(geofenceProvider);
    final locationAsync = ref.watch(locationStreamProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Safe Zones',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'My Zones', icon: Icon(Icons.shield_outlined, size: 18)),
            Tab(
                text: 'Add Zone',
                icon: Icon(Icons.add_location_alt_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildZoneList(geofenceState, locationAsync),
          _buildAddZoneTab(locationAsync),
        ],
      ),
    );
  }

  Widget _buildZoneList(
      GeofenceState geofenceState, AsyncValue<PetLocation> locationAsync) {
    if (geofenceState.geofences.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_location_alt_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No safe zones yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Go to "Add Zone" tab to create your first safe zone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add First Zone',
                style: TextStyle(color: Colors.white)),
            onPressed: () => _tabCtrl.animateTo(1),
          ),
        ]),
      );
    }
    final petLoc = locationAsync.valueOrNull;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: geofenceState.geofences.length,
      itemBuilder: (context, i) =>
          _buildZoneCard(geofenceState.geofences[i], petLoc),
    );
  }

  Widget _buildZoneCard(Geofence zone, PetLocation? petLoc) {
    final svc = ref.read(locationServiceProvider);

    // Schedule check: only enforce if both master switch AND schedule window are active
    final scheduleActive = zone.schedule.isActiveNow;
    final effectivelyActive = zone.isActive && scheduleActive;

    bool isPetInside = false;
    double? dist;
    if (petLoc != null && effectivelyActive) {
      isPetInside = svc.isWithinGeofence(
        currentLat: petLoc.latitude,
        currentLng: petLoc.longitude,
        centerLat: zone.centerLatitude,
        centerLng: zone.centerLongitude,
        radiusInMeters: zone.radiusInMeters,
        geofence: zone,
      );
      if (!isPetInside) {
        dist = _haversine(petLoc.latitude, petLoc.longitude,
            zone.centerLatitude, zone.centerLongitude);
      }
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;
    if (!zone.isActive) {
      statusColor = Colors.grey;
      statusText = 'Inactive';
      statusIcon = Icons.block;
    } else if (!scheduleActive) {
      statusColor = Colors.blueGrey;
      statusText = 'Outside schedule';
      statusIcon = Icons.schedule;
    } else if (isPetInside) {
      statusColor = Colors.green.shade700;
      statusText = 'Pet is here ✓';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = Colors.orange.shade700;
      statusText = dist != null ? '${_fmtDist(dist)} away' : 'Pet outside';
      statusIcon = Icons.warning_amber_rounded;
    }

    final zoneColor = Color(zone.colorValue);
    final typeLabel =
        zone.zoneType == GeofenceType.polygon ? 'Polygon' : 'Circle';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: zoneColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(zone.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                ])),
            Switch(
              value: zone.isActive,
              activeThumbColor: _teal,
              onChanged: (_) =>
                  ref.read(geofenceProvider.notifier).toggleGeofence(zone.id),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            _chip(
                Icons.radio_button_unchecked,
                typeLabel == 'Circle'
                    ? '${zone.radiusInMeters.toInt()}m radius'
                    : '${zone.polygonPoints.length} points'),
            _chip(
                Icons.schedule,
                zone.schedule.isScheduled
                    ? '${_fmtTime(zone.schedule.fromHour, zone.schedule.fromMinute)} – ${_fmtTime(zone.schedule.toHour, zone.schedule.toMinute)}'
                    : 'Always active'),
            _chip(Icons.category, typeLabel),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: const BorderSide(color: _teal),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => _openEditScreen(context, zone),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => _confirmDelete(context, zone),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ]),
      );

  Widget _buildAddZoneTab(AsyncValue<PetLocation> locationAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Text("Choose a method to define the safe area",
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        _buildMethodCard(
          icon: Icons.radio_button_unchecked,
          title: 'Circular Zone',
          subtitle: 'Circular Safe Zones',
          color: _teal,
          badge: 'Classic',
          onTap: () =>
              locationAsync.whenData((loc) => _openCircleCreator(context, loc)),
        ),
        const SizedBox(height: 12),
        _buildMethodCard(
          icon: Icons.edit_location_alt_outlined,
          title: 'Draw on Map',
          subtitle: 'Draw the Safe Zone on the Map',
          color: Colors.blue.shade700,
          badge: 'Method 1',
          onTap: () => locationAsync
              .whenData((loc) => _openPolygonCreator(context, loc)),
        ),
        const SizedBox(height: 12),
        _buildMethodCard(
          icon: Icons.search_rounded,
          title: 'Search Places',
          subtitle: 'Search Place Names as Safe Zones',
          color: Colors.orange.shade700,
          badge: 'Method 2',
          onTap: () =>
              locationAsync.whenData((loc) => _openPlaceSearch(context, loc)),
        ),
      ]),
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(badge,
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(subtitle,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ])),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  void _openCircleCreator(BuildContext context, PetLocation petLoc) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _CircleCreatorScreen(
                  initialLoc: petLoc,
                  onSave: (zone) {
                    ref.read(geofenceProvider.notifier).addGeofence(zone);
                    Navigator.pop(context);
                    _tabCtrl.animateTo(0);
                    _snack(context, '✓ "${zone.name}" created');
                  },
                )));
  }

  void _openPolygonCreator(BuildContext context, PetLocation petLoc) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _PolygonCreatorScreen(
                  initialLoc: petLoc,
                  onSave: (zone) {
                    ref.read(geofenceProvider.notifier).addGeofence(zone);
                    Navigator.pop(context);
                    _tabCtrl.animateTo(0);
                    _snack(context, '✓ "${zone.name}" polygon created');
                  },
                )));
  }

  void _openPlaceSearch(BuildContext context, PetLocation petLoc) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _PlaceSearchScreen(
                  initialLoc: petLoc,
                  onSave: (zone) {
                    ref.read(geofenceProvider.notifier).addGeofence(zone);
                    Navigator.pop(context);
                    _tabCtrl.animateTo(0);
                    _snack(context, '✓ "${zone.name}" zone created');
                  },
                )));
  }

  void _openEditScreen(BuildContext context, Geofence zone) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _EditZoneScreen(
                  zone: zone,
                  onSave: (updated) {
                    ref.read(geofenceProvider.notifier).updateGeofence(updated);
                    Navigator.pop(context);
                    _snack(context, '✓ "${updated.name}" updated');
                  },
                )));
  }

  void _confirmDelete(BuildContext context, Geofence zone) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete Zone?'),
              content: Text(
                  'Remove "${zone.name}"? Alerts for this zone will stop.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    ref.read(geofenceProvider.notifier).removeGeofence(zone.id);
                    Navigator.pop(context);
                    _snack(context, '"${zone.name}" deleted');
                  },
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
  }

  void _snack(BuildContext context, String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _teal));

  String _fmtDist(double m) => m < 1000
      ? '${m.toStringAsFixed(0)}m'
      : '${(m / 1000).toStringAsFixed(1)}km';
  String _fmtTime(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
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

// ─────────────────────────────────────────────────────────────────────────────
//  Circle Creator
// ─────────────────────────────────────────────────────────────────────────────
class _CircleCreatorScreen extends StatefulWidget {
  final PetLocation initialLoc;
  final void Function(Geofence) onSave;
  const _CircleCreatorScreen({required this.initialLoc, required this.onSave});
  @override
  State<_CircleCreatorScreen> createState() => _CircleCreatorScreenState();
}

class _CircleCreatorScreenState extends State<_CircleCreatorScreen> {
  static const Color _teal = Color(0xFF00897B);
  LatLng? _center;
  double _radius = 100;
  bool _isHybrid = false;

  @override
  void initState() {
    super.initState();
    _center = LatLng(widget.initialLoc.latitude, widget.initialLoc.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Circular Zone'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                _isHybrid ? Icons.map_outlined : Icons.satellite_alt_outlined,
                color: Colors.white),
            onPressed: () => setState(() => _isHybrid = !_isHybrid),
          ),
          TextButton(
            onPressed: _center == null ? null : _showNameDialog,
            child: const Text('Next',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(children: [
        GoogleMap(
          mapType: _isHybrid ? MapType.hybrid : MapType.normal,
          initialCameraPosition: CameraPosition(target: _center!, zoom: 16),
          onTap: (pos) => setState(() => _center = pos),
          markers: _center == null
              ? {}
              : {
                  Marker(
                    markerId: const MarkerId('center'),
                    position: _center!,
                    draggable: true,
                    onDragEnd: (p) => setState(() => _center = p),
                  ),
                },
          circles: _center == null
              ? {}
              : {
                  Circle(
                    circleId: const CircleId('preview'),
                    center: _center!,
                    radius: _radius,
                    fillColor: _teal.withValues(alpha: 0.15),
                    strokeColor: _teal,
                    strokeWidth: 2,
                  ),
                },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: _instructionBanner(
                'Tap the map to set zone centre. Drag the pin to reposition.')),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.radio_button_unchecked,
                    color: _teal, size: 18),
                const SizedBox(width: 8),
                Text('Radius: ${_radius.toInt()}m',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              Slider(
                value: _radius,
                min: 25,
                max: 2000,
                divisions: 79,
                activeColor: _teal,
                label: '${_radius.toInt()}m',
                onChanged: (v) => setState(() => _radius = v),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showNameDialog() => _showZoneNameDialog(
      context: context,
      center: _center!,
      radius: _radius,
      zoneType: GeofenceType.circle,
      onSave: widget.onSave);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Polygon Creator
//
//  KEY FIX — why only the first point appeared before:
//
//  The old version called _updateScreenPoints() on onCameraMove AND
//  onCameraIdle. That function awaited getScreenCoordinate() for every point
//  in a loop, then called setState(). On Android this creates a continuous
//  setState storm that exhausts the ImageReader buffer queue (the
//  "Unable to acquire a buffer item" / "updateAcquireFence" log spam).
//  While the buffer is flooded the platform view drops redraws, so new
//  polyline/polygon segments never appear — it looks like only the first
//  tap registers.
//
//  Fix: remove the CustomPaint glow overlay and all _updateScreenPoints
//  calls entirely. Points are visualised with:
//    • A native Polyline/Polygon (no async, no getScreenCoordinate)
//    • Native Markers that are alpha=0.01 while drawing (invisible, so they
//      do NOT intercept taps) and become fully visible + draggable after
//      the polygon is closed for fine-tuning.
//  Result: zero async calls per frame, zero setState storm, zero buffer flood.
// ─────────────────────────────────────────────────────────────────────────────
class _PolygonCreatorScreen extends StatefulWidget {
  final PetLocation initialLoc;
  final void Function(Geofence) onSave;
  const _PolygonCreatorScreen({required this.initialLoc, required this.onSave});
  @override
  State<_PolygonCreatorScreen> createState() => _PolygonCreatorScreenState();
}

class _PolygonCreatorScreenState extends State<_PolygonCreatorScreen> {
  static const Color _teal = Color(0xFF00897B);

  // Always replaced with a new list — never mutated in place (Android fix)
  List<LatLng> _points = [];
  bool _closed = false;
  bool _isHybrid = false;

  final List<List<LatLng>> _undoStack = [];
  final List<List<LatLng>> _redoStack = [];

  void _pushUndo() {
    _undoStack.add(List.from(_points));
    _redoStack.clear();
    if (_undoStack.length > 50) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.from(_points));
    final prev = _undoStack.removeLast();
    setState(() {
      _points = List.from(prev);
      if (_closed && _points.length < 3) _closed = false;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.from(_points));
    setState(() => _points = List.from(_redoStack.removeLast()));
  }

  void _onMapTap(LatLng pos) {
    if (_closed) return;
    // Tap within ~40 m of first point → close the polygon
    if (_points.length >= 3) {
      final d = _haversine(_points.first.latitude, _points.first.longitude,
          pos.latitude, pos.longitude);
      if (d < 40) {
        _pushUndo();
        setState(() => _closed = true);
        return;
      }
    }
    _pushUndo();
    setState(() => _points = [..._points, pos]);
  }

  // Markers:
  //  • While drawing  → alpha 0.01 (invisible) so they NEVER intercept taps
  //  • After closing  → alpha 1.0, draggable, cyan colour for fine-tuning
  Set<Marker> _buildMarkers() {
    if (_points.isEmpty) return {};
    return {
      for (int i = 0; i < _points.length; i++)
        Marker(
          markerId: MarkerId('pt_$i'),
          position: _points[i],
          alpha: _closed ? 1.0 : 0.01, // invisible while drawing
          anchor: const Offset(0.5, 1.0),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          draggable: _closed,
          onDragEnd: _closed
              ? (p) {
                  _pushUndo();
                  final updated = List<LatLng>.from(_points);
                  updated[i] = p;
                  setState(() => _points = updated);
                }
              : null,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canClose = _points.length >= 3 && !_closed;
    final canSave = _closed && _points.length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Polygon'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                _isHybrid ? Icons.map_outlined : Icons.satellite_alt_outlined,
                color: Colors.white),
            onPressed: () => setState(() => _isHybrid = !_isHybrid),
          ),
          IconButton(
            icon: Icon(Icons.undo,
                color: _undoStack.isNotEmpty ? Colors.white : Colors.white38),
            onPressed: _undoStack.isNotEmpty && !_closed ? _undo : null,
          ),
          IconButton(
            icon: Icon(Icons.redo,
                color: _redoStack.isNotEmpty ? Colors.white : Colors.white38),
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          TextButton(
            onPressed: canSave ? _showNameDialog : null,
            child: Text('Done',
                style: TextStyle(
                    color: canSave ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
              target: LatLng(
                  widget.initialLoc.latitude, widget.initialLoc.longitude),
              zoom: 16),
          mapType: _isHybrid ? MapType.hybrid : MapType.normal,
          // onTap is the ONLY interaction — no onCameraMove/onCameraIdle
          // (those caused the setState storm and buffer flood on Android)
          onTap: _onMapTap,
          markers: _buildMarkers(),
          polylines: !_closed && _points.length >= 2
              ? {
                  Polyline(
                    polylineId: const PolylineId('draft'),
                    points: List<LatLng>.from(_points), // new list every build
                    color: _teal, width: 4,
                    startCap: Cap.roundCap, endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
                }
              : {},
          polygons: _closed && _points.length >= 3
              ? {
                  Polygon(
                    polygonId: const PolygonId('draft'),
                    points: List<LatLng>.from(_points), // new list every build
                    fillColor: _teal.withValues(alpha: 0.18),
                    strokeColor: _teal, strokeWidth: 3,
                  ),
                }
              : {},
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),

        // Instruction banner
        Positioned(
          top: 10,
          left: 12,
          right: 80,
          child: _instructionBanner(
            _closed
                ? 'Polygon closed ✓  Drag cyan pins to adjust. Tap "Done" to save.'
                : _points.length >= 3
                    ? 'Tap near the first point to close, or keep adding.'
                    : 'Tap the map to add points. Need at least 3.',
          ),
        ),

        // Point counter
        Positioned(
          top: 10,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _teal, borderRadius: BorderRadius.circular(20)),
            child: Text('${_points.length} pts',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),

        // Bottom bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${_points.length} pts',
                    style: const TextStyle(
                        color: _teal, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _closed
                      ? Colors.green.shade700
                      : canClose
                          ? _teal
                          : Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: canClose ? 2 : 0,
                ),
                icon: Icon(_closed ? Icons.check_circle : Icons.check,
                    color: (canClose || _closed)
                        ? Colors.white
                        : Colors.grey.shade500,
                    size: 20),
                label: Text(
                  _closed ? 'Polygon closed ✓' : 'Close Polygon',
                  style: TextStyle(
                    color: (canClose || _closed)
                        ? Colors.white
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onPressed:
                    canClose ? () => setState(() => _closed = true) : null,
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showNameDialog() {
    if (_points.isEmpty) return;
    double cLat = 0, cLng = 0;
    for (final p in _points) {
      cLat += p.latitude;
      cLng += p.longitude;
    }
    _showZoneNameDialog(
      context: context,
      center: LatLng(cLat / _points.length, cLng / _points.length),
      radius: 100,
      zoneType: GeofenceType.polygon,
      polygonPoints: List.from(_points),
      onSave: widget.onSave,
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
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

// ─────────────────────────────────────────────────────────────────────────────
//  Place Search Screen
// ─────────────────────────────────────────────────────────────────────────────
const String _kGoogleMapsApiKey = 'AIzaSyB81jP8zOXNJnNCGrSSoEOmf_uJdum0SKA';

class _Suggestion {
  final String placeId;
  final String description;
  const _Suggestion({required this.placeId, required this.description});
}

class _PlaceSearchScreen extends StatefulWidget {
  final PetLocation initialLoc;
  final void Function(Geofence) onSave;
  const _PlaceSearchScreen({required this.initialLoc, required this.onSave});
  @override
  State<_PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<_PlaceSearchScreen> {
  static const Color _teal = Color(0xFF00897B);
  final _searchCtrl = TextEditingController();
  GoogleMapController? _mapCtrl;
  List<_Suggestion> _suggestions = [];
  bool _loading = false;
  String _loadingLabel = 'Searching…';
  Timer? _debounce;

  String _placeName = '';
  LatLng? _placeCenter;
  List<LatLng> _polygonPoints = [];
  bool _hasRealBoundary = false;
  double _radius = 150;
  bool _editMode = false;
  bool _isHybrid = false;

  bool get _hasPlace => _placeCenter != null;
  bool get _usePolygon => _polygonPoints.length >= 3;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&location=${widget.initialLoc.latitude},${widget.initialLoc.longitude}'
      '&radius=50000&key=$_kGoogleMapsApiKey',
    );
    try {
      final res = await http.get(url);
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _suggestions = ((data['predictions'] as List?) ?? [])
            .map((p) => _Suggestion(
                placeId: p['place_id'] as String,
                description: p['description'] as String))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSuggestionTapped(_Suggestion s) async {
    setState(() {
      _loading = true;
      _loadingLabel = 'Loading place…';
      _suggestions = [];
      _polygonPoints = [];
      _hasRealBoundary = false;
      _editMode = false;
    });
    _searchCtrl.text = s.description;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${s.placeId}&fields=name,geometry&key=$_kGoogleMapsApiKey',
    );
    try {
      final res = await http.get(url);
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        setState(() => _loading = false);
        return;
      }

      final geo = result['geometry'] as Map<String, dynamic>;
      final loc = geo['location'] as Map<String, dynamic>;
      final center = LatLng(
          (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
      final name = result['name'] as String? ?? s.description.split(',').first;

      setState(() {
        _placeCenter = center;
        _placeName = name;
      });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(center, 15));
      await _fetchOverpassBoundary(center, name);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchOverpassBoundary(LatLng center, String name) async {
    if (!mounted) return;
    setState(() => _loadingLabel = 'Detecting boundary…');
    try {
      final nomRes = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(name)}'
            '&lat=${center.latitude}&lon=${center.longitude}'
            '&format=json&limit=5'),
        headers: {'User-Agent': 'SmartPetApp/1.0'},
      );
      if (!mounted) return;
      final nomData = jsonDecode(nomRes.body) as List? ?? [];

      Map<String, dynamic>? best;
      double bestDist = double.infinity;
      for (final item in nomData) {
        final iLat = double.tryParse(item['lat']?.toString() ?? '') ?? 0;
        final iLon = double.tryParse(item['lon']?.toString() ?? '') ?? 0;
        final d = _haversine(center.latitude, center.longitude, iLat, iLon);
        final t = item['osm_type'] as String? ?? '';
        final pri = t == 'relation'
            ? 0
            : t == 'way'
                ? 1
                : 2;
        if (d < bestDist || (d == bestDist && pri < 2)) {
          bestDist = d;
          best = item as Map<String, dynamic>;
        }
      }

      if (best == null || bestDist > 5000 || best['osm_type'] == 'node') {
        _applyCircleFallback(center);
        return;
      }

      final osmType = best['osm_type'] as String;
      final osmId = best['osm_id']?.toString() ?? '';
      final q =
          '[out:json][timeout:15];${osmType == "relation" ? "relation" : "way"}($osmId);(._;>;);out body;';
      final ovRes = await http.get(
        Uri.parse(
            'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(q)}'),
        headers: {'User-Agent': 'SmartPetApp/1.0'},
      );
      if (!mounted) return;

      final elements = (jsonDecode(ovRes.body)['elements'] as List?) ?? [];
      final pts = _extractPolygonFromOverpass(elements, osmType, osmId);

      if (pts.length >= 3) {
        final simplified = _simplifyPolygon(pts, maxPoints: 150);
        final centroid = _computeCentroid(simplified);
        final bounds = _boundsFromPoints(simplified);
        setState(() {
          _polygonPoints = simplified;
          _placeCenter = centroid;
          _hasRealBoundary = true;
          _loading = false;
          _editMode = false;
        });
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
      } else {
        _applyCircleFallback(center);
      }
    } catch (_) {
      if (mounted) _applyCircleFallback(center);
    }
  }

  List<LatLng> _extractPolygonFromOverpass(
      List elements, String osmType, String osmId) {
    final nodeMap = <String, LatLng>{};
    for (final el in elements) {
      if (el['type'] == 'node') {
        final id = el['id']?.toString() ?? '';
        final lat = (el['lat'] as num?)?.toDouble();
        final lon = (el['lon'] as num?)?.toDouble();
        if (lat != null && lon != null) nodeMap[id] = LatLng(lat, lon);
      }
    }
    if (osmType == 'way') {
      for (final el in elements) {
        if (el['type'] == 'way' && el['id']?.toString() == osmId) {
          return (el['nodes'] as List? ?? [])
              .map((n) => nodeMap[n.toString()])
              .whereType<LatLng>()
              .toList();
        }
      }
    } else {
      List<String> outerIds = [];
      for (final el in elements) {
        if (el['type'] == 'relation' && el['id']?.toString() == osmId) {
          outerIds = (el['members'] as List? ?? [])
              .where((m) => m['type'] == 'way' && m['role'] == 'outer')
              .map((m) => m['ref']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          break;
        }
      }
      final segs = <String, List<LatLng>>{};
      for (final el in elements) {
        if (el['type'] == 'way') {
          final id = el['id']?.toString() ?? '';
          if (outerIds.contains(id)) {
            segs[id] = (el['nodes'] as List? ?? [])
                .map((n) => nodeMap[n.toString()])
                .whereType<LatLng>()
                .toList();
          }
        }
      }
      return _chainWaySegments(outerIds, segs);
    }
    return [];
  }

  List<LatLng> _chainWaySegments(
      List<String> ids, Map<String, List<LatLng>> segs) {
    if (ids.isEmpty) return [];
    final result = <LatLng>[];
    final remaining = List<String>.from(ids);
    result.addAll(segs[remaining.removeAt(0)] ?? []);
    while (remaining.isNotEmpty) {
      final last = result.last;
      bool found = false;
      for (int i = 0; i < remaining.length; i++) {
        final seg = segs[remaining[i]] ?? [];
        if (seg.isEmpty) {
          remaining.removeAt(i);
          found = true;
          break;
        }
        if (_ptClose(seg.first, last)) {
          result.addAll(seg.skip(1));
          remaining.removeAt(i);
          found = true;
          break;
        } else if (_ptClose(seg.last, last)) {
          result.addAll(seg.reversed.skip(1));
          remaining.removeAt(i);
          found = true;
          break;
        }
      }
      if (!found) break;
    }
    return result;
  }

  bool _ptClose(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 0.0001 &&
      (a.longitude - b.longitude).abs() < 0.0001;

  List<LatLng> _simplifyPolygon(List<LatLng> pts, {required int maxPoints}) {
    if (pts.length <= maxPoints) return pts;
    final stride = (pts.length / maxPoints).ceil();
    final result = <LatLng>[];
    for (int i = 0; i < pts.length; i += stride) {
      result.add(pts[i]);
    }
    if (result.last != pts.last) result.add(pts.last);
    return result;
  }

  LatLng _computeCentroid(List<LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  LatLngBounds _boundsFromPoints(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  void _applyCircleFallback(LatLng center) {
    if (!mounted) return;
    setState(() {
      _polygonPoints = [];
      _hasRealBoundary = false;
      _loading = false;
      _editMode = false;
    });
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(center, 15));
  }

  void _onMapLongPress(LatLng pos) {
    if (!_editMode) return;
    setState(() => _polygonPoints = [..._polygonPoints, pos]);
  }

  void _deletePoint(int index) {
    if (_polygonPoints.length <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Need at least 3 points to form a zone.'),
          duration: Duration(seconds: 2)));
      return;
    }
    setState(() {
      final u = List<LatLng>.from(_polygonPoints)..removeAt(index);
      _polygonPoints = u;
    });
  }

  Set<Marker> _buildEditMarkers() {
    if (!_editMode || _polygonPoints.isEmpty) return {};
    return {
      for (int i = 0; i < _polygonPoints.length; i++)
        Marker(
          markerId: MarkerId('pt_$i'),
          position: _polygonPoints[i],
          draggable: false,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _deletePoint(i),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search a Place'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                _isHybrid ? Icons.map_outlined : Icons.satellite_alt_outlined,
                color: Colors.white),
            onPressed: () => setState(() => _isHybrid = !_isHybrid),
          ),
          if (_hasPlace && _usePolygon)
            IconButton(
              icon: Icon(
                  _editMode ? Icons.check_circle : Icons.edit_location_alt,
                  color: Colors.white),
              tooltip: _editMode ? 'Done editing' : 'Edit boundary',
              onPressed: () => setState(() => _editMode = !_editMode),
            ),
          if (_hasPlace)
            TextButton(
              onPressed: _goNext,
              child: const Text('Next',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(children: [
        Container(
          color: _teal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search parks, vets, schools…',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                  : const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _suggestions = [];
                          _placeCenter = null;
                          _polygonPoints = [];
                          _hasRealBoundary = false;
                          _editMode = false;
                        });
                      })
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400),
                  () => _fetchSuggestions(v));
              setState(() => _placeCenter = null);
            },
          ),
        ),
        if (_loading)
          Container(
            color: _teal.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: _teal)),
              const SizedBox(width: 10),
              Text(_loadingLabel,
                  style: const TextStyle(color: _teal, fontSize: 13)),
            ]),
          ),
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 52),
                itemBuilder: (ctx, i) {
                  final s = _suggestions[i];
                  final parts = s.description.split(',');
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.place, color: _teal, size: 20),
                    ),
                    title: Text(parts.first.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: parts.length > 1
                        ? Text(parts.skip(1).join(',').trim(),
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12))
                        : null,
                    onTap: () => _onSuggestionTapped(s),
                  );
                },
              ),
            ),
          ),
        Expanded(
            child: Stack(children: [
          GoogleMap(
            mapType: _isHybrid ? MapType.hybrid : MapType.normal,
            initialCameraPosition: CameraPosition(
                target: LatLng(
                    widget.initialLoc.latitude, widget.initialLoc.longitude),
                zoom: 13),
            onMapCreated: (c) => _mapCtrl = c,
            onTap: (_) {
              if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
            },
            onLongPress: _editMode ? _onMapLongPress : null,
            markers: _buildEditMarkers(),
            circles: _hasPlace && !_usePolygon
                ? {
                    Circle(
                      circleId: const CircleId('preview'),
                      center: _placeCenter!,
                      radius: _radius,
                      fillColor: _teal.withValues(alpha: 0.15),
                      strokeColor: _teal,
                      strokeWidth: 2,
                    ),
                  }
                : {},
            polygons: _usePolygon
                ? {
                    Polygon(
                      polygonId: const PolygonId('boundary'),
                      points: List<LatLng>.from(_polygonPoints),
                      strokeWidth: 3,
                      strokeColor: _teal,
                      fillColor: _teal.withValues(alpha: 0.18),
                      geodesic: true,
                    ),
                  }
                : {},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
          ),
          if (!_hasPlace && !_loading)
            Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: _instructionBanner(
                    'Search above to detect the real boundary of a place.')),
          if (_hasPlace && _editMode)
            Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: _instructionBanner(
                    'Tap a red pin to remove it. Long-press map to add a point. Tap ✓ when done.')),
          if (_hasPlace && !_loading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, -2))
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.place, color: _teal, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_placeName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_hasRealBoundary
                                    ? Colors.green
                                    : Colors.orange)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _hasRealBoundary
                                ? '✓ Real boundary'
                                : _usePolygon
                                    ? 'Approx boundary'
                                    : 'Circle boundary',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _hasRealBoundary
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        _usePolygon
                            ? _editMode
                                ? 'Tap a pin to remove it. Long-press map to add.'
                                : '${_polygonPoints.length} boundary points. Tap ✎ to edit.'
                            : 'No polygon found. Adjust the radius below.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      if (!_usePolygon) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.radio_button_unchecked,
                              color: _teal, size: 16),
                          const SizedBox(width: 6),
                          Text('Radius: ${_radius.toInt()}m',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                        Slider(
                            value: _radius,
                            min: 25,
                            max: 2000,
                            divisions: 79,
                            activeColor: _teal,
                            label: '${_radius.toInt()}m',
                            onChanged: (v) => setState(() => _radius = v)),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _teal,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          onPressed: _goNext,
                          child: const Text('Use this zone →',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                      ),
                    ]),
              ),
            ),
          if (_loading && _hasPlace)
            Positioned.fill(
                child: Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: Center(
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: _teal),
                  const SizedBox(height: 14),
                  Text(_loadingLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              )),
            )),
        ])),
      ]),
    );
  }

  void _goNext() {
    if (_placeCenter == null) return;
    _showZoneNameDialog(
      context: context,
      center: _placeCenter!,
      radius: _radius,
      zoneType: _usePolygon ? GeofenceType.polygon : GeofenceType.circle,
      polygonPoints: _usePolygon ? List.from(_polygonPoints) : [],
      defaultName: _placeName.isNotEmpty ? _placeName : 'My Zone',
      onSave: widget.onSave,
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
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

// ─────────────────────────────────────────────────────────────────────────────
//  Edit Zone Screen
// ─────────────────────────────────────────────────────────────────────────────
class _EditZoneScreen extends StatefulWidget {
  final Geofence zone;
  final void Function(Geofence) onSave;
  const _EditZoneScreen({required this.zone, required this.onSave});
  @override
  State<_EditZoneScreen> createState() => _EditZoneScreenState();
}

class _EditZoneScreenState extends State<_EditZoneScreen> {
  static const Color _teal = Color(0xFF00897B);
  late TextEditingController _nameCtrl;
  late double _radius;
  late List<LatLng> _polygonPoints;
  late GeofenceSchedule _schedule;
  late int _colorValue;
  bool _isHybrid = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.zone.name);
    _radius = widget.zone.radiusInMeters;
    _polygonPoints = List.from(widget.zone.polygonPoints);
    _schedule = widget.zone.schedule;
    _colorValue = widget.zone.colorValue;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPolygon = widget.zone.zoneType == GeofenceType.polygon;
    final zoneColor = Color(_colorValue);
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit "${widget.zone.name}"'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                _isHybrid ? Icons.map_outlined : Icons.satellite_alt_outlined,
                color: Colors.white),
            onPressed: () => setState(() => _isHybrid = !_isHybrid),
          ),
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
          child: Column(children: [
        SizedBox(
          height: 320,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
                target: LatLng(
                    widget.zone.centerLatitude, widget.zone.centerLongitude),
                zoom: 15),
            mapType: _isHybrid ? MapType.hybrid : MapType.normal,
            markers: isPolygon
                ? _polygonPoints
                    .asMap()
                    .entries
                    .map((e) => Marker(
                          markerId: MarkerId('pt_${e.key}'),
                          position: e.value,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed),
                          draggable: true,
                          onDragEnd: (p) {
                            final pts = List<LatLng>.from(_polygonPoints);
                            pts[e.key] = p;
                            setState(() => _polygonPoints = pts);
                          },
                        ))
                    .toSet()
                : {
                    Marker(
                      markerId: const MarkerId('center'),
                      position: LatLng(widget.zone.centerLatitude,
                          widget.zone.centerLongitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed),
                      draggable: true,
                      onDragEnd: (_) {},
                    ),
                  },
            polygons: isPolygon && _polygonPoints.length >= 3
                ? {
                    Polygon(
                        polygonId: const PolygonId('zone'),
                        points: _polygonPoints,
                        fillColor: zoneColor.withValues(alpha: 0.15),
                        strokeColor: zoneColor,
                        strokeWidth: 2),
                  }
                : {},
            circles: !isPolygon
                ? {
                    Circle(
                        circleId: const CircleId('zone'),
                        center: LatLng(widget.zone.centerLatitude,
                            widget.zone.centerLongitude),
                        radius: _radius,
                        fillColor: zoneColor.withValues(alpha: 0.15),
                        strokeColor: zoneColor,
                        strokeWidth: 2),
                  }
                : {},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
        ),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Zone name',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Home, Park, Vet',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _teal, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                if (!isPolygon) ...[
                  Row(children: [
                    const Icon(Icons.radio_button_unchecked,
                        color: _teal, size: 18),
                    const SizedBox(width: 8),
                    Text('Radius: ${_radius.toInt()}m',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  Slider(
                      value: _radius,
                      min: 25,
                      max: 2000,
                      divisions: 79,
                      activeColor: _teal,
                      label: '${_radius.toInt()}m',
                      onChanged: (v) => setState(() => _radius = v)),
                  const SizedBox(height: 12),
                ],
                const Text('Zone color',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                _buildColorPicker(),
                const SizedBox(height: 20),
                const Text('Schedule',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                _buildScheduleSection(),
              ],
            )),
      ])),
    );
  }

  Widget _buildColorPicker() {
    const colors = [
      0xFF00897B,
      0xFF1E88E5,
      0xFFE53935,
      0xFF8E24AA,
      0xFFF4511E,
      0xFF43A047,
      0xFFFFB300,
      0xFF00ACC1
    ];
    return Wrap(
        spacing: 10,
        children: colors.map((c) {
          final sel = _colorValue == c;
          return GestureDetector(
            onTap: () => setState(() => _colorValue = c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border:
                      sel ? Border.all(color: Colors.black, width: 3) : null),
              child: sel
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }).toList());
  }

  Widget _buildScheduleSection() {
    final s = _schedule;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Enable schedule',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                Switch(
                    value: s.isScheduled,
                    activeThumbColor: _teal,
                    onChanged: (v) =>
                        setState(() => _schedule = s.copyWith(isScheduled: v))),
              ]),
              if (s.isScheduled) ...[
                const Divider(height: 20),
                Text('Active days',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(
                    children: List.generate(7, (i) {
                  final active = s.activeDays[i];
                  return Expanded(
                      child: GestureDetector(
                    onTap: () {
                      final nd = List<bool>.from(s.activeDays);
                      nd[i] = !active;
                      setState(() => _schedule = s.copyWith(activeDays: nd));
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                          color: active ? _teal : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(days[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: active
                                  ? Colors.white
                                  : Colors.grey.shade500)),
                    ),
                  ));
                })),
                const SizedBox(height: 14),
                Text('Active hours',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _timeTile(
                          label: 'From',
                          hour: s.fromHour,
                          minute: s.fromMinute,
                          onChanged: (h, m) => setState(() => _schedule =
                              s.copyWith(fromHour: h, fromMinute: m)))),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward,
                          size: 18, color: Colors.grey)),
                  Expanded(
                      child: _timeTile(
                          label: 'To',
                          hour: s.toHour,
                          minute: s.toMinute,
                          onChanged: (h, m) => setState(() =>
                              _schedule = s.copyWith(toHour: h, toMinute: m)))),
                ]),
              ],
            ],
          )),
    );
  }

  Widget _timeTile(
      {required String label,
      required int hour,
      required int minute,
      required void Function(int, int) onChanged}) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
          builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: _teal)),
              child: child!),
        );
        if (picked != null) onChanged(picked.hour, picked.minute);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onSave(widget.zone.copyWith(
      name: name,
      radiusInMeters: _radius,
      polygonPoints: _polygonPoints,
      colorValue: _colorValue,
      schedule: _schedule,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared: Name + Schedule creation dialog
// ─────────────────────────────────────────────────────────────────────────────
void _showZoneNameDialog({
  required BuildContext context,
  required LatLng center,
  required double radius,
  required GeofenceType zoneType,
  List<LatLng> polygonPoints = const [],
  String defaultName = 'My Zone',
  required void Function(Geofence) onSave,
}) {
  const teal = Color(0xFF00897B);
  final nameCtrl = TextEditingController(text: defaultName);
  double currentRadius = radius;
  GeofenceSchedule schedule = const GeofenceSchedule();
  int colorValue = 0xFF00897B;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Name your zone',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Zone name',
                hintText: 'e.g. Home, Park, Vet',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: teal, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            if (zoneType == GeofenceType.circle) ...[
              Row(children: [
                const Icon(Icons.radio_button_unchecked, color: teal, size: 18),
                const SizedBox(width: 8),
                Text('Radius: ${currentRadius.toInt()}m',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              Slider(
                  value: currentRadius,
                  min: 25,
                  max: 2000,
                  divisions: 79,
                  activeColor: teal,
                  label: '${currentRadius.toInt()}m',
                  onChanged: (v) => setSheet(() => currentRadius = v)),
              const SizedBox(height: 8),
            ],
            const Text('Color',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 10,
                children: [
                  0xFF00897B,
                  0xFF1E88E5,
                  0xFFE53935,
                  0xFF8E24AA,
                  0xFFF4511E,
                  0xFF43A047
                ].map((c) {
                  final sel = colorValue == c;
                  return GestureDetector(
                    onTap: () => setSheet(() => colorValue = c),
                    child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: sel
                                ? Border.all(color: Colors.black, width: 2.5)
                                : null),
                        child: sel
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : null),
                  );
                }).toList()),
            const SizedBox(height: 16),
            // ── Schedule toggle ──────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Set a schedule',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Only alert during set hours',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
              Switch(
                value: schedule.isScheduled,
                activeThumbColor: teal,
                onChanged: (v) => setSheet(
                    () => schedule = schedule.copyWith(isScheduled: v)),
              ),
            ]),
            // Show time pickers inline when schedule is enabled
            if (schedule.isScheduled) ...[
              const SizedBox(height: 12),
              const Text('Active hours',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _scheduleTimeTile(
                        ctx: ctx,
                        label: 'From',
                        hour: schedule.fromHour,
                        minute: schedule.fromMinute,
                        onChanged: (h, m) => setSheet(() => schedule =
                            schedule.copyWith(fromHour: h, fromMinute: m)))),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward,
                        size: 18, color: Colors.grey)),
                Expanded(
                    child: _scheduleTimeTile(
                        ctx: ctx,
                        label: 'To',
                        hour: schedule.toHour,
                        minute: schedule.toMinute,
                        onChanged: (h, m) => setSheet(() => schedule =
                            schedule.copyWith(toHour: h, toMinute: m)))),
              ]),
              const SizedBox(height: 8),
              const Text('Active days',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                  children: List.generate(7, (i) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final active = schedule.activeDays[i];
                return Expanded(
                    child: GestureDetector(
                  onTap: () {
                    final nd = List<bool>.from(schedule.activeDays);
                    nd[i] = !active;
                    setSheet(
                        () => schedule = schedule.copyWith(activeDays: nd));
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: active ? teal : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(days[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                active ? Colors.white : Colors.grey.shade500)),
                  ),
                ));
              })),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final zone = Geofence(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    centerLatitude: center.latitude,
                    centerLongitude: center.longitude,
                    radiusInMeters: currentRadius,
                    zoneType: zoneType,
                    polygonPoints: polygonPoints,
                    colorValue: colorValue,
                    schedule: schedule,
                  );
                  Navigator.pop(ctx);
                  onSave(zone);
                },
                child: const Text('Save Zone',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        )),
      ),
    ),
  );
}

Widget _scheduleTimeTile({
  required BuildContext ctx,
  required String label,
  required int hour,
  required int minute,
  required void Function(int, int) onChanged,
}) {
  const teal = Color(0xFF00897B);
  return GestureDetector(
    onTap: () async {
      final picked = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay(hour: hour, minute: minute),
        builder: (c, child) => Theme(
            data: Theme.of(c)
                .copyWith(colorScheme: const ColorScheme.light(primary: teal)),
            child: child!),
      );
      if (picked != null) onChanged(picked.hour, picked.minute);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

Widget _instructionBanner(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
