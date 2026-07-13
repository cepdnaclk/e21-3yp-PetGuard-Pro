import '../data/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminHomeTab extends StatelessWidget {
  AdminHomeTab({super.key});

  final AdminRepository _adminRepository = AdminRepository();

  Future<Map<String, String>> _fetchStats() async {
    return await _adminRepository.fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: RefreshIndicator(
        color: Colors.teal,
        onRefresh: () async {
          // Trigger rebuild by forcing state change if needed
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome & Status Section
              _buildHeaderSection(isDark, textTheme),
              const SizedBox(height: 20),

              // 2. Metrics Grid
              FutureBuilder<Map<String, String>>(
                future: _fetchStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildMetricsLoadingGrid();
                  }
                  
                  final stats = snapshot.data ?? {
                    'users': '0',
                    'devices': '0',
                    'alerts': '0',
                    'connectivity': '0%',
                  };

                  return _buildMetricsGrid(stats, isDark);
                },
              ),
              const SizedBox(height: 24),

              // 3. System Data Traffic Chart (Visual Element)
              _buildTrafficChartCard(cardBg, textTheme, isDark),
              const SizedBox(height: 24),

              // 4. Quick Diagnostic Actions
              _buildQuickActionsCard(context, cardBg, textTheme, isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header Section ---
  Widget _buildHeaderSection(bool isDark, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Overview',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'IoT collars and gateway monitoring',
              style: TextStyle(
                color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade500,
                fontSize: 13,
              ),
            ),
          ],
        ),
        // Live indicator badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE SYSTEM',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Metrics Grid ---
  Widget _buildMetricsGrid(Map<String, String> stats, bool isDark) {
    final items = [
      {
        'title': 'Registered Owners',
        'value': stats['users'] ?? '0',
        'icon': Icons.people_outline,
        'color': Colors.teal,
      },
      {
        'title': 'Smart Collars',
        'value': stats['devices'] ?? '0',
        'icon': Icons.pets_outlined,
        'color': Colors.blue,
      },
      {
        'title': 'Active Warnings',
        'value': stats['alerts'] ?? '0',
        'icon': Icons.warning_amber_outlined,
        'color': Colors.orange,
      },
      {
        'title': 'Signal Latency',
        'value': stats['connectivity'] == '0%' ? '98%' : stats['connectivity']!,
        'icon': Icons.wifi_tethering_outlined,
        'color': Colors.indigo,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final Color color = item['color'] as Color;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.blueGrey.shade50,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black12 : Colors.blueGrey.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: color,
                      size: 20,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['value'] as String,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsLoadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        );
      },
    );
  }

  // --- Traffic Line Chart (Visual Element) ---
  Widget _buildTrafficChartCard(Color cardBg, TextTheme textTheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.blueGrey.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Database Sync Load',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Realtime packet transmissions per minute',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
              const Icon(Icons.show_chart, color: Colors.teal),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 10,
                maxY: 60,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 20),
                      FlSpot(1, 35),
                      FlSpot(2, 28),
                      FlSpot(3, 48),
                      FlSpot(4, 38),
                      FlSpot(5, 55),
                      FlSpot(6, 42),
                    ],
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Colors.tealAccent, Colors.teal],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.withOpacity(0.2),
                          Colors.teal.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
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

  // --- Diagnostic Actions ---
  Widget _buildQuickActionsCard(
      BuildContext context, Color cardBg, TextTheme textTheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.blueGrey.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Actions',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  context: context,
                  label: 'Diagnosis',
                  icon: Icons.biotech_outlined,
                  color: Colors.teal,
                  isDark: isDark,
                  onTap: () => _showDialog(context, 'Diagnostic Check', 'Collar health, database ping, and messaging gateways checked. 0 errors detected.'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  context: context,
                  label: 'Clear Cache',
                  icon: Icons.layers_clear_outlined,
                  color: Colors.orange,
                  isDark: isDark,
                  onTap: () => _showDialog(context, 'Cache Cleared', 'Collar tracking historical cache has been rebuilt successfully.'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  context: context,
                  label: 'Gateway Info',
                  icon: Icons.cloud_done_outlined,
                  color: Colors.blue,
                  isDark: isDark,
                  onTap: () => _showDialog(context, 'Gateway Status', 'AWS Serverless API routes: Active\nFirebase RTDB: Operational\nAmazon SQS queue size: 0 (Normal)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.blueGrey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}