import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/incident_report_model.dart';

class AdminAnalyticsView extends StatelessWidget {
  final List<IncidentReport> incidents;

  const AdminAnalyticsView({
    super.key,
    required this.incidents,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Metric Calculations
    final total = incidents.length;
    final confirmed = incidents
        .where((i) => i.eventCategory == EventCategory.confirmedAccident || i.status == IncidentStatus.verified)
        .length;
    final detected = incidents
        .where((i) => i.eventCategory == EventCategory.detectedEvent && i.status != IncidentStatus.falseAlarm)
        .length;
    final reported = incidents
        .where((i) => i.eventCategory == EventCategory.reportedAccident)
        .length;
    final falseAlarms = incidents
        .where((i) => i.status == IncidentStatus.falseAlarm)
        .length;
    final deliveredAlerts = incidents
        .where((i) => i.alertDeliveryStatus == AlertDeliveryStatus.delivered)
        .length;

    final deliverySuccessRate = total > 0 ? ((deliveredAlerts / total) * 100).toStringAsFixed(1) : '100.0';
    final confirmedRate = total > 0 ? ((confirmed / total) * 100).toStringAsFixed(1) : '0.0';
    final falseAlarmRate = total > 0 ? ((falseAlarms / total) * 100).toStringAsFixed(1) : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accident Analytics & Telemetry Metrics',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Multi-source telemetry breakdown: Helmet sensor triggers, verified collisions, and external alerts.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8E8E93),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                    const SizedBox(width: 8),
                    Text(
                      'Live Cloud Sync: $total Incidents',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF00E676),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4 Core KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              return GridView.count(
                crossAxisCount: isDesktop ? 4 : (constraints.maxWidth > 550 ? 2 : 1),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 1.6 : 1.8,
                children: [
                  _buildKpiCard(
                    title: 'TOTAL INCIDENTS',
                    value: '$total',
                    subtitle: 'All Recorded Telemetry Events',
                    icon: Icons.shield_outlined,
                    accentColor: const Color(0xFF00E5FF),
                    badge: '100% Tracked',
                  ),
                  _buildKpiCard(
                    title: 'CONFIRMED ACCIDENTS',
                    value: '$confirmed',
                    subtitle: '$confirmedRate% of total incidents verified',
                    icon: Icons.warning_amber_rounded,
                    accentColor: const Color(0xFFE82127),
                    badge: 'Critical Priority',
                  ),
                  _buildKpiCard(
                    title: 'FALSE ALARMS',
                    value: '$falseAlarms',
                    subtitle: '$falseAlarmRate% rider cancelled within 10s',
                    icon: Icons.cancel_outlined,
                    accentColor: const Color(0xFFFF9500),
                    badge: 'Safe Disarm',
                  ),
                  _buildKpiCard(
                    title: 'ALERT DELIVERY SUCCESS',
                    value: '$deliverySuccessRate%',
                    subtitle: '$deliveredAlerts emergency SMS & calls transmitted',
                    icon: Icons.cell_tower_rounded,
                    accentColor: const Color(0xFF00E676),
                    badge: 'Avg latency: 2.1s',
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // 3-Way Category Distinction Card
          _buildThreeWayDistinctionCard(detected, confirmed, reported),

          const SizedBox(height: 24),

          // Daily, Weekly, Monthly Trends & Status Distribution
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 850;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildTrendsChartCard(incidents),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _buildStatusDistributionCard(confirmed, detected, reported, falseAlarms),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTrendsChartCard(incidents),
                    const SizedBox(height: 16),
                    _buildStatusDistributionCard(confirmed, detected, reported, falseAlarms),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF8E8E93),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF636366),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                badge,
                style: GoogleFonts.jetBrainsMono(
                  color: accentColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThreeWayDistinctionCard(int detected, int confirmed, int reported) {
    final total = (detected + confirmed + reported).clamp(1, 999999);
    final detPct = (detected / total * 100).round();
    final confPct = (confirmed / total * 100).round();
    final repPct = (reported / total * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_rounded, color: Color(0xFFFF5E3A), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'CORE CLASSIFICATION (Detected vs Confirmed vs Reported)',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'MotoShield Verification Pipeline',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8E8E93),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Multi-color segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(flex: confirmed, child: Container(color: const Color(0xFFE82127))),
                  Expanded(flex: detected, child: Container(color: const Color(0xFFFF9500))),
                  Expanded(flex: reported, child: Container(color: const Color(0xFF00E5FF))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCategoryPill(
                  title: 'CONFIRMED ACCIDENT',
                  count: confirmed,
                  pct: confPct,
                  desc: 'Physical impact verified with responder/evidence',
                  color: const Color(0xFFE82127),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryPill(
                  title: 'DETECTED EVENT',
                  count: detected,
                  pct: detPct,
                  desc: 'Helmet accelerometer & tilt threshold trigger',
                  color: const Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryPill(
                  title: 'REPORTED ACCIDENT',
                  count: reported,
                  pct: repPct,
                  desc: 'External witness or bystander manual SOS report',
                  color: const Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String title,
    required int count,
    required int pct,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$pct%',
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count Incidents',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.inter(
              color: const Color(0xFF8E8E93),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsChartCard(List<IncidentReport> list) {
    // Group last 7 days incidents
    final now = DateTime.now();
    final List<Map<String, dynamic>> dailyCounts = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStr = DateFormat('E').format(day); // Mon, Tue...
      final count = list.where((item) {
        return item.timestamp.year == day.year &&
            item.timestamp.month == day.month &&
            item.timestamp.day == day.day;
      }).length;
      dailyCounts.add({'day': dayStr, 'count': count});
    }

    final maxCount = dailyCounts.map((e) => e['count'] as int).fold(1, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
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
                    'WEEKLY & MONTHLY ACCIDENT TRENDS',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daily distribution of collisions recorded across monitored highway networks',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8E8E93),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Last 7 Days',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Bar Chart
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyCounts.map((item) {
                final count = item['count'] as int;
                final day = item['day'] as String;
                final heightFactor = (count / maxCount).clamp(0.08, 1.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: GoogleFonts.jetBrainsMono(
                            color: count > 0 ? Colors.white : const Color(0xFF636366),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 130 * heightFactor,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: count > 2
                                  ? [const Color(0xFFE82127), const Color(0xFFFF5E3A)]
                                  : [const Color(0xFF00E5FF), const Color(0xFF007AFF)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day,
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF8E8E93),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistributionCard(int confirmed, int detected, int reported, int falseAlarms) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VERIFICATION RATIO',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Breakdown of confirmed vs false positive dispatches',
            style: GoogleFonts.inter(
              color: const Color(0xFF8E8E93),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          _buildRatioBar('Confirmed Serious Crash', confirmed, const Color(0xFFE82127)),
          const SizedBox(height: 12),
          _buildRatioBar('Sensor Trigger (Pending)', detected, const Color(0xFFFF9500)),
          const SizedBox(height: 12),
          _buildRatioBar('External Witness SOS', reported, const Color(0xFF00E5FF)),
          const SizedBox(height: 12),
          _buildRatioBar('False Alarms Cancelled', falseAlarms, const Color(0xFF636366)),
        ],
      ),
    );
  }

  Widget _buildRatioBar(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: count > 0 ? (count / 10).clamp(0.05, 1.0) : 0.0,
            backgroundColor: const Color(0xFF2C2C2E),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
