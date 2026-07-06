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

  // Primary color now comes from the active ThemeData at runtime.

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
      backgroundColor: _PgColors.page(context),
      appBar: AppBar(
        title: const Text('Activity Monitor'),
        backgroundColor: _PgColors.primary(context),
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
  static Color primary(BuildContext c) => Theme.of(c).colorScheme.primary;
  static Color page(BuildContext c) => Theme.of(c).scaffoldBackgroundColor;
  static Color card(BuildContext c) => Theme.of(c).cardColor;
  static Color soft(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color(0xFF213233)
      : const Color(0xFFEAF7F5);
  static Color text(BuildContext c) => Theme.of(c).textTheme.bodyMedium?.color ?? Colors.black;
  static Color subtext(BuildContext c) => Theme.of(c).textTheme.bodySmall?.color ?? Colors.grey;
  static Color border(BuildContext c) => Theme.of(c).dividerColor;
  static Color warning(BuildContext c) => const Color(0xFFF57C00);
  static Color danger(BuildContext c) => const Color(0xFFD32F2F);
}

class _PgDecor {
  static BorderRadius get xl => BorderRadius.circular(24);
  static BorderRadius get lg => BorderRadius.circular(20);

  static BoxDecoration card(BuildContext ctx, {
    Color? color,
    Color? border,
  }) {
    final brightness = Theme.of(ctx).brightness;
    color ??= _PgColors.card(ctx);
    border ??= _PgColors.border(ctx);
    return BoxDecoration(
      color: color,
      borderRadius: xl,
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(brightness == Brightness.dark ? 46 : 10),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Activity hero ─────────────────────────────────────────
          _ActivityHeroCard(activity: activity),
          const SizedBox(height: 14),

          // ── 2. Active Minutes (centered, compact) ────────────────────
          _LiveStatCard(
            icon: Icons.timer_outlined,
            label: 'Active Minutes',
            value: '${activity.activeMinutes.toStringAsFixed(0)} min',
          ),
          const SizedBox(height: 14),

          // ── 3. Impact alert ──────────────────────────────────────────
          _ImpactAlertCard(
            detected: activity.impactDetected,
            severity: activity.impactSeverity,
          ),
          const SizedBox(height: 14),

          // ── 4. Context-aware tip ─────────────────────────────────────
          _ActivityTipCard(activityType: activity.activityType),
          const SizedBox(height: 10),

          // ── 5. Disclaimer ────────────────────────────────────────────
          const _DisclaimerBanner(),
        ],
      ),
    );
  }
}

// ── Hero card implementation ───────────────────────────────────────

class _ActivityHeroCard extends StatelessWidget {
  final ActivityData activity;
  const _ActivityHeroCard({required this.activity});

  static const Map<String, List<Color>> _gradients = {
    'resting': [Color(0xFFA8D5B5), Color(0xFF6BAF82)],
    'walking': [Color(0xFF4CAF7D), Color(0xFF2E7D52)],
    'playing': [Color(0xFF00C853), Color(0xFF00953E)],
    'running': [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    'impact':  [Color(0xFFEF5350), Color(0xFFC62828)],
  };

static List<Color> _gradientFor(String type) =>
    _gradients[type.toLowerCase()] ?? _gradients['walking']!;

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
        gradient: LinearGradient(
        colors: _gradientFor(activity.activityType),
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
        borderRadius: _PgDecor.xl,
        boxShadow: [
          BoxShadow(
            color: _gradientFor(activity.activityType)[1].withAlpha(56),
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
                  color: Colors.white.withAlpha(204),
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
                      color: Colors.white.withAlpha(179),
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
                        : Colors.white.withAlpha(64),
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
              color: Colors.white.withAlpha(191),
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
      decoration: _PgDecor.card(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _PgColors.soft(context),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _PgColors.primary(context), size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _PgColors.text(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _PgColors.subtext(context),
                ),
              ),
            ],
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
    final high = detected && severity >= 7.0;
    final accent = !detected
      ? _PgColors.primary(context)
      : high
        ? _PgColors.danger(context)
        : _PgColors.warning(context);


    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bg = isDark
        ? (!detected
            ? const Color(0xFF162522) // Dark muted teal
            : high ? const Color(0xFF331C1C) : const Color(0xFF33241B)) // Dark red / Dark orange
        : (!detected
            ? const Color(0xFFEFF8F4)
            : high ? const Color(0xFFFFEFEE) : const Color(0xFFFFF5EA));

    final borderCol = isDark
        ? (!detected
            ? const Color(0xFF25423B)
            : high ? const Color(0xFF5C2C2C) : const Color(0xFF5C3F2B))
        : (!detected
            ? const Color(0xFFBBDDD5)
            : high ? const Color(0xFFF4C7C1) : const Color(0xFFF6D9B8));

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _PgDecor.lg,
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
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
              color: accent.withAlpha(31),
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
                  style: TextStyle(
                    color: _PgColors.subtext(context),
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

class _ActivityTipCard extends StatelessWidget {
  final String activityType;
  const _ActivityTipCard({required this.activityType});

  static const Map<String, String> _tips = {
    'resting': 'Rest is essential for muscle recovery and healthy sleep cycles in pets.',
    'walking': 'Regular walks improve cardiovascular health and help maintain a healthy weight.',
    'playing': 'Play strengthens the bond between you and your pet and supports mental wellbeing.',
    'running': 'Ensure fresh water is available after intense exercise to keep your pet hydrated.',
    'impact':  'Check your pet for signs of discomfort or limping after a detected impact.',
  };

  @override
  Widget build(BuildContext context) {
    final tip = _tips[activityType.toLowerCase()] ??
        'Monitor your pet\'s activity regularly for early signs of health changes.';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFC8E6C9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DID YOU KNOW?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF388E3C),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF33691E),
                    height: 1.5,
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

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFFF9A825),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Activity data is for general awareness only and does not replace professional veterinary assessment. Consult a vet if you have concerns about your pet\'s health.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFF57F17),
                height: 1.5,
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
          color: _PgColors.primary(context),
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
        Text(
          'Activity History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _PgColors.text(context),
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
                    colorScheme: ColorScheme.light(
                      primary: _PgColors.primary(ctx),
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
              color: _PgColors.soft(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _PgColors.border(context)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined,
                    size: 15, color: _PgColors.primary(context)),
                const SizedBox(width: 5),
                Text(
                  _label(selected),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _PgColors.primary(context),
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
      decoration: _PgDecor.card(context),
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Activity level',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _PgColors.text(context),
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
                    color: _PgColors.border(context),
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
                          style: TextStyle(
                            fontSize: 9,
                            color: _PgColors.subtext(context),
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
                          style: TextStyle(
                            fontSize: 9,
                            color: _PgColors.subtext(context),
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
                        color: _PgColors.primary(context),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                          color: _PgColors.primary(context).withAlpha(20),
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
      Builder(builder: (ctx) => Text(label, style: TextStyle(fontSize: 9, color: _PgColors.subtext(ctx)))),
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
      decoration: _PgDecor.card(context),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status band · full day',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _PgColors.subtext(context)),
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
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('12am', style: TextStyle(fontSize: 9, color: _PgColors.subtext(context))),
                Text('6am',  style: TextStyle(fontSize: 9, color: _PgColors.subtext(context))),
                Text('12pm', style: TextStyle(fontSize: 9, color: _PgColors.subtext(context))),
                Text('6pm',  style: TextStyle(fontSize: 9, color: _PgColors.subtext(context))),
                Text('11pm', style: TextStyle(fontSize: 9, color: _PgColors.subtext(context))),
              ],
            ),
          ),

          // Impact tick marks
          if (impacts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Impacts  ',
                  style: TextStyle(fontSize: 9, color: _PgColors.subtext(context))),
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
                    style: TextStyle(
                        fontSize: 9, color: _PgColors.subtext(context))),
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
        Text(
          'Daily summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _PgColors.text(context),
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
              value: impacts.isEmpty
                  ? 'No impacts\ndetected'
                  : '${impacts.length} impacts\n${highImpacts > 0 ? '$highImpacts critical' : 'none critical'}',
              label: 'Impacts Today',
              accent: highImpacts > 0
                  ? _PgColors.danger(context)
                  : impacts.isNotEmpty
                      ? _PgColors.warning(context)
                      : _PgColors.primary(context),
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
      decoration: _PgDecor.card(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: _PgColors.primary(context)),
        const SizedBox(height: 16),
        Text('Loading activity data...',
            style: TextStyle(fontWeight: FontWeight.w700, color: _PgColors.text(context))),
        const SizedBox(height: 6),
        Text('Fetching the latest collar data.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _PgColors.subtext(context), fontSize: 12)),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? accent;
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final _accent = accent ?? _PgColors.primary(context);
    return Container(
      decoration: _PgDecor.card(context),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: _accent.withAlpha(26),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _accent, size: 22),
        ),
        const SizedBox(height: 10),
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _accent, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _PgColors.subtext(context))),
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
      decoration: _PgDecor.card(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
              color: _PgColors.soft(context), borderRadius: BorderRadius.circular(18)),
          child: Icon(Icons.sensors_off_outlined,
              color: _PgColors.primary(context), size: 30),
        ),
        const SizedBox(height: 16),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _PgColors.subtext(context), fontSize: 14, height: 1.4)),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A1D1D)
              : const Color(0xFFFFF3F2),
          borderRadius: _PgDecor.lg,
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4A2D2D) : const Color(0xFFF2D2CE))),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.error_outline, color: _PgColors.danger(context)),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Error: $error',
                style: TextStyle(color: _PgColors.danger(context)))),
      ]),
    );
  }
}