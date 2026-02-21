import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_history_entry.dart';
import '../providers/location_provider.dart';
import '../services/location_history_service.dart';

class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends ConsumerState<LocationHistoryScreen> {
  static const Color _teal = Color(0xFF00897B);
  GoogleMapController? _mapController;
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(locationHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDate(context),
            tooltip: 'Filter by date',
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDate = null),
              tooltip: 'Clear filter',
            ),
        ],
      ),
      body: historyAsync.when(
        data: (history) {
          final filtered = _filterHistory(history);
          if (filtered.isEmpty) {
            return _buildEmpty();
          }
          return _buildContent(filtered);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: _teal),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  List<LocationHistoryEntry> _filterHistory(
      List<LocationHistoryEntry> history) {
    if (_selectedDate == null) return history;
    return history.where((e) {
      return e.timestamp.year == _selectedDate!.year &&
          e.timestamp.month == _selectedDate!.month &&
          e.timestamp.day == _selectedDate!.day;
    }).toList();
  }

  Widget _buildContent(List<LocationHistoryEntry> history) {
    final grouped = _groupByDate(history);
    final polylinePoints =
        history.map((e) => LatLng(e.latitude, e.longitude)).toList();
    final totalDistance =
        LocationHistoryService().calculateTotalDistance(history);

    return Column(
      children: [
        // Summary bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFE0F2F1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                Icons.pin_drop,
                '${history.length}',
                'Points',
              ),
              _buildSummaryItem(
                Icons.timeline,
                _formatDistance(totalDistance),
                'Total Distance',
              ),
              _buildSummaryItem(
                Icons.date_range,
                '${grouped.length}',
                'Days',
              ),
            ],
          ),
        ),

        // Map with path
        SizedBox(
          height: 220,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(history.first.latitude, history.first.longitude),
              zoom: 14,
            ),
            onMapCreated: (c) {
              _mapController = c;
              // Fit all points
              if (polylinePoints.length > 1) {
                _fitBounds(polylinePoints);
              }
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            markers: {
              // Most recent
              Marker(
                markerId: const MarkerId('latest'),
                position: polylinePoints.first,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: 'Latest',
                  snippet: _formatDateTime(history.first.timestamp),
                ),
              ),
              // Oldest
              if (polylinePoints.length > 1)
                Marker(
                  markerId: const MarkerId('oldest'),
                  position: polylinePoints.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(
                    title: 'Oldest',
                    snippet: _formatDateTime(history.last.timestamp),
                  ),
                ),
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('path'),
                points: polylinePoints,
                color: Colors.red,
                width: 3,
                patterns: [],
              ),
            },
            circles: {
              ...polylinePoints.asMap().entries.map((entry) {
                return Circle(
                  circleId: CircleId('point_${entry.key}'),
                  center: entry.value,
                  radius: 4,
                  fillColor: Colors.red,
                  strokeColor: Colors.white,
                  strokeWidth: 1,
                );
              }),
            },
          ),
        ),

        // History list grouped by date
        Expanded(
          child: ListView.builder(
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final date = grouped.keys.elementAt(index);
              final entries = grouped[date]!;
              final dayDistance =
                  LocationHistoryService().calculateTotalDistance(entries);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey.shade100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _teal,
                          ),
                        ),
                        Text(
                          '${entries.length} points • ${_formatDistance(dayDistance)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Entries for this date
                  ...entries.map((entry) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on,
                            color: _teal, size: 20),
                        title: Text(
                          '${entry.latitude.toStringAsFixed(5)}, ${entry.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          _formatTimeOnly(entry.timestamp),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: entry.accuracy != null
                            ? Text(
                                '±${entry.accuracy!.toStringAsFixed(0)}m',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              )
                            : null,
                        onTap: () {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(entry.latitude, entry.longitude),
                              17,
                            ),
                          );
                        },
                      )),
                  const Divider(height: 1),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedDate != null
                ? 'No history for ${_formatDate(_selectedDate!)}'
                : 'No location history yet',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _selectedDate = null),
              child: const Text('Show all history'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: _teal, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Map<DateTime, List<LocationHistoryEntry>> _groupByDate(
      List<LocationHistoryEntry> history) {
    final Map<DateTime, List<LocationHistoryEntry>> grouped = {};
    for (final entry in history) {
      final date = DateTime(
          entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      grouped.putIfAbsent(date, () => []).add(entry);
    }
    return grouped;
  }

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

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _teal),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dt) {
    return '${_formatDate(dt)} ${_formatTimeOnly(dt)}';
  }

  String _formatTimeOnly(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }
}
