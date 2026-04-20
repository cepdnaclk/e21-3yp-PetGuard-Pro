// // lib/features/owner/activity/screens/activity_dashboard_screen.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../providers/activity_provider.dart';
// import '../models/activity_data.dart';

// class ActivityDashboardScreen extends ConsumerStatefulWidget {
//   const ActivityDashboardScreen({super.key});

//   @override
//   ConsumerState<ActivityDashboardScreen> createState() =>
//       _ActivityDashboardScreenState();
// }

// class _ActivityDashboardScreenState
//     extends ConsumerState<ActivityDashboardScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   static const Color _primary = Color.fromARGB(255, 0, 150, 136);

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Activity Monitor'),
//         backgroundColor: _primary,
//         foregroundColor: Colors.white,
//         elevation: 0,
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.white,
//           labelColor: Colors.white,
//           unselectedLabelColor: Colors.white70,
//           tabs: const [
//             Tab(icon: Icon(Icons.monitor), text: 'Live'),
//             Tab(icon: Icon(Icons.bar_chart), text: 'Summary'),
//             Tab(icon: Icon(Icons.history), text: 'History'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: const [
//           _LiveTab(),
//           _SummaryTab(),
//           _HistoryTab(),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // TAB 1: LIVE
// // ─────────────────────────────────────────────────────────────────────────────

// class _LiveTab extends ConsumerWidget {
//   const _LiveTab();

//   static const Color _primary = Color.fromARGB(255, 0, 150, 136);

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final activityAsync = ref.watch(currentActivityProvider);

//     return RefreshIndicator(
//       onRefresh: () async => ref.invalidate(currentActivityProvider),
//       child: SingleChildScrollView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         padding: const EdgeInsets.all(16),
//         child: activityAsync.when(
//           data: (activity) {
//             if (activity == null) {
//               return const _NoDataCard(
//                 message: 'No live activity data yet.\nData will appear once the sensor is connected.',
//               );
//             }
//             return Column(
//               children: [
//                 _ActivityStatusCard(activity: activity),
//                 const SizedBox(height: 16),
//                 if (activity.impactDetected)
//                   _ImpactAlertBanner(severity: activity.impactSeverity),
//                 if (activity.impactDetected) const SizedBox(height: 16),
//                 _PetWellnessCard(activity: activity),
//                 const SizedBox(height: 16),
//                 _StepsCard(activity: activity),
//               ],
//             );
//           },
//           loading: () => Center(
//             child: Padding(
//               padding: const EdgeInsets.only(top: 80),
//               child: Column(
//                 children: [
//                   const CircularProgressIndicator(color: _primary),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'Connecting to sensor...',
//                     style: TextStyle(color: Colors.grey, fontSize: 13),
//                   ),
//                   const SizedBox(height: 16),
//                   TextButton(
//                     onPressed: () => ref.invalidate(currentActivityProvider),
//                     child: const Text('Tap to retry',
//                         style: TextStyle(color: _primary)),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           error: (e, _) => _ErrorCard(error: e),
//         ),
//       ),
//     );
//   }
// } // ← _LiveTab closes here

// // ─────────────────────────────────────────────────────────────────────────────
// // FRIENDLY PET WELLNESS CARD
// // ─────────────────────────────────────────────────────────────────────────────

// class _PetWellnessCard extends StatelessWidget {
//   final ActivityData activity;
//   const _PetWellnessCard({required this.activity});

//   static const Color _primary = Color.fromARGB(255, 0, 150, 136);

//   String _movementIntensity(double magnitude) {
//     if (magnitude > 20) return 'Very High';
//     if (magnitude > 13) return 'High';
//     if (magnitude > 11) return 'Moderate';
//     if (magnitude > 10) return 'Low';
//     return 'Very Low';
//   }

//   Color _movementColor(double magnitude) {
//     if (magnitude > 20) return Colors.red;
//     if (magnitude > 13) return Colors.orange;
//     if (magnitude > 11) return Colors.blue;
//     if (magnitude > 10) return Colors.green;
//     return Colors.purple;
//   }

//   String _bodyStability(double gx, double gy, double gz) {
//     final gyroMag = (gx * gx + gy * gy + gz * gz);
//     if (gyroMag > 2.0) return 'Spinning / Shaking';
//     if (gyroMag > 0.5) return 'Moving around';
//     if (gyroMag > 0.05) return 'Slightly shifting';
//     return 'Calm & Steady';
//   }

//   IconData _stabilityIcon(double gx, double gy, double gz) {
//     final gyroMag = (gx * gx + gy * gy + gz * gz);
//     if (gyroMag > 2.0) return Icons.rotate_right;
//     if (gyroMag > 0.5) return Icons.waves;
//     if (gyroMag > 0.05) return Icons.swap_calls;
//     return Icons.spa;
//   }

//   String _posture(double ay) {
//     if (ay > 9.0) return 'Upright / Standing';
//     if (ay > 5.0) return 'Leaning / Tilted';
//     return 'Lying Down';
//   }

//   IconData _postureIcon(double ay) {
//     if (ay > 9.0) return Icons.vertical_align_top;
//     if (ay > 5.0) return Icons.trending_down;
//     return Icons.horizontal_rule;
//   }

//   String _wellnessMessage(ActivityData a) {
//     if (a.impactDetected) return 'Check on your pet — a fall or bump was detected!';
//     switch (a.activityType) {
//       case 'running': return 'Your pet is getting great exercise! 🏃';
//       case 'walking': return 'Your pet is enjoying a nice walk! 🐾';
//       case 'playing': return 'Your pet is happy and playful! 🎾';
//       case 'resting': return 'Your pet is relaxing comfortably. 😴';
//       default: return 'Your pet is doing well! 🐶';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final intensity = _movementIntensity(activity.magnitude);
//     final intensityColor = _movementColor(activity.magnitude);
//     final stability = _bodyStability(
//         activity.gyroscopeX, activity.gyroscopeY, activity.gyroscopeZ);
//     final stabilityIcon = _stabilityIcon(
//         activity.gyroscopeX, activity.gyroscopeY, activity.gyroscopeZ);
//     final posture = _posture(activity.accelerometerY);
//     final postureIcon = _postureIcon(activity.accelerometerY);
//     final intensityFraction = (activity.magnitude / 25.0).clamp(0.0, 1.0);

//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 3,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Row(
//               children: [
//                 Icon(Icons.favorite, color: Color.fromARGB(255, 0, 150, 136)),
//                 SizedBox(width: 8),
//                 Text('Pet Wellness',
//                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//               decoration: BoxDecoration(
//                 color: _primary.withOpacity(0.08),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Text(
//                 _wellnessMessage(activity),
//                 style: const TextStyle(fontSize: 13, color: Colors.black87),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//             const Divider(height: 24),
//             Row(
//               children: [
//                 Expanded(
//                   child: _WellnessTile(
//                     icon: Icons.bolt,
//                     iconColor: intensityColor,
//                     bgColor: intensityColor.withOpacity(0.1),
//                     title: 'Movement',
//                     value: intensity,
//                     subtitle: 'Intensity level',
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: _WellnessTile(
//                     icon: stabilityIcon,
//                     iconColor: Colors.indigo,
//                     bgColor: Colors.indigo.withOpacity(0.1),
//                     title: 'Balance',
//                     value: stability,
//                     subtitle: 'Body stability',
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 Expanded(
//                   child: _WellnessTile(
//                     icon: postureIcon,
//                     iconColor: Colors.teal,
//                     bgColor: Colors.teal.withOpacity(0.1),
//                     title: 'Posture',
//                     value: posture,
//                     subtitle: 'Body position',
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: _WellnessTile(
//                     icon: activity.impactDetected
//                         ? Icons.warning_amber
//                         : Icons.shield,
//                     iconColor:
//                         activity.impactDetected ? Colors.red : Colors.green,
//                     bgColor: activity.impactDetected
//                         ? Colors.red.withOpacity(0.1)
//                         : Colors.green.withOpacity(0.1),
//                     title: 'Safety',
//                     value: activity.impactDetected ? 'Check Pet!' : 'All Good',
//                     subtitle: 'No issues detected',
//                   ),
//                 ),
//               ],
//             ),
//             const Divider(height: 24),
//             const Text('Movement Intensity',
//                 style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey,
//                     fontWeight: FontWeight.w500)),
//             const SizedBox(height: 6),
//             Stack(
//               children: [
//                 Container(
//                   height: 12,
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade200,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                 ),
//                 AnimatedContainer(
//                   duration: const Duration(milliseconds: 600),
//                   height: 12,
//                   width: MediaQuery.of(context).size.width *
//                       intensityFraction *
//                       0.75,
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Colors.green, Colors.orange, Colors.red],
//                       stops: [0.0, 0.6, 1.0],
//                     ),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 4),
//             const Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Calm', style: TextStyle(fontSize: 10, color: Colors.grey)),
//                 Text('Active', style: TextStyle(fontSize: 10, color: Colors.grey)),
//                 Text('Very Active', style: TextStyle(fontSize: 10, color: Colors.grey)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _WellnessTile extends StatelessWidget {
//   final IconData icon;
//   final Color iconColor;
//   final Color bgColor;
//   final String title;
//   final String value;
//   final String subtitle;

//   const _WellnessTile({
//     required this.icon,
//     required this.iconColor,
//     required this.bgColor,
//     required this.title,
//     required this.value,
//     required this.subtitle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: iconColor, size: 18),
//               const SizedBox(width: 6),
//               Text(title,
//                   style: TextStyle(
//                       fontSize: 11,
//                       color: iconColor,
//                       fontWeight: FontWeight.w600)),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             value,
//             style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87),
//           ),
//           const SizedBox(height: 2),
//           Text(subtitle,
//               style: const TextStyle(fontSize: 10, color: Colors.grey)),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // TAB 2: SUMMARY
// // ─────────────────────────────────────────────────────────────────────────────

// class _SummaryTab extends ConsumerWidget {
//   const _SummaryTab();

//   static const Color _primary = Color.fromARGB(255, 0, 150, 136);

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final summariesAsync = ref.watch(dailySummariesProvider);
//     final impactAsync = ref.watch(impactAlertsProvider);

//     return RefreshIndicator(
//       onRefresh: () async {
//         ref.invalidate(dailySummariesProvider);
//         ref.invalidate(impactAlertsProvider);
//       },
//       child: SingleChildScrollView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('7-Day Activity Summary',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 12),
//             summariesAsync.when(
//               data: (summaries) {
//                 if (summaries.isEmpty) {
//                   return const _NoDataCard(
//                       message: 'No summary data yet.\nManually add data to Firebase to see charts.');
//                 }
//                 return Column(
//                   children: [
//                     _StepsBarChart(summaries: summaries),
//                     const SizedBox(height: 16),
//                     _ActiveMinutesChart(summaries: summaries),
//                     const SizedBox(height: 16),
//                     _SummaryStatsRow(summaries: summaries),
//                   ],
//                 );
//               },
//               loading: () => const Center(
//                   child: CircularProgressIndicator(color: _primary)),
//               error: (e, _) => _ErrorCard(error: e),
//             ),
//             const SizedBox(height: 24),
//             const Text('Recent Impacts',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 12),
//             impactAsync.when(
//               data: (impacts) {
//                 if (impacts.isEmpty) {
//                   return const _NoDataCard(
//                       message: 'No impacts recorded. Your pet is safe! 🐾');
//                 }
//                 return Column(
//                   children: impacts
//                       .take(5)
//                       .map((i) => _ImpactListTile(activity: i))
//                       .toList(),
//                 );
//               },
//               loading: () => const Center(
//                   child: CircularProgressIndicator(color: _primary)),
//               error: (e, _) => _ErrorCard(error: e),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // TAB 3: HISTORY
// // ─────────────────────────────────────────────────────────────────────────────

// class _HistoryTab extends ConsumerWidget {
//   const _HistoryTab();

//   static const Color _primary = Color.fromARGB(255, 0, 150, 136);

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final historyAsync = ref.watch(activityHistoryProvider);

//     return RefreshIndicator(
//       onRefresh: () async => ref.invalidate(activityHistoryProvider),
//       child: historyAsync.when(
//         data: (history) {
//           if (history.isEmpty) {
//             return const _NoDataCard(
//                 message: 'No history yet.\nAdd data to Firebase to see logs here.');
//           }
//           return ListView.separated(
//             padding: const EdgeInsets.all(12),
//             itemCount: history.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 8),
//             itemBuilder: (ctx, i) => _HistoryTile(activity: history[i]),
//           );
//         },
//         loading: () =>
//             const Center(child: CircularProgressIndicator(color: _primary)),
//         error: (e, _) => Center(child: _ErrorCard(error: e)),
//       ),
//     );
//   }
// }

// // ═════════════════════════════════════════════════════════════════════════════
// // WIDGETS
// // ═════════════════════════════════════════════════════════════════════════════

// class _ActivityStatusCard extends StatelessWidget {
//   final ActivityData activity;
//   const _ActivityStatusCard({required this.activity});

//   static const _activityColors = {
//     'walking': Color(0xFF4CAF50),
//     'running': Color(0xFF2196F3),
//     'resting': Color(0xFF9C27B0),
//     'playing': Color(0xFFFF9800),
//     'impact': Color(0xFFF44336),
//   };

//   static const _activityEmojis = {
//     'walking': '🐕',
//     'running': '🐕‍🦺',
//     'resting': '🐾',
//     'playing': '🦴',
//     'impact': '⚠️',
//   };

//   @override
//   Widget build(BuildContext context) {
//     final color = _activityColors[activity.activityType] ?? Colors.teal;
//     final emoji = _activityEmojis[activity.activityType] ?? '🐶';

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [color.withOpacity(0.8), color],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//               color: color.withOpacity(0.4),
//               blurRadius: 12,
//               offset: const Offset(0, 6))
//         ],
//       ),
//       child: Row(
//         children: [
//           Text(emoji, style: const TextStyle(fontSize: 52)),
//           const SizedBox(width: 20),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('Current Activity',
//                     style: TextStyle(color: Colors.white70, fontSize: 13)),
//                 Text(
//                   activity.activityType.toUpperCase(),
//                   style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 26,
//                       fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   _formatTime(activity.timestamp),
//                   style: const TextStyle(color: Colors.white70, fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//           Column(
//             children: [
//               _StatBubble(value: '${activity.stepCount}', label: 'Steps'),
//               const SizedBox(height: 8),
//               _StatBubble(
//                   value: '${activity.activeMinutes.toStringAsFixed(0)}m',
//                   label: 'Active'),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatTime(DateTime dt) =>
//       '${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
// }

// class _StatBubble extends StatelessWidget {
//   final String value;
//   final String label;
//   const _StatBubble({required this.value, required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.25),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Text(value,
//               style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16)),
//           Text(label,
//               style: const TextStyle(color: Colors.white70, fontSize: 11)),
//         ],
//       ),
//     );
//   }
// }

// class _ImpactAlertBanner extends StatelessWidget {
//   final double severity;
//   const _ImpactAlertBanner({required this.severity});

//   @override
//   Widget build(BuildContext context) {
//     final isHigh = severity >= 7.0;
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: isHigh ? Colors.red.shade50 : Colors.orange.shade50,
//         border:
//             Border.all(color: isHigh ? Colors.red : Colors.orange, width: 2),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.warning_amber,
//               color: isHigh ? Colors.red : Colors.orange, size: 32),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   isHigh ? '🚨 HIGH IMPACT DETECTED!' : '⚠️ Impact Detected',
//                   style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: isHigh ? Colors.red : Colors.orange,
//                       fontSize: 15),
//                 ),
//                 Text(
//                   'Severity: ${severity.toStringAsFixed(1)} / 10',
//                   style: const TextStyle(color: Colors.black87),
//                 ),
//                 if (isHigh)
//                   const Text(
//                     'Consider checking on your pet!',
//                     style: TextStyle(color: Colors.red, fontSize: 12),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _StepsCard extends StatelessWidget {
//   final ActivityData activity;
//   const _StepsCard({required this.activity});

//   @override
//   Widget build(BuildContext context) {
//     final progress = (activity.activeMinutes / 60.0).clamp(0.0, 1.0);
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 3,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Row(children: [
//               Text('🐾', style: TextStyle(fontSize: 20)),
//               SizedBox(width: 8),
//               Text('Activity Progress',
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
//             ]),
//             const SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _BigStat(
//                     value: '${activity.stepCount}', label: 'Steps Today'),
//                 _BigStat(
//                     value: '${activity.activeMinutes.toStringAsFixed(0)} min',
//                     label: 'Active Time'),
//               ],
//             ),
//             const SizedBox(height: 16),
//             const Text('Daily Goal Progress (60 min)',
//                 style: TextStyle(color: Colors.grey, fontSize: 12)),
//             const SizedBox(height: 6),
//             LinearProgressIndicator(
//               value: progress,
//               backgroundColor: Colors.grey.shade200,
//               color: const Color.fromARGB(255, 0, 150, 136),
//               minHeight: 10,
//               borderRadius: BorderRadius.circular(5),
//             ),
//             const SizedBox(height: 4),
//             Text('${(progress * 100).toStringAsFixed(0)}% of daily goal',
//                 style: const TextStyle(color: Colors.grey, fontSize: 11)),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _BigStat extends StatelessWidget {
//   final String value;
//   final String label;
//   const _BigStat({required this.value, required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(value,
//             style: const TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//                 color: Color.fromARGB(255, 0, 150, 136))),
//         Text(label,
//             style: const TextStyle(color: Colors.grey, fontSize: 12)),
//       ],
//     );
//   }
// }

// // ─── Bar Charts ───────────────────────────────────────────────────────────────

// class _StepsBarChart extends StatelessWidget {
//   final List<ActivitySummary> summaries;
//   const _StepsBarChart({required this.summaries});

//   @override
//   Widget build(BuildContext context) {
//     final maxSteps =
//         summaries.map((s) => s.totalSteps).reduce((a, b) => a > b ? a : b);

//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 3,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Steps per Day',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
//             const SizedBox(height: 16),
//             SizedBox(
//               height: 140,
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: summaries.reversed.take(7).map((s) {
//                   final heightFraction =
//                       maxSteps > 0 ? s.totalSteps / maxSteps : 0.0;
//                   return _Bar(
//                     heightFraction: heightFraction,
//                     label: _dayLabel(s.date),
//                     value: '${s.totalSteps}',
//                     color: const Color.fromARGB(255, 0, 150, 136),
//                   );
//                 }).toList(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _dayLabel(DateTime dt) {
//     const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//     return days[dt.weekday - 1];
//   }
// }

// class _ActiveMinutesChart extends StatelessWidget {
//   final List<ActivitySummary> summaries;
//   const _ActiveMinutesChart({required this.summaries});

//   @override
//   Widget build(BuildContext context) {
//     final maxMins = summaries
//         .map((s) => s.totalActiveMinutes)
//         .reduce((a, b) => a > b ? a : b);

//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 3,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Active Minutes per Day',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
//             const SizedBox(height: 16),
//             SizedBox(
//               height: 140,
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: summaries.reversed.take(7).map((s) {
//                   final heightFraction =
//                       maxMins > 0 ? s.totalActiveMinutes / maxMins : 0.0;
//                   return _Bar(
//                     heightFraction: heightFraction,
//                     label: _dayLabel(s.date),
//                     value: '${s.totalActiveMinutes.toStringAsFixed(0)}m',
//                     color: Colors.blue,
//                   );
//                 }).toList(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _dayLabel(DateTime dt) {
//     const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//     return days[dt.weekday - 1];
//   }
// }

// class _Bar extends StatelessWidget {
//   final double heightFraction;
//   final String label;
//   final String value;
//   final Color color;
//   const _Bar({
//     required this.heightFraction,
//     required this.label,
//     required this.value,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         Text(value,
//             style: TextStyle(
//                 fontSize: 9, color: color, fontWeight: FontWeight.bold)),
//         const SizedBox(height: 2),
//         AnimatedContainer(
//           duration: const Duration(milliseconds: 600),
//           width: 28,
//           height: (heightFraction * 100).clamp(4.0, 100.0),
//           decoration: BoxDecoration(
//             color: color,
//             borderRadius:
//                 const BorderRadius.vertical(top: Radius.circular(6)),
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(label,
//             style: const TextStyle(fontSize: 10, color: Colors.grey)),
//       ],
//     );
//   }
// }

// class _SummaryStatsRow extends StatelessWidget {
//   final List<ActivitySummary> summaries;
//   const _SummaryStatsRow({required this.summaries});

//   @override
//   Widget build(BuildContext context) {
//     final totalSteps = summaries.fold(0, (sum, s) => sum + s.totalSteps);
//     final totalMins =
//         summaries.fold(0.0, (sum, s) => sum + s.totalActiveMinutes);
//     final totalImpacts = summaries.fold(0, (sum, s) => sum + s.impactCount);

//     return Row(
//       children: [
//         Expanded(
//             child: _SummaryChip(
//                 icon: Icons.pets,
//                 value: '$totalSteps',
//                 label: 'Total Steps',
//                 color: Colors.teal)),
//         const SizedBox(width: 8),
//         Expanded(
//             child: _SummaryChip(
//                 icon: Icons.timer,
//                 value: '${totalMins.toStringAsFixed(0)}m',
//                 label: 'Active Time',
//                 color: Colors.blue)),
//         const SizedBox(width: 8),
//         Expanded(
//             child: _SummaryChip(
//                 icon: Icons.warning_amber,
//                 value: '$totalImpacts',
//                 label: 'Impacts',
//                 color: totalImpacts > 0 ? Colors.red : Colors.green)),
//       ],
//     );
//   }
// }

// class _SummaryChip extends StatelessWidget {
//   final IconData icon;
//   final String value;
//   final String label;
//   final Color color;
//   const _SummaryChip({
//     required this.icon,
//     required this.value,
//     required this.label,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, color: color, size: 22),
//           const SizedBox(height: 4),
//           Text(value,
//               style: TextStyle(
//                   fontWeight: FontWeight.bold, fontSize: 18, color: color)),
//           Text(label,
//               style: const TextStyle(fontSize: 10, color: Colors.grey),
//               textAlign: TextAlign.center),
//         ],
//       ),
//     );
//   }
// }

// class _ImpactListTile extends StatelessWidget {
//   final ActivityData activity;
//   const _ImpactListTile({required this.activity});

//   @override
//   Widget build(BuildContext context) {
//     final isHigh = activity.impactSeverity >= 7.0;
//     return Container(
//       margin: const EdgeInsets.only(bottom: 6),
//       decoration: BoxDecoration(
//         color: isHigh ? Colors.red.shade50 : Colors.orange.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//             color: isHigh ? Colors.red.shade200 : Colors.orange.shade200),
//       ),
//       child: ListTile(
//         leading: Icon(Icons.warning_amber,
//             color: isHigh ? Colors.red : Colors.orange),
//         title: Text(
//             'Severity: ${activity.impactSeverity.toStringAsFixed(1)}/10',
//             style: const TextStyle(fontWeight: FontWeight.bold)),
//         subtitle: Text(
//             '${activity.timestamp.day}/${activity.timestamp.month} at '
//             '${activity.timestamp.hour.toString().padLeft(2, '0')}:'
//             '${activity.timestamp.minute.toString().padLeft(2, '0')}'),
//         trailing: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//           decoration: BoxDecoration(
//             color: isHigh ? Colors.red : Colors.orange,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Text(
//             isHigh ? 'HIGH' : 'MED',
//             style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 11,
//                 fontWeight: FontWeight.bold),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _HistoryTile extends StatelessWidget {
//   final ActivityData activity;
//   const _HistoryTile({required this.activity});

//   static const _activityColors = {
//     'walking': Color(0xFF4CAF50),
//     'running': Color(0xFF2196F3),
//     'resting': Color(0xFF9C27B0),
//     'playing': Color(0xFFFF9800),
//     'impact': Color(0xFFF44336),
//   };

//   static const _activityEmojis = {
//     'walking': '🐕',
//     'running': '🐕‍🦺',
//     'resting': '🐾',
//     'playing': '🦴',
//     'impact': '⚠️',
//   };

//   @override
//   Widget build(BuildContext context) {
//     final color = _activityColors[activity.activityType] ?? Colors.teal;
//     final emoji = _activityEmojis[activity.activityType] ?? '🐶';
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                   color: color.withOpacity(0.15),
//                   borderRadius: BorderRadius.circular(10)),
//               child: Text(emoji, style: const TextStyle(fontSize: 22)),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     activity.activityType.toUpperCase(),
//                     style:
//                         TextStyle(fontWeight: FontWeight.bold, color: color),
//                   ),
//                   Text(
//                     '${activity.timestamp.day}/${activity.timestamp.month}  '
//                     '${activity.timestamp.hour.toString().padLeft(2, '0')}:'
//                     '${activity.timestamp.minute.toString().padLeft(2, '0')}',
//                     style:
//                         const TextStyle(color: Colors.grey, fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Text('${activity.stepCount} steps',
//                     style: const TextStyle(
//                         fontSize: 12, fontWeight: FontWeight.w500)),
//                 if (activity.impactDetected)
//                   const Text('⚠️ Impact',
//                       style: TextStyle(color: Colors.red, fontSize: 11)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─── Shared helper widgets ────────────────────────────────────────────────────

// class _NoDataCard extends StatelessWidget {
//   final String message;
//   const _NoDataCard({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 40),
//         child: Column(
//           children: [
//             const Icon(Icons.sensors_off, size: 60, color: Colors.grey),
//             const SizedBox(height: 12),
//             Text(
//               message,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.grey, fontSize: 14),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _ErrorCard extends StatelessWidget {
//   final Object error;
//   const _ErrorCard({required this.error});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//           color: Colors.red.shade50,
//           borderRadius: BorderRadius.circular(12)),
//       child:
//           Text('Error: $error', style: const TextStyle(color: Colors.red)),
//     );
//   }
// }

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

class _PgColors {
  static const Color primary = Color(0xFF009688);
  static const Color primaryDark = Color(0xFF00796B);
  static const Color page = Color(0xFFF4F7F7);
  static const Color card = Colors.white;
  static const Color soft = Color(0xFFEAF7F5);
  static const Color soft2 = Color(0xFFF1FBF9);
  static const Color text = Color(0xFF143237);
  static const Color subtext = Color(0xFF6D8387);
  static const Color border = Color(0xFFDCE9E7);
  static const Color warning = Color(0xFFF57C00);
  static const Color danger = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
}

class _PgDecor {
  static BorderRadius get xl => BorderRadius.circular(24);
  static BorderRadius get lg => BorderRadius.circular(20);
  static BorderRadius get md => BorderRadius.circular(16);

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
// LIVE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _LiveTab extends ConsumerWidget {
  const _LiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(currentActivityProvider);

    return RefreshIndicator(
      color: _PgColors.primary,
      onRefresh: () async => ref.invalidate(currentActivityProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: activityAsync.when(
          data: (activity) {
            if (activity == null) {
              return const _NoDataCard(
                message:
                    'No live activity data yet.\nData will appear once the collar sensor is connected.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LiveHeroCard(activity: activity),
                const SizedBox(height: 14),
                _StatStrip(activity: activity),
                const SizedBox(height: 14),
                if (activity.impactDetected) ...[
                  _ImpactAlertBanner(severity: activity.impactSeverity),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _InsightMiniCard(
                        icon: _activityIcon(activity.activityType),
                        iconColor: _PgColors.primary,
                        iconBg: _PgColors.soft,
                        title: 'Current Activity',
                        value: _activityTitle(activity.activityType),
                        subtitle:
                            'Updated ${_formatTime(activity.timestamp)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InsightMiniCard(
                        icon: activity.impactDetected
                            ? Icons.warning_amber_rounded
                            : Icons.verified_outlined,
                        iconColor: activity.impactDetected
                            ? _PgColors.warning
                            : _PgColors.success,
                        iconBg: activity.impactDetected
                            ? const Color(0xFFFFF3E8)
                            : const Color(0xFFEFF8F0),
                        title: 'Safety Status',
                        value:
                            activity.impactDetected ? 'Check Pet' : 'Normal',
                        subtitle: activity.impactDetected
                            ? 'Impact detected'
                            : 'No abnormal impact detected',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _LiveSnapshotCard(activity: activity),
                const SizedBox(height: 14),
                _WellnessDashboardCard(activity: activity),
                const SizedBox(height: 14),
                _ProgressCard(activity: activity),
              ],
            );
          },
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(error: e),
        ),
      ),
    );
  }
}

class _LiveHeroCard extends StatelessWidget {
  final ActivityData activity;
  const _LiveHeroCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final bool alert = activity.impactDetected;
    final icon = _activityIcon(activity.activityType);
    final title = _activityTitle(activity.activityType);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: alert
              ? [const Color(0xFFE86D5B), const Color(0xFFD84F43)]
              : [const Color(0xFF10B5A7), _PgColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: _PgDecor.xl,
        boxShadow: [
          BoxShadow(
            color: (alert ? _PgColors.danger : _PgColors.primary)
                .withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(icon, size: 34, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Live collar status and motion insights',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Updated ${_formatTime(activity.timestamp)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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

class _StatStrip extends StatelessWidget {
  final ActivityData activity;
  const _StatStrip({required this.activity});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        icon: Icons.pets_rounded,
        title: 'Steps',
        value: '${activity.stepCount}',
      ),
      (
        icon: Icons.timer_outlined,
        title: 'Active Time',
        value: '${activity.activeMinutes.toStringAsFixed(0)} min',
      ),
      (
        icon: activity.impactDetected
            ? Icons.warning_amber_rounded
            : Icons.shield_outlined,
        title: 'Impact',
        value: activity.impactDetected ? 'Detected' : 'None',
      ),
    ];

    return Row(
      children: items.map((item) {
        final isLast = identical(item, items.last);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: Container(
              decoration: _PgDecor.card(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _PgColors.soft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.icon, color: _PgColors.primary, size: 22),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _PgColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _PgColors.subtext,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InsightMiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String value;
  final String subtitle;

  const _InsightMiniCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: _PgColors.subtext,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _PgColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: _PgColors.subtext,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSnapshotCard extends StatelessWidget {
  final ActivityData activity;
  const _LiveSnapshotCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.monitor_heart_outlined,
            title: 'Live Activity Snapshot',
            subtitle: 'Quick glance at the pet’s current motion state',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SnapshotTile(
                  icon: _activityIcon(activity.activityType),
                  iconColor: _PgColors.primary,
                  bgColor: const Color(0xFFF0FAF8),
                  title: 'Motion State',
                  value: _activityTitle(activity.activityType),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SnapshotTile(
                  icon: Icons.warning_amber_rounded,
                  iconColor: activity.impactDetected
                      ? _PgColors.danger
                      : _PgColors.warning,
                  bgColor: const Color(0xFFFFF6EE),
                  title: 'Impact Severity',
                  value: '${activity.impactSeverity.toStringAsFixed(1)} / 10',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String value;

  const _SnapshotTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: _PgDecor.lg,
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _PgColors.subtext,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: _PgColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

class _WellnessDashboardCard extends StatelessWidget {
  final ActivityData activity;
  const _WellnessDashboardCard({required this.activity});

  String _movementIntensity(double magnitude) {
    if (magnitude > 20) return 'Very High';
    if (magnitude > 13) return 'High';
    if (magnitude > 11) return 'Moderate';
    if (magnitude > 10) return 'Low';
    return 'Very Low';
  }

  String _bodyStability(double gx, double gy, double gz) {
    final gyroMag = (gx * gx + gy * gy + gz * gz);
    if (gyroMag > 2.0) return 'Spinning / Shaking';
    if (gyroMag > 0.5) return 'Moving Around';
    if (gyroMag > 0.05) return 'Slightly Shifting';
    return 'Calm & Steady';
  }

  String _posture(double ay) {
    if (ay > 9.0) return 'Upright / Standing';
    if (ay > 5.0) return 'Leaning / Tilted';
    return 'Lying Down';
  }

  IconData _stabilityIcon(double gx, double gy, double gz) {
    final gyroMag = (gx * gx + gy * gy + gz * gz);
    if (gyroMag > 2.0) return Icons.sync;
    if (gyroMag > 0.5) return Icons.compare_arrows_rounded;
    if (gyroMag > 0.05) return Icons.waves_outlined;
    return Icons.spa_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final movement = _movementIntensity(activity.magnitude);
    final stability = _bodyStability(
      activity.gyroscopeX,
      activity.gyroscopeY,
      activity.gyroscopeZ,
    );
    final posture = _posture(activity.accelerometerY);
    final intensity = (activity.magnitude / 25.0).clamp(0.0, 1.0);

    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.favorite_border_rounded,
            title: 'Pet Wellness',
            subtitle: 'Movement quality, balance, posture, and safety',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WellnessGridTile(
                  icon: Icons.flash_on_rounded,
                  title: 'Movement',
                  value: movement,
                  subtitle: 'Intensity level',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WellnessGridTile(
                  icon: _stabilityIcon(
                    activity.gyroscopeX,
                    activity.gyroscopeY,
                    activity.gyroscopeZ,
                  ),
                  title: 'Balance',
                  value: stability,
                  subtitle: 'Body stability',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WellnessGridTile(
                  icon: Icons.bed_outlined,
                  title: 'Posture',
                  value: posture,
                  subtitle: 'Body position',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WellnessGridTile(
                  icon: activity.impactDetected
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                  title: 'Safety',
                  value: activity.impactDetected ? 'Check Pet' : 'All Good',
                  subtitle: activity.impactDetected
                      ? 'Impact detected'
                      : 'No issues detected',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Movement Intensity',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _PgColors.subtext,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: intensity,
              minHeight: 14,
              backgroundColor: const Color(0xFFE7E7E7),
              color: _PgColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Calm',
                  style: TextStyle(fontSize: 11, color: _PgColors.subtext)),
              Text('Active',
                  style: TextStyle(fontSize: 11, color: _PgColors.subtext)),
              Text('Very Active',
                  style: TextStyle(fontSize: 11, color: _PgColors.subtext)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WellnessGridTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _WellnessGridTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _PgColors.soft2,
        borderRadius: _PgDecor.lg,
        border: Border.all(color: const Color(0xFFE7F2F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _PgColors.primary, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: _PgColors.subtext,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _PgColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: _PgColors.subtext,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final ActivityData activity;
  const _ProgressCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final progress = (activity.activeMinutes / 60.0).clamp(0.0, 1.0);

    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.donut_large_rounded,
            title: 'Daily Activity Progress',
            subtitle: 'Steps, active time, and goal completion',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ProgressMetric(
                  value: '${activity.stepCount}',
                  label: 'Steps Today',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProgressMetric(
                  value: '${activity.activeMinutes.toStringAsFixed(0)} min',
                  label: 'Active Time',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Daily Goal Progress (60 min)',
            style: TextStyle(
              fontSize: 13,
              color: _PgColors.subtext,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFE7E7E7),
              color: _PgColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% of daily goal completed',
            style: const TextStyle(
              fontSize: 12,
              color: _PgColors.subtext,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  final String value;
  final String label;

  const _ProgressMetric({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: _PgColors.soft,
        borderRadius: _PgDecor.lg,
        border: Border.all(color: const Color(0xFFE1F1EE)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _PgColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _PgColors.subtext,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(dailySummariesProvider);
    final impactAsync = ref.watch(impactAlertsProvider);

    return RefreshIndicator(
      color: _PgColors.primary,
      onRefresh: () async {
        ref.invalidate(dailySummariesProvider);
        ref.invalidate(impactAlertsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TopLabel(
              title: 'Weekly Summary',
              subtitle: 'A clear view of recent activity and impact history',
            ),
            const SizedBox(height: 16),
            summariesAsync.when(
              data: (summaries) {
                if (summaries.isEmpty) {
                  return const _NoDataCard(
                    message:
                        'No summary data yet.\nManually add data to Firebase to see charts.',
                  );
                }
                return Column(
                  children: [
                    _StepsBarChart(summaries: summaries),
                    const SizedBox(height: 14),
                    _ActiveMinutesChart(summaries: summaries),
                    const SizedBox(height: 14),
                    _SummaryStatsRow(summaries: summaries),
                  ],
                );
              },
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(error: e),
            ),
            const SizedBox(height: 18),
            const _TopLabel(
              title: 'Recent Impacts',
              subtitle: 'Latest severity records from the collar',
            ),
            const SizedBox(height: 12),
            impactAsync.when(
              data: (impacts) {
                if (impacts.isEmpty) {
                  return const _NoDataCard(
                    message: 'No impacts recorded. Your pet is safe!',
                  );
                }
                return Column(
                  children: impacts
                      .take(5)
                      .map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
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

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY TAB
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
                message: 'No history yet.\nAdd data to Firebase to see logs here.',
              ),
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _PgColors.soft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: _PgColors.primary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _PgColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _PgColors.subtext,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TopLabel({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _PgColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: _PgColors.subtext,
          ),
        ),
      ],
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
      child: const Column(
        children: [
          CircularProgressIndicator(color: _PgColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading activity data...',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _PgColors.text,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Please wait while the latest collar information is fetched.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _PgColors.subtext,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactAlertBanner extends StatelessWidget {
  final double severity;
  const _ImpactAlertBanner({required this.severity});

  @override
  Widget build(BuildContext context) {
    final high = severity >= 7.0;

    return Container(
      decoration: BoxDecoration(
        color: high ? const Color(0xFFFFEFEE) : const Color(0xFFFFF5EA),
        borderRadius: _PgDecor.lg,
        border: Border.all(
          color: high ? const Color(0xFFF4C7C1) : const Color(0xFFF6D9B8),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: high ? const Color(0xFFFBE1DD) : const Color(0xFFFFE7CC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: high ? _PgColors.danger : _PgColors.warning,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  high ? 'High Impact Detected' : 'Impact Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: high ? _PgColors.danger : _PgColors.warning,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Severity: ${severity.toStringAsFixed(1)} / 10',
                  style: const TextStyle(
                    color: _PgColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  high
                      ? 'Please check on your pet as soon as possible.'
                      : 'A moderate impact was recorded. Monitor your pet closely.',
                  style: const TextStyle(
                    color: _PgColors.subtext,
                    fontSize: 12,
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

class _StepsBarChart extends StatelessWidget {
  final List<ActivitySummary> summaries;
  const _StepsBarChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final maxSteps =
        summaries.map((s) => s.totalSteps).reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Steps per Day',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _PgColors.text,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: summaries.reversed.take(7).map((s) {
                final fraction = maxSteps > 0 ? s.totalSteps / maxSteps : 0.0;
                return _Bar(
                  heightFraction: fraction,
                  label: _dayLabel(s.date),
                  value: '${s.totalSteps}',
                  color: _PgColors.primary,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
}

class _ActiveMinutesChart extends StatelessWidget {
  final List<ActivitySummary> summaries;
  const _ActiveMinutesChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final maxMins = summaries
        .map((s) => s.totalActiveMinutes)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Minutes per Day',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _PgColors.text,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: summaries.reversed.take(7).map((s) {
                final fraction =
                    maxMins > 0 ? s.totalActiveMinutes / maxMins : 0.0;
                return _Bar(
                  heightFraction: fraction,
                  label: _dayLabel(s.date),
                  value: '${s.totalActiveMinutes.toStringAsFixed(0)}m',
                  color: const Color(0xFF26A69A),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
}

class _Bar extends StatelessWidget {
  final double heightFraction;
  final String label;
  final String value;
  final Color color;

  const _Bar({
    required this.heightFraction,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          width: 28,
          height: (heightFraction * 104).clamp(6.0, 104.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _PgColors.subtext),
        ),
      ],
    );
  }
}

class _SummaryStatsRow extends StatelessWidget {
  final List<ActivitySummary> summaries;
  const _SummaryStatsRow({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final totalSteps = summaries.fold(0, (sum, s) => sum + s.totalSteps);
    final totalMins =
        summaries.fold(0.0, (sum, s) => sum + s.totalActiveMinutes);
    final totalImpacts = summaries.fold(0, (sum, s) => sum + s.impactCount);

    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
            icon: Icons.pets_rounded,
            value: '$totalSteps',
            label: 'Total Steps',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryChip(
            icon: Icons.timer_outlined,
            value: '${totalMins.toStringAsFixed(0)}m',
            label: 'Active Time',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryChip(
            icon: Icons.warning_amber_rounded,
            value: '$totalImpacts',
            label: 'Impacts',
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _PgColors.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _PgColors.primary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _PgColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: _PgColors.subtext,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactListTile extends StatelessWidget {
  final ActivityData activity;
  const _ImpactListTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final high = activity.impactSeverity >= 7.0;

    return Container(
      decoration: _PgDecor.card(
        color: high ? const Color(0xFFFFF5F4) : _PgColors.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: high ? const Color(0xFFFFE2DF) : const Color(0xFFFFF1DE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: high ? _PgColors.danger : _PgColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Severity: ${activity.impactSeverity.toStringAsFixed(1)}/10',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _PgColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity.timestamp.day}/${activity.timestamp.month} at '
                  '${activity.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${activity.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: _PgColors.subtext,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: high ? _PgColors.danger : _PgColors.warning,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              high ? 'HIGH' : 'MED',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ActivityData activity;
  const _HistoryTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final icon = _activityIcon(activity.activityType);

    return Container(
      decoration: _PgDecor.card(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _PgColors.soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _PgColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityTitle(activity.activityType),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _PgColors.text,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity.timestamp.day}/${activity.timestamp.month}  '
                  '${activity.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${activity.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: _PgColors.subtext,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${activity.stepCount} steps',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _PgColors.text,
                ),
              ),
              const SizedBox(height: 4),
              if (activity.impactDetected)
                const Text(
                  'Impact',
                  style: TextStyle(
                    color: _PgColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
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
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _PgColors.soft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.sensors_off_outlined,
              color: _PgColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _PgColors.subtext,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
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
        border: Border.all(color: const Color(0xFFF2D2CE)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _PgColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Error: $error',
              style: const TextStyle(color: _PgColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

IconData _activityIcon(String type) {
  switch (type.toLowerCase()) {
    case 'walking':
      return Icons.directions_walk_rounded;
    case 'running':
      return Icons.directions_run_rounded;
    case 'resting':
      return Icons.nightlight_round;
    case 'playing':
      return Icons.pets_rounded;
    case 'impact':
      return Icons.warning_amber_rounded;
    default:
      return Icons.monitor_heart_outlined;
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