// lib/features/owner/activity/screens/activity_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/activity_provider.dart';
import '../models/activity_data.dart';
import 'package:fl_chart/fl_chart.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LiveTab(),
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
          //Expanded(flex: 4, child: _ActivityHeroCard(activity: activity)),
          _ActivityHeroCard(activity: activity),
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
/*
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
                    fontSize: 30,
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
*/
// REPLACE _ActivityHeroCard entirely:

class _ActivityHeroCard extends StatelessWidget {
  final ActivityData activity;
  const _ActivityHeroCard({required this.activity});

  static const List<Color> _fixedGradient = [
    Color(0xFF10B5A7),
    Color(0xFF009688),
  ];

  static const _levelLabels = ['Resting', 'Light', 'Moderate', 'Active'];

  @override
  Widget build(BuildContext context) {
    final label = _activityTitle(activity.activityType);
    final level = activity.activityLevel.clamp(0, 3);
    final now   = activity.timestamp;

    final dateStr =
        '${now.day}/${now.month}/${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _fixedGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: _PgDecor.xl,
        boxShadow: [
          BoxShadow(
            color: _PgColors.primary.withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Top row: label + date/time ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Activity',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.80),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Activity name + level dots ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // 4 level dots
              Row(
                children: List.generate(4, (i) => Container(
                  margin: const EdgeInsets.only(left: 5),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= level
                        ? Colors.white
                        : Colors.white.withOpacity(0.25),
                  ),
                )),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Level label ─────────────────────────────────────────────
          Text(
            'Level ${level + 1} · ${_levelLabels[level]}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
// TAB 2 · HISTORY  — chart + gantt + calendar + stats
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();
  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(activityHistoryProvider);

    return historyAsync.when(
      data: (history) {
        // Filter to selected date
        final dayEntries = history.where((e) {
          final d = e.timestamp;
          return d.year == _selectedDate.year &&
              d.month == _selectedDate.month &&
              d.day == _selectedDate.day;
        }).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return RefreshIndicator(
          color: _PgColors.primary,
          onRefresh: () async => ref.invalidate(activityHistoryProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date picker row ────────────────────────────────────────
                _DatePickerRow(
                  selected: _selectedDate,
                  onChanged: (d) => setState(() => _selectedDate = d),
                ),
                const SizedBox(height: 16),

                if (dayEntries.isEmpty)
                  _NoDataCard(
                    message:
                        'No activity recorded for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}.',
                  )
                else ...[
                  // ── Line chart ─────────────────────────────────────────
                  _ActivityLineChart(entries: dayEntries),
                  const SizedBox(height: 14),

                  // ── Gantt band ─────────────────────────────────────────
                  _GanttBand(entries: dayEntries),
                  const SizedBox(height: 14),

                  // ── Summary stats ──────────────────────────────────────
                  _DaySummaryStats(entries: dayEntries),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: _LoadingCard()),
      error: (e, _) => Center(child: _ErrorCard(error: e)),
    );
  }
}

// ── Date picker row ───────────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  const _DatePickerRow({required this.selected, required this.onChanged});

  String _label(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Activity History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _PgColors.text,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selected,
              firstDate: DateTime.now().subtract(const Duration(days: 90)),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: _PgColors.primary,
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _PgColors.soft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _PgColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 15, color: _PgColors.primary),
                const SizedBox(width: 5),
                Text(
                  _label(selected),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _PgColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Activity line chart ───────────────────────────────────────────────────────

class _ActivityLineChart extends StatelessWidget {
  final List<ActivityData> entries;
  const _ActivityLineChart({required this.entries});

  static const _sevHigh   = Color(0xFFD32F2F);
  static const _sevMed    = Color(0xFFF57C00);
  static const _sevLow    = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    // Build spots from entries
    final spots = entries.map((e) {
      final x = e.timestamp.hour + e.timestamp.minute / 60.0;
      final y = e.activityLevel.toDouble();
      return FlSpot(x, y);
    }).toList();

    // Impact entries for overlay dots
    final impacts = entries.where((e) => e.impactDetected).toList();

    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Activity level',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _PgColors.text,
                ),
              ),
              const Spacer(),
              // Legend
              _dot(_sevHigh, 'High impact'),
              const SizedBox(width: 8),
              _dot(_sevMed, 'Med'),
              const SizedBox(width: 8),
              _dot(_sevLow, 'Low'),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0, maxX: 24,
                minY: -0.3, maxY: 3.5,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: _PgColors.border,
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        const labels = ['Rest', 'Light', 'Mod', 'Active'];
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox();
                        return Text(
                          labels[i],
                          style: const TextStyle(
                            fontSize: 9,
                            color: _PgColors.subtext,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 4,
                      getTitlesWidget: (v, _) {
                        final h = v.toInt();
                        String label;
                        if (h == 0) label = '12a';
                        else if (h == 12) label = '12p';
                        else if (h < 12) label = '${h}a';
                        else label = '${h - 12}p';
                        return Text(
                          label,
                          style: const TextStyle(
                            fontSize: 9,
                            color: _PgColors.subtext,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    isStepLineChart: true,
                    color: _PgColors.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _PgColors.primary.withOpacity(0.08),
                    ),
                  ),
                  // Impact dots — transparent line, visible dots only
                  LineChartBarData(
                    spots: impacts.map((e) {
                      final x = e.timestamp.hour + e.timestamp.minute / 60.0;
                      final y = e.activityLevel.toDouble();
                      return FlSpot(x, y);
                    }).toList(),
                    isCurved: false,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) {
                        final entry = impacts[idx];
                        final color = entry.impactSeverity >= 7.0
                            ? _sevHigh
                            : entry.impactSeverity >= 4.0
                                ? _sevMed
                                : _sevLow;
                        return FlDotCirclePainter(
                          radius: 5,
                          color: color,
                          strokeColor: Colors.white,
                          strokeWidth: 1.5,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 9, color: _PgColors.subtext)),
    ],
  );
}

// ── Gantt status band ─────────────────────────────────────────────────────────

class _GanttBand extends StatelessWidget {
  final List<ActivityData> entries;
  const _GanttBand({required this.entries});

  static const _colors = [
    Color(0xFFB3D9F5), // resting — soft blue
    Color(0xFF1baf7a), // light   — green
    Color(0xFFeda100), // moderate — amber
    Color(0xFFe34948), // active  — red
  ];

  static const _labels = ['Resting', 'Light', 'Moderate', 'Active'];

  Color _impactColor(double sev) => sev >= 7.0
      ? const Color(0xFFD32F2F)
      : sev >= 4.0
          ? const Color(0xFFF57C00)
          : const Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final impacts = entries.where((e) => e.impactDetected).toList();

    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status band · full day',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _PgColors.subtext),
          ),
          const SizedBox(height: 8),

          // Gantt bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 18,
              child: LayoutBuilder(builder: (ctx, constraints) {
                return Row(
                  children: entries.map((e) {
                    final level = e.activityLevel;
                    // Each entry gets equal width slice
                    return Expanded(
                      child: Container(
                        color: _colors[level.clamp(0, 3)],
                      ),
                    );
                  }).toList(),
                );
              }),
            ),
          ),

          // Time labels
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('12am', style: TextStyle(fontSize: 9, color: _PgColors.subtext)),
                Text('6am',  style: TextStyle(fontSize: 9, color: _PgColors.subtext)),
                Text('12pm', style: TextStyle(fontSize: 9, color: _PgColors.subtext)),
                Text('6pm',  style: TextStyle(fontSize: 9, color: _PgColors.subtext)),
                Text('11pm', style: TextStyle(fontSize: 9, color: _PgColors.subtext)),
              ],
            ),
          ),

          // Impact tick marks
          if (impacts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Impacts  ',
                    style: TextStyle(fontSize: 9, color: _PgColors.subtext)),
                Expanded(
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(height: 12),
                        ...impacts.map((e) {
                          final pct =
                              (e.timestamp.hour * 60 + e.timestamp.minute) /
                                  (23 * 60 + 59);
                          return Positioned(
                            left: pct * constraints.maxWidth - 1,
                            top: 0,
                            child: Container(
                              width: 2.5,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _impactColor(e.impactSeverity),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ],

          // Legend
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: List.generate(4, (i) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: _colors[i],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 3),
                Text(_labels[i],
                    style: const TextStyle(
                        fontSize: 9, color: _PgColors.subtext)),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

// ── Day summary stats ─────────────────────────────────────────────────────────

class _DaySummaryStats extends StatelessWidget {
  final List<ActivityData> entries;
  const _DaySummaryStats({required this.entries});

  @override
  Widget build(BuildContext context) {
    final impacts = entries.where((e) => e.impactDetected).toList();
    final highImpacts = impacts.where((e) => e.impactSeverity >= 7.0).length;
    final medImpacts  = impacts.where((e) => e.impactSeverity >= 4.0 && e.impactSeverity < 7.0).length;

    // Dominant activity level
    final levelCounts = [0, 0, 0, 0];
    for (final e in entries) {
      levelCounts[e.activityLevel.clamp(0, 3)]++;
    }
    final dominantIdx = levelCounts.indexOf(levelCounts.reduce((a, b) => a > b ? a : b));
    const levelNames = ['Resting', 'Light', 'Moderate', 'Active'];

    final activeCount = entries.where((e) => e.activityLevel >= 2).length;
    final activeHours = (activeCount * 0.25).toStringAsFixed(1); // assuming 15-min intervals

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _PgColors.text,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _StatChip(
              icon: Icons.timer_outlined,
              value: '${activeHours}h',
              label: 'Active Time',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              icon: Icons.warning_amber_rounded,
              value: '$highImpacts high\n$medImpacts med',
              label: 'Impacts',
              accent: highImpacts > 0 ? _PgColors.danger : _PgColors.primary,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _StatChip(
              icon: Icons.track_changes_outlined,
              value: levelNames[dominantIdx],
              label: 'Dominant Status',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              icon: Icons.trending_up_rounded,
              value: entries.isEmpty ? '--:--' : () {
                final peak = entries.reduce(
                  (a, b) => a.activityLevel >= b.activityLevel ? a : b,
                );
                final h = peak.timestamp.hour.toString().padLeft(2, '0');
                final m = peak.timestamp.minute.toString().padLeft(2, '0');
                return '$h:$m';
              }(),
              label: 'Peak Activity',
            ),
          ),
        ]),
      ],
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = _PgColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(height: 10),
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: accent, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: _PgColors.subtext)),
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