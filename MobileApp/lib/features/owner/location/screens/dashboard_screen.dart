import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/location_provider.dart';
import '../services/location_history_service.dart';
import '../models/location_history_entry.dart';
import '../models/geofence.dart';
import '../models/pet_location.dart';
import 'location_tracking_screen.dart';
import 'history_screen.dart';
import 'manage_zones_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Schedule helper — must match the extension in manage_zones_screen.dart.
//  If GeofenceScheduleX is already exported from that file and visible here,
//  delete this duplicate and just use zone.schedule.isActiveNow directly.
// ─────────────────────────────────────────────────────────────────────────────
extension _ScheduleCheck on GeofenceSchedule {
  bool get isActiveNow {
    if (!isScheduled) return true;
    final now = DateTime.now();
    final dayIdx = now.weekday - 1; // 0 = Mon … 6 = Sun
    if (dayIdx < 0 || dayIdx >= activeDays.length) return false;
    if (!activeDays[dayIdx]) return false;

    final nowMins = now.hour * 60 + now.minute;
    final fromMins = fromHour * 60 + fromMinute;
    final toMins = toHour * 60 + toMinute;

    if (fromMins <= toMins) {
      return nowMins >= fromMins && nowMins <= toMins;
    } else {
      // Overnight range e.g. 22:00–06:00
      return nowMins >= fromMins || nowMins <= toMins;
    }
  }
}

class LocationDashboard extends ConsumerStatefulWidget {
  const LocationDashboard({super.key});

  @override
  ConsumerState<LocationDashboard> createState() => _LocationDashboardState();
}

class _LocationDashboardState extends ConsumerState<LocationDashboard>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF00897B);
  static const Color _safe = Color(0xFF00897B);
  static const Color _warn = Color(0xFFF57F17);
  static const Color _alert = Color(0xFFC62828);

  GoogleMapController? _miniMapController;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _miniMapController?.dispose();
    super.dispose();
  }

  // ── Helper: is the pet effectively inside a given zone right now? ─────────
  //
  // FIX 1: always pass `geofence: zone` so polygon zones are evaluated
  //         with the full point-in-polygon algorithm, not just centre distance.
  // FIX 2: gate on `zone.schedule.isActiveNow` so scheduled-off zones are
  //         treated as inactive for both status display AND breach detection.
  bool _isPetInsideZone(
    PetLocation location,
    Geofence zone,
  ) {
    // A zone that is disabled by schedule is treated as if it were inactive.
    if (!zone.isActive) return false;
    if (!zone.schedule.isActiveNow) return false;

    return ref.read(locationServiceProvider).isWithinGeofence(
          currentLat: location.latitude,
          currentLng: location.longitude,
          centerLat: zone.centerLatitude,
          centerLng: zone.centerLongitude,
          radiusInMeters: zone.radiusInMeters,
          geofence: zone, // ← CRITICAL: polygon PIP check lives here
        );
  }

  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationStreamProvider);
    final geofenceState = ref.watch(geofenceProvider);
    final historyAsync = ref.watch(recentLocationsProvider);

    ref.watch(geofenceMonitorProvider);
    ref.watch(locationHistorySaverProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'GPS Tracking',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Full Map',
            onPressed: () => _openLiveMap(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () async => ref.invalidate(locationStreamProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: locationAsync.when(
            data: (location) =>
                _buildContent(context, location, geofenceState, historyAsync),
            loading: () => _buildLoading(),
            error: (err, _) => _buildError(err),
          ),
        ),
      ),
    );
  }

  // ── Main content ────────────────────────────────────────────────────────────
  Widget _buildContent(
    BuildContext context,
    PetLocation location,
    GeofenceState geofenceState,
    AsyncValue<List<LocationHistoryEntry>> historyAsync,
  ) {
    // FIX: only count a zone as "active" when both the master switch is on
    // AND the schedule window currently covers this moment.
    final effectivelyActiveZones = geofenceState.geofences
        .where((z) => z.isActive && z.schedule.isActiveNow)
        .toList();

    // FIX: use _isPetInsideZone (passes geofence: z, checks schedule)
    final insideZones = effectivelyActiveZones
        .where((z) => _isPetInsideZone(location, z))
        .toList();

    // A "breach" is any effectively-active zone the pet is currently outside.
    final breachedZones = effectivelyActiveZones
        .where((z) => !_isPetInsideZone(location, z))
        .toList();

    _PetStatus status;
    String statusTitle;
    String statusSubtitle;
    Color statusColor;
    IconData statusIcon;

    if (effectivelyActiveZones.isEmpty) {
      // No zones active right now (either none defined, all disabled, or all
      // outside their schedule window).
      status = _PetStatus.wandering;
      statusTitle = geofenceState.geofences.isEmpty
          ? 'No Safe Zones Set'
          : 'No Active Zones Right Now';
      statusSubtitle = geofenceState.geofences.isEmpty
          ? 'Add a safe zone to start monitoring'
          : 'All zones are inactive or outside schedule';
      statusColor = _warn;
      statusIcon = Icons.add_location_alt_outlined;
    } else if (insideZones.isNotEmpty) {
      // Pet is inside at least one active zone.
      status = _PetStatus.safe;
      statusTitle = 'Your Pet is at ${insideZones.first.name}';
      statusSubtitle = 'Within active safe zone · Updated now';
      statusColor = _safe;
      statusIcon = Icons.check_circle_rounded;
    } else {
      // Pet is outside every active zone → alert.
      status = _PetStatus.alert;
      statusTitle = 'Pet Outside Safe Zone!';
      statusSubtitle = 'Outside ${breachedZones.map((b) => b.name).join(", ")}';
      statusColor = _alert;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroCard(
          status: status,
          title: statusTitle,
          subtitle: statusSubtitle,
          color: statusColor,
          icon: statusIcon,
          location: location,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildMiniMap(location, geofenceState, statusColor),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: historyAsync.when(
            data: (h) => _buildTodaySummary(h, location),
            loading: () => _buildTodaySummary([], location),
            error: (_, __) => _buildTodaySummary([], location),
          ),
        ),
        const SizedBox(height: 12),
        if (geofenceState.geofences.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildZoneStatusList(location, geofenceState),
          ),
        if (geofenceState.geofences.isNotEmpty) const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: historyAsync.when(
            data: (h) => _buildRecentTimeline(h),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildQuickActions(context, location),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Hero Status Card ──────────────────────────────────────────────────────
  Widget _buildHeroCard({
    required _PetStatus status,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required PetLocation location,
  }) {
    final diff = DateTime.now().difference(location.timestamp);
    final isLive = diff.inSeconds < 30;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.75)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: status == _PetStatus.alert ? _pulseAnim.value : 1.0,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 36, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.white.withValues(alpha: _pulseAnim.value)
                          : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isLive ? 'Live' : _formatTimeShort(location.timestamp),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.gps_fixed,
                    size: 12, color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 4),
                Text(
                  '±${location.accuracy?.toStringAsFixed(0) ?? '?'}m',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Mini Live Map ─────────────────────────────────────────────────────────
  Widget _buildMiniMap(
    PetLocation location,
    GeofenceState geofenceState,
    Color statusColor,
  ) {
    final petPos = LatLng(location.latitude, location.longitude);

    return GestureDetector(
      onTap: () => _openLiveMap(context),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: petPos, zoom: 15.5),
            onMapCreated: (c) => _miniMapController = c,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('pet'),
                position: petPos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: const InfoWindow(title: 'Your Pet'),
              ),
            },
            // Only draw zones that are currently effectively active
            circles: geofenceState.geofences
                .where((f) => f.isActive && f.schedule.isActiveNow)
                .map((f) => Circle(
                      circleId: CircleId(f.id),
                      center: LatLng(f.centerLatitude, f.centerLongitude),
                      radius: f.radiusInMeters,
                      fillColor: _primary.withValues(alpha: 0.15),
                      strokeColor: _primary,
                      strokeWidth: 2,
                    ))
                .toSet(),
            polygons: geofenceState.geofences
                .where((f) =>
                    f.isActive &&
                    f.schedule.isActiveNow &&
                    f.zoneType == GeofenceType.polygon &&
                    f.polygonPoints.length >= 3)
                .map((f) => Polygon(
                      polygonId: PolygonId(f.id),
                      points: f.polygonPoints,
                      fillColor: _primary.withValues(alpha: 0.15),
                      strokeColor: _primary,
                      strokeWidth: 2,
                    ))
                .toSet(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(children: [
                const Icon(Icons.touch_app, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                const Text('Tap to open full map',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                Text(
                  '${location.latitude.toStringAsFixed(4)}, '
                  '${location.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Today's Activity Summary ──────────────────────────────────────────────
  Widget _buildTodaySummary(
      List<LocationHistoryEntry> history, PetLocation location) {
    final today = DateTime.now();
    final todayHistory = history
        .where((e) =>
            e.timestamp.year == today.year &&
            e.timestamp.month == today.month &&
            e.timestamp.day == today.day)
        .toList();

    final distance = LocationHistoryService()
        .calculateTotalDistance(todayHistory.cast<LocationHistoryEntry>());

    final lastMoved = todayHistory.isNotEmpty
        ? todayHistory.first.timestamp
        : location.timestamp;
    final minSince = DateTime.now().difference(lastMoved).inMinutes;
    final lastMovedStr = minSince < 1
        ? 'Just now'
        : minSince < 60
            ? '${minSince}m ago'
            : '${(minSince / 60).floor()}h ${minSince % 60}m ago';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.today, color: _primary, size: 18),
            const SizedBox(width: 8),
            const Text('Today',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(Icons.pets, _formatDistance(distance), 'Walked',
                  Colors.blue.shade600),
              _buildVertDivider(),
              _buildStat(Icons.access_time_rounded, lastMovedStr, 'Last moved',
                  Colors.orange.shade700),
              _buildVertDivider(),
              _buildStat(
                Icons.local_activity,
                todayHistory.length > 1
                    ? _formatDuration(todayHistory.last.timestamp
                        .difference(todayHistory.first.timestamp)
                        .abs())
                    : '0m',
                'Active time',
                _primary,
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    ]);
  }

  Widget _buildVertDivider() =>
      Container(width: 1, height: 44, color: Colors.grey.shade200);

  // ── Zone Status List ──────────────────────────────────────────────────────
  Widget _buildZoneStatusList(
      PetLocation location, GeofenceState geofenceState) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.shield_outlined, color: _primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Safe Zones',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                TextButton(
                  onPressed: () => _openManageZones(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  child: const Text('Edit', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...geofenceState.geofences.map((zone) {
              // FIX: honour schedule when determining dot colour & status text
              final scheduleActive = zone.schedule.isActiveNow;
              final effectivelyActive = zone.isActive && scheduleActive;

              // FIX: pass geofence: zone so polygon PIP is used
              final isInside =
                  effectivelyActive && _isPetInsideZone(location, zone);

              Color dotColor;
              String zoneStatus;

              if (!zone.isActive) {
                dotColor = Colors.grey;
                zoneStatus = 'Inactive';
              } else if (!scheduleActive) {
                // Zone is enabled but currently outside its schedule window
                dotColor = Colors.blueGrey;
                zoneStatus = 'Outside schedule';
              } else if (isInside) {
                dotColor = _safe;
                zoneStatus = 'Pet is here ✓';
              } else {
                dotColor = _warn;
                final dist = _approxDistance(
                  location.latitude,
                  location.longitude,
                  zone.centerLatitude,
                  zone.centerLongitude,
                );
                zoneStatus = '${_formatDistance(dist)} away';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(zone.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                  ),
                  Text(
                    zoneStatus,
                    style: TextStyle(
                      fontSize: 13,
                      color: !zone.isActive
                          ? Colors.grey
                          : !scheduleActive
                              ? Colors.blueGrey
                              : dotColor,
                      fontWeight:
                          isInside ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Recent Timeline ───────────────────────────────────────────────────────
  Widget _buildRecentTimeline(List<LocationHistoryEntry> history) {
    if (history.isEmpty) return const SizedBox();
    final events = _buildTimelineEvents(history.take(8).toList());
    if (events.isEmpty) return const SizedBox();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.timeline, color: _primary, size: 18),
              const SizedBox(width: 8),
              const Text('Recent Activity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            ...events.take(5).map(_buildTimelineEvent),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEvent(_TimelineEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: event.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(event.icon, size: 15, color: event.color),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(event.label, style: const TextStyle(fontSize: 13))),
        Text(_formatTimeOnly(event.time),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, PetLocation location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: _buildActionButton(
                  icon: Icons.map_rounded,
                  label: 'Live Map',
                  color: _primary,
                  onTap: () => _openLiveMap(context))),
          const SizedBox(width: 10),
          Expanded(
              child: _buildActionButton(
                  icon: Icons.shield_rounded,
                  label: 'Edit Zones',
                  color: Colors.green.shade700,
                  onTap: () => _openManageZones(context))),
          const SizedBox(width: 10),
          Expanded(
              child: _buildActionButton(
                  icon: Icons.history_rounded,
                  label: 'Full History',
                  color: Colors.orange.shade700,
                  onTap: () => _openHistory(context))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _buildActionButton(
                  icon: Icons.volume_up_rounded,
                  label: 'Find Pet',
                  color: Colors.deepPurple,
                  onTap: () => _triggerFindMyPet(context))),
          const SizedBox(width: 10),
          Expanded(
              child: _buildActionButton(
                  icon: Icons.home_rounded,
                  label: 'Set Home',
                  color: Colors.blue.shade700,
                  onTap: () => _setHomeZone(context, location))),
          const SizedBox(width: 10),
          Expanded(
              child: _buildActionButton(
                  icon: Icons.share_location_rounded,
                  label: 'Share',
                  color: Colors.teal.shade700,
                  onTap: () => _shareLocation(context, location))),
        ]),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
        ]),
      ),
    );
  }

  // ── Loading / Error ───────────────────────────────────────────────────────
  Widget _buildLoading() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: _primary),
          const SizedBox(height: 16),
          Text('Getting pet location…',
              style: TextStyle(color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _buildError(Object error) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.red),
          const SizedBox(height: 16),
          Text(error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
            onPressed: () => ref.invalidate(locationStreamProvider),
          ),
        ]),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _openLiveMap(BuildContext context) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const LocationTrackingScreen()));

  void _openManageZones(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const ManageZonesScreen()));

  void _openHistory(BuildContext context) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const LocationHistoryScreen()));

  // ── Action handlers ───────────────────────────────────────────────────────
  Future<void> _triggerFindMyPet(BuildContext context) async {
    final cloudSvc = ref.read(cloudServiceProvider);
    try {
      // ✅ Step 1: Send true to activate buzzer
      await cloudSvc.sendBuzzerCommand(true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🔔 Buzzer triggered on collar!'),
        backgroundColor: Color(0xFF00897B),
        duration: Duration(seconds: 10), // Show for 10 seconds
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not reach collar — is it online?'),
          backgroundColor: Colors.red));
      return; // Don't continue if initial command failed
    }

    // ✅ Step 2: Wait 10 seconds
    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;

    // ✅ Step 3: Send false to turn off buzzer
    try {
      await cloudSvc.sendBuzzerCommand(false);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (_) {
      // Non-critical — collar's 2-minute watchdog will stop it
      debugPrint('Could not send buzzer stop command');
    }
  }

  void _setHomeZone(BuildContext context, PetLocation location) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set Home Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "Mark your pet's current location as the Home safe zone?"),
            const SizedBox(height: 8),
            Text(
              '${location.latitude.toStringAsFixed(5)}, '
              '${location.longitude.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            onPressed: () {
              final homeZone = Geofence(
                id: 'home_${DateTime.now().millisecondsSinceEpoch}',
                name: 'Home',
                centerLatitude: location.latitude,
                centerLongitude: location.longitude,
                radiusInMeters: 100,
              );
              ref.read(geofenceProvider.notifier).addGeofence(homeZone);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('🏠 Home zone set (100m radius)'),
                  backgroundColor: Color(0xFF00897B)));
            },
            child:
                const Text('Set Home', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _shareLocation(BuildContext context, PetLocation location) {
    final url =
        'https://maps.google.com/?q=${location.latitude},${location.longitude}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Share Location'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share this link to show your pet\'s current location:'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(url,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')));
            },
            child:
                const Text('Copy Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Timeline helpers ──────────────────────────────────────────────────────
  List<_TimelineEvent> _buildTimelineEvents(
      List<LocationHistoryEntry> history) {
    if (history.isEmpty) return [];
    if (history.length < 2) {
      return [
        _TimelineEvent(
          icon: Icons.location_on,
          label: 'Location recorded',
          time: history.first.timestamp,
          color: _primary,
        ),
      ];
    }

    final events = <_TimelineEvent>[];
    events.add(_TimelineEvent(
      icon: Icons.my_location,
      label: 'Location updated',
      time: history.first.timestamp,
      color: _primary,
    ));

    for (int i = 1; i < history.length - 1; i++) {
      final prev = history[i + 1];
      final curr = history[i];
      final dist = _approxDistance(
          prev.latitude, prev.longitude, curr.latitude, curr.longitude);
      final timeDiff = curr.timestamp.difference(prev.timestamp).inMinutes;

      if (dist < 50 && timeDiff > 5) {
        events.add(_TimelineEvent(
          icon: Icons.pause_circle_outline,
          label: 'Stationary for ~${timeDiff}min',
          time: curr.timestamp,
          color: Colors.orange.shade700,
        ));
      } else if (dist > 200) {
        events.add(_TimelineEvent(
          icon: Icons.directions_walk,
          label: 'Moved ${_formatDistance(dist)}',
          time: curr.timestamp,
          color: Colors.blue.shade700,
        ));
      }
    }
    return events;
  }

  // ── Utility ───────────────────────────────────────────────────────────────
  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '<1m';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  String _formatTimeShort(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeOnly(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  String _formatDistance(double meters) => meters < 1000
      ? '${meters.toStringAsFixed(0)}m'
      : '${(meters / 1000).toStringAsFixed(1)}km';

  double _approxDistance(double lat1, double lon1, double lat2, double lon2) {
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

// ── Enums & data classes ─────────────────────────────────────────────────────
enum _PetStatus { safe, wandering, alert }

class _TimelineEvent {
  final IconData icon;
  final String label;
  final DateTime time;
  final Color color;
  const _TimelineEvent({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });
}
