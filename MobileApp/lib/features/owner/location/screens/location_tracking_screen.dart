import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/location_provider.dart';
import '../models/pet_location.dart';
import '../models/geofence.dart';
import 'manage_zones_screen.dart';

class LocationTrackingScreen extends ConsumerStatefulWidget {
  const LocationTrackingScreen({super.key});

  @override
  ConsumerState<LocationTrackingScreen> createState() =>
      _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends ConsumerState<LocationTrackingScreen>
    with SingleTickerProviderStateMixin {
  static const Color _teal = Color(0xFF00897B);

  GoogleMapController? _mapController;
  bool _followPet = true;
  bool _satelliteView = false;
  bool _sosActive = false;
  final List<LatLng> _breadcrumbs = [];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationStreamProvider);
    final geofenceState = ref.watch(geofenceProvider);

    ref.watch(geofenceMonitorProvider);
    ref.watch(locationHistorySaverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Map',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Satellite toggle
          IconButton(
            icon: Icon(
              _satelliteView ? Icons.map_outlined : Icons.satellite_alt,
              color: Colors.white,
            ),
            tooltip: _satelliteView ? 'Normal view' : 'Satellite view',
            onPressed: () => setState(() => _satelliteView = !_satelliteView),
          ),
          // Manage zones
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: Colors.white),
            tooltip: 'Manage zones',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageZonesScreen()),
            ),
          ),
        ],
      ),
      body: locationAsync.when(
        data: (location) {
          _updateBreadcrumbs(location);
          if (_followPet && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(location.latitude, location.longitude),
              ),
            );
          }
          return _buildMapView(context, location, geofenceState);
        },
        loading: () => _buildLoading(),
        error: (err, _) => _buildError(err),
      ),
    );
  }

  void _updateBreadcrumbs(PetLocation location) {
    final pos = LatLng(location.latitude, location.longitude);
    if (_breadcrumbs.isEmpty ||
        _breadcrumbs.last.latitude != pos.latitude ||
        _breadcrumbs.last.longitude != pos.longitude) {
      _breadcrumbs.add(pos);
      if (_breadcrumbs.length > 20) _breadcrumbs.removeAt(0);
    }
  }

  Widget _buildMapView(
    BuildContext context,
    PetLocation location,
    GeofenceState geofenceState,
  ) {
    final petPos = LatLng(location.latitude, location.longitude);
    final notifier = ref.read(geofenceProvider.notifier);
    final breaches = notifier.checkGeofenceBreaches(location);
    final isBreached = breaches.any((fence) => fence.schedule.isActiveNow);

    // Build circles: zones + pulsing accuracy ring
    final circles = <Circle>{};

    // Accuracy circle
    circles.add(Circle(
      circleId: const CircleId('accuracy'),
      center: petPos,
      radius: location.accuracy ?? 10,
      fillColor: _teal.withValues(alpha: 0.08),
      strokeColor: _teal.withValues(alpha: 0.3),
      strokeWidth: 1,
    ));

    // Geofence circles and polygons
    final polygons = <Polygon>{};

    for (final fence in geofenceState.geofences) {
      final scheduleActive = fence.isActive && fence.schedule.isActiveNow;
      final isInside = ref.read(locationServiceProvider).isWithinGeofence(
            currentLat: location.latitude,
            currentLng: location.longitude,
            centerLat: fence.centerLatitude,
            centerLng: fence.centerLongitude,
            radiusInMeters: fence.radiusInMeters,
            geofence: fence,
          );

      Color fillColor;
      Color strokeColor;
      if (!scheduleActive) {
        fillColor = Colors.grey.withValues(alpha: 0.08);
        strokeColor = Colors.grey.withValues(alpha: 0.4);
      } else if (isInside) {
        fillColor = Colors.green.withValues(alpha: 0.15);
        strokeColor = Colors.green;
      } else {
        fillColor = Colors.red.withValues(alpha: 0.1);
        strokeColor = Colors.red;
      }

      if (fence.zoneType == GeofenceType.polygon &&
          fence.polygonPoints.length >= 3) {
        polygons.add(Polygon(
          polygonId: PolygonId(fence.id),
          points: fence.polygonPoints,
          fillColor: fillColor,
          strokeColor: strokeColor,
          strokeWidth: 2,
        ));
      } else {
        circles.add(Circle(
          circleId: CircleId(fence.id),
          center: LatLng(fence.centerLatitude, fence.centerLongitude),
          radius: fence.radiusInMeters,
          fillColor: fillColor,
          strokeColor: strokeColor,
          strokeWidth: 2,
        ));
      }
    }

    return Stack(
      children: [
        // ── Main map ────────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: petPos,
            zoom: 16,
          ),
          mapType: _satelliteView ? MapType.hybrid : MapType.normal,
          onMapCreated: (c) => _mapController = c,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onCameraMoveStarted: () {
            // Only disable follow if user deliberately moves map
            // (we don't track programmatic moves here)
          },
          markers: {
            Marker(
              markerId: const MarkerId('pet'),
              position: petPos,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                isBreached
                    ? BitmapDescriptor.hueRed
                    : BitmapDescriptor.hueGreen,
              ),
              infoWindow: InfoWindow(
                title: isBreached ? '⚠ Outside safe zone!' : '✓ Your Pet',
                snippet: 'Updated: ${_formatTime(location.timestamp)}',
              ),
            ),
          },
          circles: circles,
          polygons: polygons,
          polylines: _breadcrumbs.length > 1
              ? {
                  Polyline(
                    polylineId: const PolylineId('breadcrumb'),
                    points: _breadcrumbs,
                    color: _teal.withValues(alpha: 0.7),
                    width: 3,
                    patterns: [],
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
                }
              : {},
        ),

        // ── Top info panel ──────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildInfoBanner(location, geofenceState, isBreached),
        ),

        // ── Map controls (right) ────────────────────────────────────────────
        Positioned(
          top: 120,
          right: 12,
          child: Column(
            children: [
              _mapFab(
                icon: _followPet ? Icons.gps_fixed : Icons.gps_not_fixed,
                tooltip: _followPet ? 'Following pet' : 'Re-center on pet',
                onTap: () {
                  setState(() => _followPet = true);
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(petPos),
                  );
                },
                active: _followPet,
              ),
              const SizedBox(height: 8),
              _mapFab(
                icon: Icons.add,
                tooltip: 'Add zone here',
                onTap: () => _addZoneAtCenter(context),
              ),
              const SizedBox(height: 8),
              _mapFab(
                icon: Icons.zoom_in,
                tooltip: 'Zoom in',
                onTap: () => _mapController?.animateCamera(
                  CameraUpdate.zoomIn(),
                ),
              ),
              const SizedBox(height: 8),
              _mapFab(
                icon: Icons.zoom_out,
                tooltip: 'Zoom out',
                onTap: () => _mapController?.animateCamera(
                  CameraUpdate.zoomOut(),
                ),
              ),
            ],
          ),
        ),

        // ── Bottom info sheet (draggable) ───────────────────────────────────
        DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.08,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.08, 0.35, 0.85],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: _buildBottomSheetContent(location, geofenceState),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoBanner(
    PetLocation location,
    GeofenceState geofenceState,
    bool isBreached,
  ) {
    final speed = _calculateSpeed();
    final direction = _getDirection();

    return Container(
      color: isBreached ? Colors.red.shade700 : const Color(0xFFE0F2F1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            isBreached ? Icons.warning_amber_rounded : Icons.pets,
            color: isBreached ? Colors.white : _teal,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isBreached
                  ? 'Pet is outside a safe zone!'
                  : 'Pet is safe · $direction · ${speed > 0 ? '${speed.toStringAsFixed(1)} m/s' : 'Stationary'}',
              style: TextStyle(
                color: isBreached ? Colors.white : Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            _formatTime(location.timestamp),
            style: TextStyle(
              color: isBreached ? Colors.white70 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(
    PetLocation location,
    GeofenceState geofenceState,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomStat(
                  Icons.gps_fixed,
                  '±${location.accuracy?.toStringAsFixed(0) ?? '?'}m',
                  'Accuracy'),
              _bottomStatDivider(),
              _bottomStat(Icons.speed, _calculateSpeed().toStringAsFixed(1),
                  'Speed (m/s)'),
              _bottomStatDivider(),
              _bottomStat(Icons.navigation, _getDirection(), 'Direction'),
              _bottomStatDivider(),
              _bottomStat(
                  Icons.satellite_alt,
                  '${geofenceState.geofences.where((f) => f.isActive).length}',
                  'Active zones'),
            ],
          ),

          const SizedBox(height: 16),

          // Geofence list (compact)
          if (geofenceState.geofences.isNotEmpty) ...[
            ...geofenceState.geofences.map((fence) {
              final scheduleActive =
                  fence.isActive && fence.schedule.isActiveNow;
              final isInside =
                  ref.read(locationServiceProvider).isWithinGeofence(
                        currentLat: location.latitude,
                        currentLng: location.longitude,
                        centerLat: fence.centerLatitude,
                        centerLng: fence.centerLongitude,
                        radiusInMeters: fence.radiusInMeters,
                        geofence: fence,
                      );
              return Opacity(
                opacity: scheduleActive ? 1.0 : 0.5,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    scheduleActive
                        ? (isInside ? Icons.check_circle : Icons.warning)
                        : Icons.block,
                    color: scheduleActive
                        ? (isInside ? Colors.green : Colors.red)
                        : Colors.grey,
                    size: 20,
                  ),
                  title: Text(fence.name,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    scheduleActive
                        ? (isInside
                            ? 'Pet is inside this zone'
                            : '⚠ Pet is outside!')
                        : fence.isActive
                            ? 'Outside schedule'
                            : 'Disabled',
                  ),
                  trailing: Switch(
                    value: fence.isActive,
                    activeThumbColor: _teal,
                    onChanged: (_) => ref
                        .read(geofenceProvider.notifier)
                        .toggleGeofence(fence.id),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // SOS / Find My Pet button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _sosActive
                    ? const Color(0xFF00695C)
                    : const Color(0xFF00897B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _sosActive ? Icons.volume_off : Icons.volume_up_rounded,
                color: Colors.white,
              ),
              label: Text(
                _sosActive ? 'Buzzer Active…' : 'Find My Pet',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: _sosActive ? null : () => _triggerSOS(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapFab({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return FloatingActionButton.small(
      heroTag: tooltip,
      backgroundColor: active ? _teal : Colors.white,
      elevation: 2,
      tooltip: tooltip,
      onPressed: onTap,
      child: Icon(icon,
          color: active ? Colors.white : Colors.grey.shade700, size: 18),
    );
  }

  Widget _bottomStat(IconData icon, String value, String label) {
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

  Widget _bottomStatDivider() {
    return Container(width: 1, height: 36, color: Colors.grey.shade200);
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _teal),
          SizedBox(height: 16),
          Text('Getting live location…'),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.red),
          const SizedBox(height: 16),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _teal),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
            onPressed: () => ref.invalidate(locationStreamProvider),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  double _calculateSpeed() {
    if (_breadcrumbs.length < 2) return 0;
    final p1 = _breadcrumbs[_breadcrumbs.length - 2];
    final p2 = _breadcrumbs.last;
    final dist = _haversine(p1, p2);
    // Assume ~10s between GPS points
    return dist / 10.0;
  }

  String _getDirection() {
    if (_breadcrumbs.length < 2) return 'N/A';
    final p1 = _breadcrumbs[_breadcrumbs.length - 2];
    final p2 = _breadcrumbs.last;
    final dLat = p2.latitude - p1.latitude;
    final dLng = p2.longitude - p1.longitude;
    if (dLat.abs() < 0.000001 && dLng.abs() < 0.000001) return 'Stationary';
    final angle = math.atan2(dLng, dLat) * 180 / math.pi;
    final bearing = (angle + 360) % 360;
    if (bearing < 22.5 || bearing >= 337.5) return 'North';
    if (bearing < 67.5) return 'North-East';
    if (bearing < 112.5) return 'East';
    if (bearing < 157.5) return 'South-East';
    if (bearing < 202.5) return 'South';
    if (bearing < 247.5) return 'South-West';
    if (bearing < 292.5) return 'West';
    return 'North-West';
  }

  double _haversine(LatLng p1, LatLng p2) {
    const r = 6371000.0;
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLng = (p2.longitude - p1.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _triggerSOS(BuildContext context) async {
    setState(() => _sosActive = true);

    try {
      // Write active: true to Firebase — ESP32 polls this and sounds buzzer
      await ref.read(cloudServiceProvider).sendBuzzerCommand(true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buzzer activated on collar!'),
          backgroundColor: _teal,
          duration: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reach collar — check GSM connection'),
          backgroundColor: Colors.red,
        ),
      );
      // Reset immediately on failure — no point waiting
      setState(() => _sosActive = false);
      return;
    }

    // Auto-stop after 10 seconds:
    // 1. Write active: false back to Firebase so the collar stops buzzing
    // 2. Reset the UI button
    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;

    try {
      // Tell the collar to stop — without this Firebase stays active: true forever
      await ref.read(cloudServiceProvider).sendBuzzerCommand(false);
    } catch (_) {
      // Non-critical — collar will timeout on its own via firmware watchdog
      debugPrint('Could not send buzzer stop command');
    }

    if (mounted) {
      setState(() => _sosActive = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _addZoneAtCenter(BuildContext context) async {
    // Get the current map center position
    final center = await _mapController?.getLatLng(
      ScreenCoordinate(
        x: (MediaQuery.of(context).size.width / 2).toInt(),
        y: (MediaQuery.of(context).size.height / 2).toInt(),
      ),
    );
    if (center == null || !context.mounted) return;

    final nameCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Safe Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Zone Name',
                hintText: 'e.g. Home, Park',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: radiusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius (meters)',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Center: ${center.latitude.toStringAsFixed(5)}, '
              '${center.longitude.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _teal),
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final radius = double.tryParse(radiusCtrl.text.trim()) ?? 100;
              final zone = Geofence(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                centerLatitude: center.latitude,
                centerLongitude: center.longitude,
                radiusInMeters: radius,
              );
              ref.read(geofenceProvider.notifier).addGeofence(zone);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Zone "$name" added!')),
              );
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
