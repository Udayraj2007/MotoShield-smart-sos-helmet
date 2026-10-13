import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/screens/login_screen.dart';
import '../models/incident_report_model.dart';
import '../services/incident_firestore_service.dart';
import '../views/admin_analytics_view.dart';
import '../views/admin_live_map_view.dart';
import '../views/admin_reports_management_view.dart';
import '../views/admin_insights_prevention_view.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToRiderApp;

  const AdminDashboardScreen({
    super.key,
    this.onSwitchToRiderApp,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTab = 0; // 0: Analytics, 1: Live Map, 2: Reports, 3: Insights
  StreamSubscription<List<IncidentReport>>? _streamSub;
  List<IncidentReport> _incidents = [];
  bool _isLoading = true;

  void _handleSwitchToRider() {
    if (widget.onSwitchToRiderApp != null) {
      widget.onSwitchToRiderApp!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onSwitchToAdmin: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // 1. Instantly populate demo data in memory so UI renders with zero lag
    IncidentFirestoreService.instance.ensureLocalDataLoaded();
    _incidents = IncidentFirestoreService.instance.currentIncidents;
    _isLoading = false;

    // 2. Connect to live Firestore stream and sync in background
    _initIncidents();
  }

  void _initIncidents() {
    _streamSub = IncidentFirestoreService.instance.getIncidentsStream().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _incidents = list;
          _isLoading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      },
    );

    // Sync to Firestore cloud in background
    IncidentFirestoreService.instance.seedRealisticDemoData();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0D12),
          drawer: isDesktop ? null : _buildDrawer(),
          body: Row(
            children: [
              // Desktop Sidebar
              if (isDesktop) _buildSidebar(),

              // Main Dashboard Area
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(isDesktop),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF5E3A),
                              ),
                            )
                          : _buildActiveTabContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isDesktop)
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              const Icon(Icons.shield_rounded, color: Color(0xFFFF5E3A), size: 24),
              const SizedBox(width: 10),
              Text(
                'MotoShield Cloud Control',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF00E676), size: 6),
                    const SizedBox(width: 6),
                    Text(
                      'FIRESTORE ACTIVE',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF00E676),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Row(
            children: [
              // Quick Seed Demo Data Action
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF00E5FF)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await IncidentFirestoreService.instance.seedRealisticDemoData(force: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Re-seeded realistic telemetry & hotspot incident records!'),
                        backgroundColor: Color(0xFF00E5FF),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text('Seed Demo Data', style: GoogleFonts.inter(fontSize: 11)),
              ),

              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5E3A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _handleSwitchToRider,
                icon: const Icon(Icons.phone_android_rounded, size: 14),
                label: Text(
                  'Rider App / Login',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(width: 14),

              // Admin Operator Badge
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: Color(0xFFFF5E3A),
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Admin Operative',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF101216),
        border: Border(right: BorderSide(color: Color(0xFF2C2C2E))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5E3A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.security_rounded, color: Color(0xFFFF5E3A), size: 22),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MOTOSHIELD',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'ADMIN WEB PORTAL',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF8E8E93),
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF2C2C2E), height: 1),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'COMMAND MODULES',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF636366),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          _buildNavItem(0, 'Accident Analytics', Icons.analytics_outlined),
          _buildNavItem(1, 'Live Map & Hotspots', Icons.radar_outlined),
          _buildNavItem(2, 'Incident Reports', Icons.assignment_outlined),
          _buildNavItem(3, 'Insights & Prevention', Icons.insights_outlined),

          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5E3A).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFFFF5E3A),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFFF5E3A), width: 1),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _handleSwitchToRider,
              icon: const Icon(Icons.phone_android_rounded, size: 16),
              label: Text(
                'Open Rider App / Login',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),

          const Spacer(),

          // Telemetry Status Footer
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF141518),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sensors, color: Color(0xFF00E676), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'HELMET TELEMETRY',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF8E8E93),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Crash Threshold: 4.5G\nFailover: Dual Fused',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF101216),
      child: SafeArea(
        child: Column(
          children: [
            _buildNavItem(0, 'Accident Analytics', Icons.analytics_outlined),
            _buildNavItem(1, 'Live Map & Hotspots', Icons.radar_outlined),
            _buildNavItem(2, 'Incident Reports', Icons.assignment_outlined),
            _buildNavItem(3, 'Insights & Prevention', Icons.insights_outlined),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5E3A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _handleSwitchToRider();
                },
                icon: const Icon(Icons.phone_android_rounded, size: 18),
                label: Text(
                  'Open Rider App / Login',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _currentTab == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () {
          setState(() => _currentTab = index);
          if (Scaffold.of(context).isDrawerOpen) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5E3A).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFFFF5E3A).withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFFFF5E3A) : const Color(0xFF8E8E93),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_currentTab) {
      case 0:
        return AdminAnalyticsView(incidents: _incidents);
      case 1:
        return AdminLiveMapView(incidents: _incidents);
      case 2:
        return AdminReportsManagementView(incidents: _incidents);
      case 3:
        return AdminInsightsPreventionView(incidents: _incidents);
      default:
        return AdminAnalyticsView(incidents: _incidents);
    }
  }
}
