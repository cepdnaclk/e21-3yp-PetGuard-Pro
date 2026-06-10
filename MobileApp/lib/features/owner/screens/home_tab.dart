import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../auth/services/pet_authorization_module.dart';
import 'dashboard_widgets.dart';
import 'pet_details_form_page.dart';
import '../data/owner_repository.dart';

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
              _Greeting(userName: widget.repository.getFirstName()),
              const SizedBox(height: 28),
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

class _Greeting extends StatelessWidget {
  final String userName;
  const _Greeting({required this.userName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $userName 👋',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Here's how your pet is doing today.",
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

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
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: FutureBuilder<String>(
        future: _dbPathFuture,
        builder: (context, pathSnapshot) {
          final dbPath = pathSnapshot.data;

          if (pathSnapshot.connectionState == ConnectionState.waiting ||
              pathSnapshot.hasError ||
              dbPath == null ||
              dbPath.isEmpty) {
            return _buildContentRow(context, null);
          }

          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('$dbPath/battery/percentage').onValue,
            builder: (context, batterySnapshot) {
              int? batteryPercent;
              if (batterySnapshot.hasData && batterySnapshot.data!.snapshot.value != null) {
                final value = batterySnapshot.data!.snapshot.value;
                if (value is num) {
                  batteryPercent = value.toInt();
                } else if (value is String) {
                  batteryPercent = int.tryParse(value);
                }
              }
              return _buildContentRow(context, batteryPercent);
            },
          );
        },
      ),
    );
  }

  Widget _buildContentRow(BuildContext context, int? batteryPercent) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(color: _kTeal, shape: BoxShape.circle),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All systems normal',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "Your pet's tracker is online and transmitting.",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (batteryPercent != null) ...[
          const SizedBox(width: 12),
          _buildBatteryIndicator(context, batteryPercent),
        ],
      ],
    );
  }

  Widget _buildBatteryIndicator(BuildContext context, int percent) {
    final colorScheme = Theme.of(context).colorScheme;
    IconData icon;
    Color iconColor;

    if (percent >= 80) {
      icon = Icons.battery_full_rounded;
      iconColor = Colors.green;
    } else if (percent >= 50) {
      icon = Icons.battery_4_bar_rounded;
      iconColor = Colors.green;
    } else if (percent >= 20) {
      icon = Icons.battery_3_bar_rounded;
      iconColor = Colors.orange;
    } else {
      icon = Icons.battery_alert_rounded;
      iconColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 4),
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
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
