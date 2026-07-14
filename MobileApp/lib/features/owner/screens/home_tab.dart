import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../auth/services/pet_authorization_module.dart';
import 'dashboard_widgets.dart';
import 'pet_details_form_page.dart';
import '../data/owner_repository.dart';
import '../location/screens/dashboard_screen.dart' show LocationDashboard;

const _kTeal = Color(0xFF009688);
const _kTealLight = Color(0xFFE0F2F1);
const _kTealMid = Color(0xFF4DB6AC);

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final OwnerRepository _repository = OwnerRepository();
  late Future<Map<String, dynamic>?> _petFuture;

  @override
  void initState() {
    super.initState();
    _petFuture = _repository.fetchUserPetWithId();
  }

  void _refreshPetData() {
    setState(() {
      _petFuture = _repository.fetchUserPetWithId();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const DashboardAppBar(title: 'Dashboard'),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _petFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }
          if (snapshot.hasError) {
            return _ErrorView(message: snapshot.error.toString());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _AddPetCardView(onAddComplete: _refreshPetData);
          }
          return _PetHomeBody(
            petData: snapshot.data!,
            repository: _repository,
          );
        },
      ),
    );
  }
}

class _PetHomeBody extends StatefulWidget {
  final Map<String, dynamic> petData;
  final OwnerRepository repository;
  const _PetHomeBody({required this.petData, required this.repository});

  @override
  State<_PetHomeBody> createState() => _PetHomeBodyState();
}

class _PetHomeBodyState extends State<_PetHomeBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _uploading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.petData['photoUrl'] as String?;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handlePhotoUpload() async {
    if (_uploading) return;

    final docId = widget.petData['_docId'];
    if (docId is! String || docId.isEmpty) {
      _showError('Cannot upload: pet record ID is missing.');
      return;
    }

    setState(() => _uploading = true);

    final newUrl = await widget.repository.pickAndUploadPhoto(
      docId: docId,
      onError: _showError,
    );

    if (mounted) {
      setState(() {
        if (newUrl != null) _photoUrl = newUrl;
        _uploading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.petData['petName'] as String? ?? 'Unnamed Pet';
    final rawSize = widget.petData['size'] as String? ?? 'Unknown';
    final shortSize = rawSize.split('·').first.trim();
    final rawAge = widget.petData['ageGroup'] as String? ?? 'Unknown';
    final shortAge = rawAge.split('·').first.trim();
    final petId = widget.petData['petId'] as String? ?? '';

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PetHeroCard(
                petName: petName,
                petSize: shortSize,
                petAge: shortAge,
                petId: petId,
                photoUrl: _photoUrl,
                uploading: _uploading,
                onPhotoTap: _handlePhotoUpload,
              ),
              const SizedBox(height: 24),
              const _StatusBanner(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI Sub-Widgets (No Logic Changes)
// ─────────────────────────────────────────────────────────────────────────────



class _PetHeroCard extends StatelessWidget {
  final String petName;
  final String petSize;
  final String petAge;
  final String petId;
  final String? photoUrl;
  final bool uploading;
  final VoidCallback onPhotoTap;

  const _PetHeroCard({
    required this.petName,
    required this.petSize,
    required this.petAge,
    required this.petId,
    required this.photoUrl,
    required this.uploading,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF0F766E), Color(0xFF145C67)]
        : const [Color(0xFF00897B), Color(0xFF26A69A)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kTeal.withOpacity(0.32),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPhotoTap,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.18),
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: uploading
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : _PetAvatar(photoUrl: photoUrl),
                ),
                if (!uploading)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 16, color: _kTeal),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      //const Icon(Icons.tag, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        //petId.isNotEmpty ? petId : 'Not Assigned',
                        'Pet ID: ${petId.isNotEmpty ? petId : 'Not Assigned'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  final String? photoUrl;
  const _PetAvatar({required this.photoUrl});
  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) return const _DefaultPetAvatar();
    return Image.network(photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _DefaultPetAvatar());
  }
}

class _DefaultPetAvatar extends StatelessWidget {
  const _DefaultPetAvatar();
  @override
  Widget build(BuildContext context) => Container(
      color: Colors.white10,
      child: const Icon(Icons.pets, color: Colors.white, size: 42));
}

class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

class _StatusBanner extends StatefulWidget {
  const _StatusBanner();

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner> {
  late Future<String> _dbPathFuture;

  @override
  void initState() {
    super.initState();
    _dbPathFuture = PetAuthorizationModule.instance.getPetDatabasePath();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<String>(
      future: _dbPathFuture,
      builder: (context, pathSnapshot) {
        final dbPath = pathSnapshot.data;

        if (pathSnapshot.connectionState == ConnectionState.waiting ||
            pathSnapshot.hasError ||
            dbPath == null ||
            dbPath.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator(
                color: _kTeal,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref(dbPath).onValue,
          builder: (context, eventSnapshot) {
            Map<dynamic, dynamic>? val;
            if (eventSnapshot.hasData && eventSnapshot.data!.snapshot.value != null) {
              final value = eventSnapshot.data!.snapshot.value;
              if (value is Map) {
                val = value;
              }
            }

            return _buildDashboardContent(context, val, isDark);
          },
        );
      },
    );
  }

  int? _getLatestTimestampMs(Map<dynamic, dynamic>? data) {
    if (data == null) return null;

    // 1. Try health timestamp
    final healthMap = data['health'] as Map?;
    final healthTs = healthMap?['timestamp'];
    if (healthTs != null) {
      if (healthTs is int) return healthTs;
      final parsed = DateTime.tryParse(healthTs.toString());
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }

    // 2. Try activity current timestamp
    final activityMap = data['activity'] as Map?;
    final currentActMap = activityMap?['current'] as Map?;
    final actTs = currentActMap?['timestamp'];
    if (actTs != null) {
      if (actTs is int) return actTs;
      final parsed = DateTime.tryParse(actTs.toString());
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }

    // 3. Try root timestamp
    final rootTs = data['timestamp'];
    if (rootTs != null) {
      if (rootTs is int) return rootTs;
      final parsed = DateTime.tryParse(rootTs.toString());
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }

    return null;
  }

  Widget _buildDashboardContent(
      BuildContext context, Map<dynamic, dynamic>? data, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    final latestTsMs = _getLatestTimestampMs(data);
    bool isOnline = false;
    if (latestTsMs != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = (nowMs - latestTsMs).abs() / 1000;
      isOnline = diffSeconds <= 60; // 60 seconds threshold for active telemetry
    } else {
      isOnline = data != null;
    }
    int batteryPercent = 100;
    int heartRate = 0;
    double temp = 0.0;
    int steps = 0;
    String actType = 'RESTING';
    bool impact = false;
    double? lat;
    double? lng;

    if (data != null) {
      final batteryMap = data['battery'] as Map?;
      batteryPercent = (batteryMap?['percentage'] ?? 100) as int;

      final healthMap = data['health'] as Map?;
      heartRate = (healthMap?['heart_rate'] ?? 0) as int;
      temp = (healthMap?['temperature'] ?? 0.0) as double;

      final activityMap = data['activity'] as Map?;
      final currentActMap = activityMap?['current'] as Map?;
      steps = (currentActMap?['step_count'] ?? 0) as int;
      actType = (currentActMap?['activity_type'] ?? 'RESTING')
          .toString()
          .toUpperCase();
      impact = (currentActMap?['impact_detected'] ?? false) as bool;

      final locationMap = data['current_location'] as Map?;
      if (locationMap != null) {
        lat = (locationMap['latitude'] ?? 0.0) as double;
        lng = (locationMap['longitude'] ?? 0.0) as double;
      }
    }

    final double stepProgress = (steps / 5000.0).clamp(0.0, 1.0);

    Color bannerBgColor;
    Color borderClr;
    Color iconBgColor;
    Color iconColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    if (!isOnline) {
      bannerBgColor = Colors.grey.shade100.withValues(alpha: isDark ? 0.08 : 0.95);
      borderClr = Colors.grey.withValues(alpha: 0.3);
      iconBgColor = Colors.grey.withValues(alpha: 0.12);
      iconColor = Colors.grey;
      statusIcon = Icons.offline_bolt_rounded;
      statusTitle = 'Collar Status: Offline';
      statusSubtitle = 'Collar is currently disconnected or offline.';
    } else if (impact) {
      bannerBgColor = Colors.red.shade50.withValues(alpha: isDark ? 0.08 : 0.95);
      borderClr = Colors.red.withValues(alpha: 0.3);
      iconBgColor = Colors.red.withValues(alpha: 0.12);
      iconColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
      statusTitle = 'Collar Status: Online (Alert)';
      statusSubtitle = 'Collar registered high acceleration collision.';
    } else {
      bannerBgColor = colorScheme.primaryContainer.withValues(alpha: isDark ? 0.08 : 0.7);
      borderClr = colorScheme.primary.withValues(alpha: 0.3);
      iconBgColor = _kTeal.withValues(alpha: 0.12);
      iconColor = _kTeal;
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Collar Status: Online';
      statusSubtitle = 'Collar is online and transmitting telemetry data.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. System Status Row / Alert Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderClr,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: impact ? Colors.red.shade800 : colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isOnline) _buildBatteryIndicator(context, batteryPercent),
            ],
          ),
        ),
        
        const SizedBox(height: 28),
        
        // Subtitle
        Text(
          'Live Telemetry Vitals',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        // 2. Metrics Cards Grid (Row & Column adaptive layout)
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context: context,
                icon: const _PulsatingHeartIcon(),
                title: 'Heart Rate',
                value: heartRate > 0 ? '$heartRate BPM' : '-- BPM',
                color: Colors.red,
                subtitle: heartRate > 120 ? 'Elevated pulse' : 'Normal vital bounds',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context: context,
                icon: const Icon(Icons.thermostat_outlined, color: Colors.orange, size: 20),
                title: 'Body Temp',
                value: temp > 0.0 ? '${temp.toStringAsFixed(1)} °C' : '-- °C',
                color: Colors.orange,
                subtitle: temp > 39.2 ? 'Slight fever' : 'Normal range',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context: context,
                icon: const Icon(Icons.directions_run_outlined, color: Colors.blue, size: 20),
                title: 'Steps Walked',
                value: '$steps steps',
                color: Colors.blue,
                subtitle: '${(stepProgress * 100).toInt()}% of daily goal',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context: context,
                icon: const Icon(Icons.pets_outlined, color: Colors.teal, size: 20),
                title: 'Active State',
                value: actType,
                color: Colors.teal,
                subtitle: actType == 'RESTING' ? 'Sleeping / Inactive' : 'Active mobility',
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // 3. Satellite Connection Link Card
        Text(
          'GPS Safe Zone Monitor',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white10 : Colors.blueGrey.shade50,
            ),
          ),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.satellite_alt_rounded,
                        color: Colors.indigo,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lat != null && lng != null ? 'GPS Signal Connected' : 'GPS Signal Searching...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lat != null && lng != null
                                ? 'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
                                : 'Collar is searching for satellites outdoor.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (lat != null && lng != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LocationDashboard(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text(
                        'Track Live Location',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required Widget icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.blueGrey.shade50,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.blueGrey.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: icon,
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator(BuildContext context, int percent) {
    final colorScheme = Theme.of(context).colorScheme;
    final clampedPercent = percent.clamp(0, 100);
    Color batteryColor;

    if (clampedPercent >= 80) {
      batteryColor = const Color(0xFF10B981); // Emerald Green
    } else if (clampedPercent >= 50) {
      batteryColor = const Color(0xFF10B981); // Emerald Green
    } else if (clampedPercent >= 20) {
      batteryColor = const Color(0xFFF59E0B); // Amber/Orange
    } else {
      batteryColor = const Color(0xFFEF4444); // Crimson Red
    }

    final double maxFillWidth = 24.0 - 4.8;
    double fillWidth = maxFillWidth * (clampedPercent / 100);
    if (clampedPercent > 0 && fillWidth < 2.0) {
      fillWidth = 2.0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 13,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3.5),
                  border: Border.all(
                    color: colorScheme.onSurface.withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(1.2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: batteryColor,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: batteryColor.withOpacity(0.35),
                          blurRadius: 2,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1.5,
                height: 5,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.35),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(1.2),
                    bottomRight: Radius.circular(1.2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '$clampedPercent%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsatingHeartIcon extends StatefulWidget {
  const _PulsatingHeartIcon();

  @override
  State<_PulsatingHeartIcon> createState() => _PulsatingHeartIconState();
}

class _PulsatingHeartIconState extends State<_PulsatingHeartIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartAnim;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _heartAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _heartAnim,
      child: const Icon(
        Icons.favorite_rounded,
        color: Colors.red,
        size: 20,
      ),
    );
  }
}

class _AddPetCardView extends StatelessWidget {
  final VoidCallback onAddComplete;
  const _AddPetCardView({required this.onAddComplete});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: _kTeal.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                      color: _kTealLight, shape: BoxShape.circle),
                  child: const Icon(Icons.pets, size: 40, color: _kTeal)),
              const SizedBox(height: 24),
              Text('Add your pet details',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PetDetailsFormPage()));
                    onAddComplete();
                  },
                  child: const Text('Add Pet Details',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(color: _kTeal, strokeWidth: 2.5));
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}
