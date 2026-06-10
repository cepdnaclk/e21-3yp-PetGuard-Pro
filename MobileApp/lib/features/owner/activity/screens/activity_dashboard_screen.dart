// lib/features/owner/activity/screens/activity_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/activity_provider.dart';
import '../models/activity_data.dart';

class ActivityDashboardScreen extends ConsumerStatefulWidget {
  const ActivityDashboardScreen({super.key});

  @override
  ConsumerState<ActivityDashboardScreen> createState() =>
      _ActivityDashboardScreenState();
}

class _ActivityDashboardScreenState
    extends ConsumerState<ActivityDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _primary = Color(0xFF009688);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PgColors.page,
      appBar: AppBar(
        title: const Text('Activity Monitor'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.favorite_border), text: 'Live'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Summary'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LiveTab(),
          _SummaryTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR & DECORATION HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _PgColors {
  static const Color primary     = Color(0xFF009688);
  static const Color primaryDark = Color(0xFF00796B);
  static const Color page        = Color(0xFFF4F7F7);
  static const Color card        = Colors.white;
  static const Color soft        = Color(0xFFEAF7F5);
  static const Color soft2       = Color(0xFFF1FBF9);
  static const Color text        = Color(0xFF143237);
  static const Color subtext     = Color(0xFF6D8387);
  static const Color border      = Color(0xFFDCE9E7);
  static const Color warning     = Color(0xFFF57C00);
  static const Color danger      = Color(0xFFD32F2F);
  static const Color success     = Color(0xFF2E7D32);
}

class _PgDecor {
  static BorderRadius get xl => BorderRadius.circular(24);
  static BorderRadius get lg => BorderRadius.circular(20);

  static BoxDecoration card({
    Color color = _PgColors.card,
    Color border = _PgColors.border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: xl,
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY HELPERS
// Pet-appropriate emoji for each activity type (shown as watermark on hero).
// No human icons used anywhere.
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a pet-appropriate emoji for the hero card watermark.
String _activityEmoji(String type) {
  switch (type.toLowerCase()) {
    case 'walking':  return '🐾';
    case 'running':  return '💨';
    case 'resting':  return '🌙';
    case 'playing':  return '🦴';
    case 'impact':   return '⚠️';
    default:         return '🐾';
  }
}

/// Returns a neutral (non-human) Material icon for each activity.
/// Used only in history tiles and stat strips — NOT in the hero card.
IconData _activityIcon(String type) {
  switch (type.toLowerCase()) {
    case 'walking':  return Icons.pets_rounded;          // paw print
    case 'running':  return Icons.bolt_rounded;          // energy / speed
    case 'resting':  return Icons.bedtime_outlined;      // moon / sleep
    case 'playing':  return Icons.sports_tennis_rounded; // ball / play
    case 'impact':   return Icons.warning_amber_rounded; // alert
    default:         return Icons.monitor_heart_outlined;
  }
}

String _activityTitle(String type) {
  if (type.isEmpty) return 'Unknown';
  final lower = type.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

String _formatTime(DateTime dt) {
  return '${dt.day}/${dt.month}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 · LIVE
// No scroll. 3 zones: hero → steps+minutes → impact.
// Hero shows emoji watermark + big activity name. No icon in the bubble.
// ─────────────────────────────────────────────────────────────────────────────

class _LiveTab extends ConsumerWidget {
  const _LiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(currentActivityProvider);

    return activityAsync.when(
      data: (activity) {
        if (activity == null) {
          return const _NoDataCard(
            message:
                'No live activity data yet.\nData will appear once the collar sensor is connected.',
          );
        }
        return _LiveLayout(activity: activity);
      },
      loading: () => const _LoadingCard(),
      error: (e, _) => Center(child: _ErrorCard(error: e)),
    );
  }
}

class _LiveLayout extends StatelessWidget {
  final ActivityData activity;
  const _LiveLayout({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Activity hero ───────────────────────────────────────────────
          Expanded(flex: 5, child: _ActivityHeroCard(activity: activity)),
          const SizedBox(height: 14),

          // ── 2. Steps + Active Minutes ──────────────────────────────────────
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: _LiveStatCard(
                    icon: Icons.pets_rounded,
                    label: 'Steps',
                    value: '${activity.stepCount}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LiveStatCard(
                    icon: Icons.timer_outlined,
                    label: 'Active Minutes',
                    value: '${activity.activeMinutes.toStringAsFixed(0)} min',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 3. Impact alert ────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: _ImpactAlertCard(
              detected: activity.impactDetected,
              severity: activity.impactSeverity,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero card — emoji watermark + big text, NO icon bubble ───────────────────

class _ActivityHeroCard extends StatelessWidget {
  final ActivityData activity;
  const _ActivityHeroCard({required this.activity});

  // Per-activity gradient pairs (start, end)
  /*
  static const Map<String, List<Color>> _gradients = {
    'walking': [Color(0xFF10B5A7), Color(0xFF009688)],
    'running': [Color(0xFF29B6F6), Color(0xFF0288D1)],
    'resting': [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
    'playing': [Color(0xFFFFA726), Color(0xFFF57C00)],
    'impact':  [Color(0xFFE86D5B), Color(0xFFD84F43)],
  };
  */


  //static const List<Color> _impactGrad = [Color(0xFFE86D5B), Color(0xFFD84F43)];

  static const List<Color> _fixedGradient = [Color(0xFF10B5A7), Color(0xFF009688)];

  @override
  Widget build(BuildContext context) {
    //final key    = activity.activityType.toLowerCase();
    /*
    final grad   = activity.impactDetected
        ? _impactGrad
        : (_gradients[key] ?? _gradients['walking']!);
    */
    final grad = _fixedGradient;
    final shadow = _PgColors.primary; // Always use primary color for shadow
    final label = _activityTitle(activity.activityType);
    //final shadow = activity.impactDetected ? _PgColors.danger : _PgColors.primary;
    //final label  = activity.impactDetected ? 'Impact!' : _activityTitle(activity.activityType);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: grad,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: _PgDecor.xl,
        boxShadow: [
          BoxShadow(
            color: shadow.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Text(
                  'Current Activity',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),

                const Spacer(),

                // Big activity name
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 14),

                // Timestamp pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Updated ${_formatTime(activity.timestamp)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );     
    
  }
}

// ── Metric cards (steps / active minutes) ─────────────────────────────────────

class _LiveStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LiveStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _PgColors.soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _PgColors.primary, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _PgColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _PgColors.subtext),
          ),
        ],
      ),
    );
  }
}

// ── Impact alert card ─────────────────────────────────────────────────────────

class _ImpactAlertCard extends StatelessWidget {
  final bool detected;
  final double severity;

  const _ImpactAlertCard({
    required this.detected,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final high      = detected && severity >= 7.0;
    final accent    = !detected ? _PgColors.primary : high ? _PgColors.danger : _PgColors.warning;
    final bg        = !detected
        ? const Color(0xFFEFF8F4)
        : high ? const Color(0xFFFFEFEE) : const Color(0xFFFFF5EA);
    final borderCol = !detected
        ? const Color(0xFFBBDDD5)
        : high ? const Color(0xFFF4C7C1) : const Color(0xFFF6D9B8);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _PgDecor.lg,
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              !detected ? Icons.shield_outlined : Icons.warning_amber_rounded,
              color: accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  !detected
                      ? 'All Clear'
                      : high ? 'High Impact Detected!' : 'Impact Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  !detected
                      ? 'No abnormal impact detected'
                      : 'Severity: ${severity.toStringAsFixed(1)} / 10',
                  style: const TextStyle(
                    color: _PgColors.subtext,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (detected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                high ? 'HIGH' : 'MED',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 · SUMMARY
// Reads from todayAsSummaryListProvider which aggregates today's history
// entries (midnight → now) directly from Firebase history node.
// This fixes the 0-step issue caused by the missing daily_summary node.
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch todayAsSummaryListProvider — aggregates history entries from
    // midnight to now. The DB has no daily_summary node, so dailySummariesProvider
    // always returned empty. This provider computes the same data on the fly.
    final summariesAsync = ref.watch(todayAsSummaryListProvider);
    final impactAsync    = ref.watch(impactAlertsProvider);

    return RefreshIndicator(
      color: _PgColors.primary,
      onRefresh: () async {
        // Invalidate history so the aggregation re-runs with fresh data
        ref.invalidate(activityHistoryProvider);
        ref.invalidate(impactAlertsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            summariesAsync.when(
              data: (summaries) {
                final totalSteps =
                    summaries.fold(0, (sum, s) => sum + s.totalSteps);
                final totalMins =
                    summaries.fold(0.0, (sum, s) => sum + s.totalActiveMinutes);
                final totalImpacts =
                    summaries.fold(0, (sum, s) => sum + s.impactCount);
                return _StatChipsRow(
                  totalSteps: totalSteps,
                  totalMins: totalMins,
                  totalImpacts: totalImpacts,
                );
              },
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(error: e),
            ),
            const SizedBox(height: 22),
            const Text(
              'Recent Impacts',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _PgColors.text),
            ),
            const SizedBox(height: 4),
            const Text(
              'Last 10 impact events recorded by the collar',
              style: TextStyle(fontSize: 13, color: _PgColors.subtext),
            ),
            const SizedBox(height: 14),
            impactAsync.when(
              data: (impacts) {
                if (impacts.isEmpty) {
                  return const _NoDataCard(
                      message: 'No impacts recorded. Your pet is safe! 🐾');
                }
                return Column(
                  children: impacts
                      .take(10)
                      .map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ImpactListTile(activity: i),
                          ))
                      .toList(),
                );
              },
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(error: e),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChipsRow extends StatelessWidget {
  final int totalSteps;
  final double totalMins;
  final int totalImpacts;
  const _StatChipsRow(
      {required this.totalSteps,
      required this.totalMins,
      required this.totalImpacts});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: _StatChip(
              icon: Icons.pets_rounded,
              value: '$totalSteps',
              label: 'Total Steps')),
      const SizedBox(width: 10),
      Expanded(
          child: _StatChip(
              icon: Icons.timer_outlined,
              value: '${totalMins.toStringAsFixed(0)} m',
              label: 'Active Time')),
      const SizedBox(width: 10),
      Expanded(
          child: _StatChip(
              icon: Icons.warning_amber_rounded,
              value: '$totalImpacts',
              label: 'Impacts',
              accent: totalImpacts > 0 ? _PgColors.danger : _PgColors.primary)),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  const _StatChip(
      {required this.icon,
      required this.value,
      required this.label,
      this.accent = _PgColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                color: accent, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: _PgColors.subtext)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 · HISTORY  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(activityHistoryProvider);

    return RefreshIndicator(
      color: _PgColors.primary,
      onRefresh: () async => ref.invalidate(activityHistoryProvider),
      child: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: _NoDataCard(
                  message:
                      'No history yet.\nAdd data to Firebase to see logs here.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _HistoryTile(activity: history[i]),
          );
        },
        loading: () => const Center(child: _LoadingCard()),
        error: (e, _) => Center(child: _ErrorCard(error: e)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactListTile extends StatelessWidget {
  final ActivityData activity;
  const _ImpactListTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final high = activity.impactSeverity >= 7.0;
    return Container(
      decoration: _PgDecor.card(
          color: high ? const Color(0xFFFFF5F4) : _PgColors.card),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: high ? const Color(0xFFFFE2DF) : const Color(0xFFFFF1DE),
              borderRadius: BorderRadius.circular(16)),
          child: Icon(Icons.warning_amber_rounded,
              color: high ? _PgColors.danger : _PgColors.warning),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'Severity: ${activity.impactSeverity.toStringAsFixed(1)} / 10',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: _PgColors.text)),
            const SizedBox(height: 4),
            Text(
                '${activity.timestamp.day}/${activity.timestamp.month} at '
                '${activity.timestamp.hour.toString().padLeft(2, '0')}:'
                '${activity.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: _PgColors.subtext, fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
              color: high ? _PgColors.danger : _PgColors.warning,
              borderRadius: BorderRadius.circular(999)),
          child: Text(high ? 'HIGH' : 'MED',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ActivityData activity;
  const _HistoryTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        // Removed the emoji badge container
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_activityTitle(activity.activityType),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _PgColors.text,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Text(
                '${activity.timestamp.day}/${activity.timestamp.month}  '
                '${activity.timestamp.hour.toString().padLeft(2, '0')}:'
                '${activity.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: _PgColors.subtext, fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${activity.stepCount} steps',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _PgColors.text)),
          const SizedBox(height: 4),
          if (activity.impactDetected)
            const Text('Impact',
                style: TextStyle(
                    color: _PgColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: const Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: _PgColors.primary),
        SizedBox(height: 16),
        Text('Loading activity data...',
            style: TextStyle(fontWeight: FontWeight.w700, color: _PgColors.text)),
        SizedBox(height: 6),
        Text('Fetching the latest collar data.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _PgColors.subtext, fontSize: 12)),
      ]),
    );
  }
}

class _NoDataCard extends StatelessWidget {
  final String message;
  const _NoDataCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
              color: _PgColors.soft, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.sensors_off_outlined,
              color: _PgColors.primary, size: 30),
        ),
        const SizedBox(height: 16),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _PgColors.subtext, fontSize: 14, height: 1.4)),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object error;
  const _ErrorCard({required this.error});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3F2),
          borderRadius: _PgDecor.lg,
          border: Border.all(color: const Color(0xFFF2D2CE))),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Icon(Icons.error_outline, color: _PgColors.danger),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Error: $error',
                style: const TextStyle(color: _PgColors.danger))),
      ]),
    );
  }
}