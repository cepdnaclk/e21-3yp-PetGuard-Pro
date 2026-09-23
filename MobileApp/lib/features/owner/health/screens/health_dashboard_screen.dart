import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/health_provider.dart';
import '../models/health_vitals.dart';
import 'package:fl_chart/fl_chart.dart';

class HealthDashboardScreen extends ConsumerWidget {
  const HealthDashboardScreen({super.key});

  static const Color _primaryColor = Color.fromARGB(255, 0, 150, 136);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthVitalsStreamProvider);

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
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),

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
                  data: (vitals) => _buildVitalsCards(context, vitals, ref),
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

  // ───────────────── HEADER (matches Location) ─────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _primaryColor.withValues(alpha: 0.7)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pet Health',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Live vitals monitoring',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── VITALS ─────────────────

Widget _buildVitalsCards(BuildContext context, HealthVitals vitals, WidgetRef ref) {
  final thresholds = ref.watch(vitalThresholdsProvider);
  return Column(
    children: [
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
              value: vitals.respiratoryRate > 0 ? vitals.respiratoryRate.toString() : '--',
              unit: 'br/min',
              icon: Icons.air,
              iconColor: Colors.teal,
              status: vitals.respiratoryRate > 0
                  ? thresholds.respiratoryStatus(vitals.respiratoryRate)
                  : null,
              normalRange: '${thresholds.respNormalMin}–${thresholds.respNormalMax}',
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
  bool fullWidth = false,
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
                        content: Text(
                          description,
                          style: const TextStyle(fontSize: 14, height: 1.5),
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
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
  return fullWidth ? card : card;
}

  // ───────────────── SUPPORTING UI ─────────────────

  Widget _buildLoadingCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(color: _primaryColor),
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

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatSelectedDay(selectedDay),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          TextButton.icon(
            onPressed: () => _pickDay(ref),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text('Change day'),
            style: TextButton.styleFrom(foregroundColor: _primaryColor),
          ),
        ],
      ),
      const SizedBox(height: 8),

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
  if (day.year == now.year && day.month == now.month && day.day == now.day) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (day.year == yesterday.year && day.month == yesterday.month && day.day == yesterday.day) {
    return 'Yesterday';
  }
  return '${day.day}/${day.month}/${day.year}';
}

Widget _buildCharts(List<HealthVitals> history) {
  final validRespHistory = history.where((v) => v.respiratoryRate > 0).toList();
  final validTempHistory = history.where((v) => v.temperature > 30).toList(); // offset applied via calibratedTemperature below

  return Column(
    children: [
      // Respiratory Rate
      _buildLineChart(
        label: 'Respiratory Rate (br/min)',
        spots: validRespHistory.asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), e.value.respiratoryRate.toDouble())).toList(),
        color: Colors.teal,
        minY: 5,
        maxY: 60,
        history: validRespHistory,
      ),
      const SizedBox(height: 16),

      // Temperature
      _buildLineChart(
        label: 'Temperature (°C)',
        spots: validTempHistory.asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), e.value.calibratedTemperature)).toList(),
        color: Colors.orange,
        minY: 36,
        maxY: 42,
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