import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/health_provider.dart';
import '../models/health_vitals.dart';
import '../models/respiratory_alert_settings.dart';
import '../models/temperature_alert_settings.dart';
import 'package:fl_chart/fl_chart.dart';

Future<void> _launchLearnMoreUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $url')),
    );
  }
}

enum VitalTrend { up, down, steady }

/// How long a reading can go without an update before we treat the sensor
/// as offline/disconnected rather than just showing the last known value.
const _staleAfter = Duration(minutes: 2);

/// Formats a duration as a short relative-time string ("just now", "12s ago",
/// "3m ago", "2h ago", "1d ago") for "last updated" labels.
String _formatElapsed(Duration d) {
  if (d.inSeconds < 5) return 'just now';
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

/// Compares [current] to [previous] and returns the direction of change.
/// Returns null when there's no previous reading to compare against.
/// [epsilon] absorbs sensor noise so tiny fluctuations don't flicker.
VitalTrend? _trendFor(double? current, double? previous, {double epsilon = 0}) {
  if (current == null || previous == null) return null;
  final diff = current - previous;
  if (diff > epsilon) return VitalTrend.up;
  if (diff < -epsilon) return VitalTrend.down;
  return VitalTrend.steady;
}

class HealthDashboardScreen extends ConsumerWidget {
  const HealthDashboardScreen({super.key});

  static const Color _primaryColor = Color.fromARGB(255, 0, 150, 136);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(vitalsWithTrendProvider);

    // Reset the dismissed banner as soon as the collar looks fine again, so
    // it reappears fresh if misalignment happens again later rather than
    // staying hidden forever after a single dismissal.
    ref.listen(collarMisalignedProvider, (previous, next) {
      if (next.valueOrNull != true) {
        ref.read(collarBannerDismissedProvider.notifier).state = false;
      }
    });
    final collarMisaligned = ref.watch(collarMisalignedProvider).valueOrNull ?? false;
    final collarBannerDismissed = ref.watch(collarBannerDismissedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Monitoring'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(healthVitalsStreamProvider);
          ref.invalidate(vitalsWithTrendProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              if (collarMisaligned && !collarBannerDismissed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildCollarAlignmentBanner(ref),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Live Health Vitals',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: healthAsync.when(
                  data: (vitalsWithTrend) => _buildVitalsCards(context, vitalsWithTrend, ref),
                  loading: () => _buildLoadingCard(),
                  error: (error, _) => _buildErrorCard(error),
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Daily Vital Trends',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTrendsSection(ref),
              ),

              const SizedBox(height: 24),

              // ── Disclaimer ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'These readings are for general awareness only and do '
                          'not replace professional veterinary assessment. Consult '
                          'a vet if you have concerns about your pet\'s health.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── Collar alignment banner ─────────────────

  Widget _buildCollarAlignmentBanner(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Check your dog's collar",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reading looks off — the sensor may not be in contact with '
                  'your dog\'s skin. Check the collar fit.',
                  style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => ref.read(collarBannerDismissedProvider.notifier).state = true,
            child: Icon(Icons.close_rounded, size: 18, color: Colors.amber.shade800),
          ),
        ],
      ),
    );
  }

  // ───────────────── VITALS ─────────────────

Widget _buildVitalsCards(BuildContext context, VitalsWithTrend vitalsWithTrend, WidgetRef ref) {
  final thresholds = ref.watch(vitalThresholdsProvider);
  final vitals = vitalsWithTrend.current;
  final previous = vitalsWithTrend.previous;
  final respAlertSettings =
      ref.watch(respiratoryAlertSettingsProvider).valueOrNull ??
          RespiratoryAlertSettings.disabled;
  final tempAlertSettings =
      ref.watch(temperatureAlertSettingsProvider).valueOrNull ??
          TemperatureAlertSettings.disabled;

  final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
  final elapsed = now.difference(vitals.timestamp);
  final isStale = elapsed > _staleAfter;

  final respTrend = (vitals.respiratoryRate > 0 && (previous?.respiratoryRate ?? 0) > 0)
      ? _trendFor(
          vitals.respiratoryRate.toDouble(),
          previous!.respiratoryRate.toDouble(),
        )
      : null;

  final tempTrend = (vitals.temperature > 0 && (previous?.temperature ?? 0) > 0)
      ? _trendFor(
          vitals.calibratedTemperature,
          previous!.calibratedTemperature,
          epsilon: 0.05, // ignores noise below the displayed 0.1°C precision
        )
      : null;

  return Column(
    children: [
      // ── "Last updated" / staleness indicator ──
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isStale ? Icons.cloud_off_rounded : Icons.circle,
            size: isStale ? 14 : 8,
            color: isStale ? Colors.red.shade400 : Colors.green.shade400,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isStale
                  ? 'No new reading in ${_formatElapsed(elapsed)} — check sensor connection'
                  : 'Updated ${_formatElapsed(elapsed)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isStale ? FontWeight.w600 : FontWeight.normal,
                color: isStale ? Colors.red.shade600 : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),

      // ── Row 1: Respiratory Rate + Temperature ──
      Row(
        children: [
          Expanded(
            child: _buildVitalCard(
              context: context,
              title: 'Respiratory Rate',
              description:
                  'Respiratory rate is how many breaths your dog takes per minute at rest. '
                  'It is a key indicator of cardiovascular and lung health. '
                  'An elevated resting rate can signal pain, fever, heart disease, or respiratory distress.',
              learnMoreUrl: 'https://www.msdvetmanual.com/reference-values-and-conversion-tables/reference-guides/resting-respiratory-rates',
              value: vitals.respiratoryRate > 0 ? vitals.respiratoryRate.toString() : '--',
              unit: 'br/min',
              icon: Icons.air,
              iconColor: Colors.teal,
              status: vitals.respiratoryRate > 0
                  ? thresholds.respiratoryStatus(vitals.respiratoryRate)
                  : null,
              normalRange: '${thresholds.respNormalMin}–${thresholds.respNormalMax}',
              trend: respTrend,
              muted: isStale,
              alertSettingsEnabled: respAlertSettings.enabled,
              onAlertSettingsTap: () => showDialog(
                context: context,
                builder: (_) => _RespiratoryAlertSettingsDialog(initial: respAlertSettings),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildVitalCard(
              context: context,
              title: 'Body Temperature',
              value: vitals.temperature > 0
                  ? vitals.calibratedTemperature.toStringAsFixed(1)
                  : '--',
              unit: '°C',
              icon: Icons.thermostat,
              iconColor: Colors.orange,
              status: vitals.temperature > 0
                  ? thresholds.temperatureStatus(vitals.calibratedTemperature)
                  : null,
              normalRange: '${thresholds.tempNormalMin}–${thresholds.tempNormalMax}°C',
              trend: tempTrend,
              muted: isStale,
              alertSettingsEnabled: tempAlertSettings.enabled,
              onAlertSettingsTap: () => showDialog(
                context: context,
                builder: (_) => _TemperatureAlertSettingsDialog(initial: tempAlertSettings),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

 Widget _buildVitalCard({
  required BuildContext context,
  required String title,
  required String value,
  required String unit,
  required IconData icon,
  required Color iconColor,
  VitalStatus? status,
  String? normalRange,
  String? description,
  String? learnMoreUrl,
  VitalTrend? trend,
  bool muted = false,
  bool fullWidth = false,
  VoidCallback? onAlertSettingsTap,
  bool alertSettingsEnabled = false,
}) {
  final statusColor = switch (status) {
    VitalStatus.normal  => Colors.green,
    VitalStatus.caution => Colors.orange,
    VitalStatus.danger  => Colors.red,
    null                => _primaryColor,
  };

  final statusLabel = switch (status) {
    VitalStatus.normal  => 'Normal',
    VitalStatus.caution => 'Caution',
    VitalStatus.danger  => 'Danger',
    null                => null,
  };

  final card = Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (description != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                            if (learnMoreUrl != null) ...[
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () => _launchLearnMoreUrl(context, learnMoreUrl),
                                child: Text(
                                  'Learn more',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _primaryColor,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 15,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
              if (onAlertSettingsTap != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onAlertSettingsTap,
                  child: Tooltip(
                    message: alertSettingsEnabled
                        ? 'Custom alerts on — tap to edit'
                        : 'Set custom alert limits',
                    child: Icon(
                      alertSettingsEnabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      size: 16,
                      color: alertSettingsEnabled
                          ? _primaryColor
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                if (trend != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: switch (trend) {
                      VitalTrend.up => 'Up from previous reading',
                      VitalTrend.down => 'Down from previous reading',
                      VitalTrend.steady => 'Same as previous reading',
                    },
                    child: Icon(
                      switch (trend) {
                        VitalTrend.up => Icons.arrow_upward_rounded,
                        VitalTrend.down => Icons.arrow_downward_rounded,
                        VitalTrend.steady => Icons.trending_flat_rounded,
                      },
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (statusLabel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (normalRange != null) ...[
            const SizedBox(height: 6),
            Text(
              'Normal: $normalRange',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    ),
  );
  return Opacity(opacity: muted ? 0.55 : 1, child: fullWidth ? card : card);
}

  // ───────────────── SUPPORTING UI ─────────────────

  Widget _buildLoadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _primaryColor),
              const SizedBox(height: 16),
              Text(
                'Connecting to sensor…',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
            error.toString(),         // ← show the actual error
            style: const TextStyle(fontSize: 11, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          ],
        ),
      ),
    );
  }

Widget _buildTrendsSection(WidgetRef ref) {
  final selectedDay = ref.watch(selectedDayProvider);
  final historyAsync = ref.watch(healthHistoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final earliestAllowedDay = today.subtract(const Duration(days: 90));
  final canGoNext = !_isSameDay(selectedDay, today) && selectedDay.isBefore(today);
  final canGoPrev = !_isSameDay(selectedDay, earliestAllowedDay) &&
      selectedDay.isAfter(earliestAllowedDay);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          IconButton(
            onPressed: canGoPrev
                ? () => ref.read(selectedDayProvider.notifier).state =
                    DateTime(selectedDay.year, selectedDay.month, selectedDay.day)
                        .subtract(const Duration(days: 1))
                : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous day',
            color: _primaryColor,
            disabledColor: Colors.grey.shade300,
          ),
          Expanded(
            child: Center(
              child: Text(
                _formatSelectedDay(selectedDay),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext
                ? () => ref.read(selectedDayProvider.notifier).state =
                    DateTime(selectedDay.year, selectedDay.month, selectedDay.day)
                        .add(const Duration(days: 1))
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next day',
            color: _primaryColor,
            disabledColor: Colors.grey.shade300,
          ),
          IconButton(
            onPressed: () => _pickDay(ref),
            icon: const Icon(Icons.calendar_today, size: 18),
            tooltip: 'Pick a day',
            color: _primaryColor,
          ),
        ],
      ),
      const SizedBox(height: 8),

      SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            // Oldest to newest, ending in today.
            final day = today.subtract(Duration(days: 6 - index));
            return _buildDayChip(ref, day: day, selectedDay: selectedDay);
          },
        ),
      ),
      const SizedBox(height: 12),

      historyAsync.when(
        data: (history) => history.isEmpty
            ? _buildNoDataCard()
            : _buildCharts(history),
        loading: () => const Card(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(color: _primaryColor)),
          ),
        ),
        error: (e, _) => _buildErrorCard(e),
      ),
    ],
  );
}

Widget _buildDayChip(WidgetRef ref, {required DateTime day, required DateTime selectedDay}) {
  final isSelected = _isSameDay(day, selectedDay);
  final hasAlertAsync = ref.watch(dayHasAlertProvider(day));
  final hasAlert = hasAlertAsync.valueOrNull ?? false;

  const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  return GestureDetector(
    onTap: () => ref.read(selectedDayProvider.notifier).state = day,
    child: Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? _primaryColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayLabels[day.weekday - 1],
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                day.day.toString(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          if (hasAlert)
            Positioned(
              top: -2,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _primaryColor : Colors.grey.shade100,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Future<void> _pickDay(WidgetRef ref) async {
  final current = ref.read(selectedDayProvider);
  final picked = await showDatePicker(
    context: ref.context,
    initialDate: current,
    firstDate: DateTime.now().subtract(const Duration(days: 90)),
    lastDate: DateTime.now(),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(primary: _primaryColor),
      ),
      child: child!,
    ),
  );
  if (picked != null) {
    ref.read(selectedDayProvider.notifier).state = picked;
  }
}

String _formatSelectedDay(DateTime day) {
  final now = DateTime.now();
  if (_isSameDay(day, now)) return 'Today';
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(day, yesterday)) return 'Yesterday';
  return '${day.day}/${day.month}/${day.year}';
}

/// Computes a [minY, maxY] range that always fits the actual data, padded a
/// bit so the line doesn't touch the top/bottom edge. Falls back to
/// [fallbackMin]/[fallbackMax] when there are no values to measure.
List<double> _autoRange(
  Iterable<double> values, {
  required double fallbackMin,
  required double fallbackMax,
  double paddingFraction = 0.1,
  double minSpan = 1,
}) {
  if (values.isEmpty) return [fallbackMin, fallbackMax];

  final minVal = values.reduce((a, b) => a < b ? a : b);
  final maxVal = values.reduce((a, b) => a > b ? a : b);
  final span = (maxVal - minVal).abs();
  final effectiveSpan = span < minSpan ? minSpan : span;
  final padding = effectiveSpan * paddingFraction;

  return [minVal - padding, maxVal + padding];
}

Widget _buildCharts(List<HealthVitals> history) {
  final validRespHistory = history.where((v) => v.respiratoryRate > 0).toList();
  final validTempHistory = history.where((v) => v.temperature > 30).toList(); // offset applied via calibratedTemperature below

  final respRange = _autoRange(
    validRespHistory.map((v) => v.respiratoryRate.toDouble()),
    fallbackMin: 5,
    fallbackMax: 60,
    minSpan: 10,
  );
  final tempRange = _autoRange(
    validTempHistory.map((v) => v.calibratedTemperature),
    fallbackMin: 36,
    fallbackMax: 42,
    minSpan: 1,
  );

  return Column(
    children: [
      // Respiratory Rate
      _buildLineChart(
        label: 'Respiratory Rate (br/min)',
        spots: validRespHistory.asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), e.value.respiratoryRate.toDouble())).toList(),
        color: Colors.teal,
        minY: respRange[0],
        maxY: respRange[1],
        history: validRespHistory,
      ),
      const SizedBox(height: 16),

      // Temperature
      _buildLineChart(
        label: 'Temperature (°C)',
        spots: validTempHistory.asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), e.value.calibratedTemperature)).toList(),
        color: Colors.orange,
        minY: tempRange[0],
        maxY: tempRange[1],
        history: validTempHistory,
      ),
    ],
  );
}

Widget _buildLineChart({
  required String label,
  required List<FlSpot> spots,
  required Color color,
  required double minY,
  required double maxY,
  required List<HealthVitals> history,
}) {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 2,
    clipBehavior: Clip.hardEdge,          // ← prevents chart bleeding outside card
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          LayoutBuilder(                  // ← adapts to available width
            builder: (context, constraints) {
              return SizedBox(
                height: 180,
                width: constraints.maxWidth,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    clipData: const FlClipData.all(),  // ← clips line inside chart bounds
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (val, _) => Text(
                            val.toStringAsFixed(0),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: (spots.length / 4).ceilToDouble().clamp(1, 999),
                          getTitlesWidget: (val, _) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= history.length) return const SizedBox();
                            final t = history[idx].timestamp;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: spots.length <= 24,
                          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                            radius: 3,
                            color: color,
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((s) {
                          final idx = s.spotIndex;
                          final t = history[idx].timestamp;
                          return LineTooltipItem(
                            "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}\n${s.y.toStringAsFixed(1)}",
                            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}


Widget _buildNoDataCard() {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No data for this day',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    ),
  );
}

}
// ───────────────── Respiratory rate custom alert settings ─────────────────

class _RespiratoryAlertSettingsDialog extends ConsumerStatefulWidget {
  final RespiratoryAlertSettings initial;

  const _RespiratoryAlertSettingsDialog({required this.initial});

  @override
  ConsumerState<_RespiratoryAlertSettingsDialog> createState() =>
      _RespiratoryAlertSettingsDialogState();
}

class _RespiratoryAlertSettingsDialogState
    extends ConsumerState<_RespiratoryAlertSettingsDialog> {
  static const Color _primaryColor = Color.fromARGB(255, 0, 150, 136);

  late bool _enabled;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late int _sustainedMinutes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.enabled;
    _minController =
        TextEditingController(text: widget.initial.minRate?.toString() ?? '');
    _maxController =
        TextEditingController(text: widget.initial.maxRate?.toString() ?? '');
    _sustainedMinutes = widget.initial.sustainedMinutes;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Respiratory Rate Alerts',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enable custom alerts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              value: _enabled,
              activeColor: _primaryColor,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    enabled: _enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min (br/min)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    enabled: _enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max (br/min)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Leave a field blank to skip that limit.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            Text(
              'Notify if sustained for $_sustainedMinutes min',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _enabled ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
            Slider(
              value: _sustainedMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: _primaryColor,
              label: '$_sustainedMinutes min',
              onChanged: _enabled
                  ? (v) => setState(() => _sustainedMinutes = v.round())
                  : null,
            ),
            Text(
              'A notification is sent only once the rate stays outside your '
              'limit continuously for this long — a brief spike won\'t trigger it.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          style: TextButton.styleFrom(foregroundColor: _primaryColor),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final min = int.tryParse(_minController.text.trim());
    final max = int.tryParse(_maxController.text.trim());

    if (_enabled && min == null && max == null) {
      setState(() => _error = 'Set at least a min or max limit, or turn alerts off.');
      return;
    }
    if (min != null && max != null && min >= max) {
      setState(() => _error = 'Min must be less than max.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final settings = RespiratoryAlertSettings(
      enabled: _enabled,
      minRate: min,
      maxRate: max,
      sustainedMinutes: _sustainedMinutes,
    );

    try {
      await ref.read(healthServiceProvider).saveRespiratoryAlertSettings(settings);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }
}

// ───────────────── Temperature custom alert settings ─────────────────

class _TemperatureAlertSettingsDialog extends ConsumerStatefulWidget {
  final TemperatureAlertSettings initial;

  const _TemperatureAlertSettingsDialog({required this.initial});

  @override
  ConsumerState<_TemperatureAlertSettingsDialog> createState() =>
      _TemperatureAlertSettingsDialogState();
}

class _TemperatureAlertSettingsDialogState
    extends ConsumerState<_TemperatureAlertSettingsDialog> {
  static const Color _primaryColor = Color.fromARGB(255, 0, 150, 136);

  late bool _enabled;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late int _sustainedMinutes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.enabled;
    _minController = TextEditingController(
        text: widget.initial.minTemp?.toStringAsFixed(1) ?? '');
    _maxController = TextEditingController(
        text: widget.initial.maxTemp?.toStringAsFixed(1) ?? '');
    _sustainedMinutes = widget.initial.sustainedMinutes;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Temperature Alerts',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enable custom alerts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              value: _enabled,
              activeColor: _primaryColor,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    enabled: _enabled,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Min (°C)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    enabled: _enabled,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Max (°C)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Leave a field blank to skip that limit.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            Text(
              'Notify if sustained for $_sustainedMinutes min',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _enabled ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
            Slider(
              value: _sustainedMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: _primaryColor,
              label: '$_sustainedMinutes min',
              onChanged: _enabled
                  ? (v) => setState(() => _sustainedMinutes = v.round())
                  : null,
            ),
            Text(
              'A notification is sent only once the temperature stays outside '
              'your limit continuously for this long — a brief spike won\'t trigger it.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          style: TextButton.styleFrom(foregroundColor: _primaryColor),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final min = double.tryParse(_minController.text.trim());
    final max = double.tryParse(_maxController.text.trim());

    if (_enabled && min == null && max == null) {
      setState(() => _error = 'Set at least a min or max limit, or turn alerts off.');
      return;
    }
    if (min != null && max != null && min >= max) {
      setState(() => _error = 'Min must be less than max.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final settings = TemperatureAlertSettings(
      enabled: _enabled,
      minTemp: min,
      maxTemp: max,
      sustainedMinutes: _sustainedMinutes,
    );

    try {
      await ref.read(healthServiceProvider).saveTemperatureAlertSettings(settings);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }
}