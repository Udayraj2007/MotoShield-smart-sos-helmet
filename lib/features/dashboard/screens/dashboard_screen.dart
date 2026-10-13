import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/ble_service.dart';
import '../../../core/services/emergency_voice_service.dart';
import '../../../core/services/in_app_notification_service.dart';
import '../../../core/services/location_fusion_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/models/incident_report_model.dart';
import '../../admin/services/incident_firestore_service.dart';
import '../../ble/screens/ble_pairing_screen.dart';
import '../../contacts/models/contact_model.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../contacts/services/contact_service.dart';
import '../../history/presentation/screens/history_model.dart';
import '../../history/presentation/screens/history_screen.dart';
import '../../history/presentation/screens/history_service.dart';
import '../../settings/settings_screen.dart';
import '../../settings/settings_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../notifications/screens/notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const MethodChannel _smsChannel =
      MethodChannel('com.udayraj.smartsoshelmet/direct_sms');

  int _currentNavIndex = 0;
  late PageController _pageController;

  bool _isSosActive = false;
  int _sosCountdownTotal = 5;
  int _sosCountdown = 5;
  Timer? _sosTimer;

  // Emergency Voice Call State
  EmergencyCallStatus _voiceCallStatus = EmergencyCallStatus.idle;
  String _voiceCallDetails = '';

  // 2-Second Hold SOS Button Progress
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  String? _activeIncidentId;

  // Real-time BLE Telemetry & Location State
  HelmetTelemetry _telemetry = BleService.instance.currentTelemetry;
  StreamSubscription<HelmetTelemetry>? _telemetrySubscription;
  StreamSubscription<String>? _eventSubscription;

  // Hybrid Dual-Redundant Location State (Helmet GPS + Phone GPS)
  FusedLocation? _fusedLocation;
  StreamSubscription<FusedLocation>? _fusedLocationSub;

  String _locationStreet = 'Acquiring GPS Signal...';
  String _locationCity = 'Searching Satellites';

  late AnimationController _pulseController;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: _currentNavIndex);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _listenToBleService();
    _initLocationFusion();
  }

  void _initLocationFusion() {
    LocationFusionService.instance.init();
    _fusedLocation = LocationFusionService.instance.currentLocation;
    if (_fusedLocation != null) {
      _locationStreet = _fusedLocation!.street;
      _locationCity = _fusedLocation!.city;
    }

    _fusedLocationSub =
        LocationFusionService.instance.locationStream.listen((fused) {
      if (!mounted) return;
      setState(() {
        _fusedLocation = fused;
        _locationStreet = fused.street;
        _locationCity = fused.city;
      });
    });
  }

  void _listenToBleService() {
    BleService.instance.initAutoReconnect();
    _telemetry = BleService.instance.currentTelemetry;

    _telemetrySubscription = BleService.instance.telemetry.listen((data) {
      if (!mounted) return;
      setState(() {
        _telemetry = data;
      });

      if (data.sosActive && !_isSosActive) {
        _triggerSosCountdown();
      }

      if (data.latitude != null && data.longitude != null) {
        _updateAddressFromCoords(data.latitude!, data.longitude!);
      }
    });

    _eventSubscription = BleService.instance.events.listen((event) {
      if (!mounted) return;
      if (event == 'SOS_ACTIVE' || event == 'CRASH_DETECTED') {
        if (!_isSosActive) {
          _triggerSosCountdown();
        }
      } else if (event == 'SOS_CANCELLED' || event == 'SOS_CLEARED') {
        _cancelSos(logCancelled: true);
      }
    });
  }


  Future<void> _updateAddressFromCoords(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _locationStreet = p.street?.isNotEmpty == true
              ? p.street!
              : (p.subLocality?.isNotEmpty == true ? p.subLocality! : 'Current Location');

          _locationCity = '${p.locality ?? ""}, ${p.administrativeArea ?? ""} • ${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationCity = '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E';
        });
      }
    }
  }

  // ============================================================
  // USER AVATAR
  // ============================================================

  Widget _buildUserAvatar() {
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;

    if (photoUrl == null || photoUrl.trim().isEmpty) {
      return const ColoredBox(
        color: Color(0xFF252525),
        child: Center(
          child: Icon(
            Icons.person_outline_rounded,
            color: Color(0xFF8E8E93),
            size: 18,
          ),
        ),
      );
    }

    return Image.network(
      photoUrl,
      width: 32,
      height: 32,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: Color(0xFF252525),
          child: Center(
            child: Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF8E8E93),
              size: 18,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _radarController.dispose();
    _sosTimer?.cancel();
    _holdTimer?.cancel();
    _telemetrySubscription?.cancel();
    _eventSubscription?.cancel();
    _fusedLocationSub?.cancel();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (_currentNavIndex == index) return;
    HapticFeedback.lightImpact();

    setState(() {
      _currentNavIndex = index;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  // ============================================================
  // 2-SECOND HOLD SOS LOGIC
  // ============================================================

  void _startHoldSos() {
    _holdTimer?.cancel();
    setState(() {
      _holdProgress = 0.0;
    });

    // 2000 ms total duration, tick every 50 ms (40 steps)
    const stepMs = 50;
    const totalMs = 2000;

    _holdTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _holdProgress += stepMs / totalMs;
      });

      if (_holdProgress >= 1.0) {
        timer.cancel();
        setState(() {
          _holdProgress = 0.0;
        });

        // Trigger manual SOS on ESP32 & launch app SOS Countdown HUD
        BleService.instance.triggerManualSos();
        _triggerSosCountdown();
      }
    });
  }

  void _cancelHoldSos() {
    _holdTimer?.cancel();
    if (mounted && _holdProgress < 1.0) {
      setState(() {
        _holdProgress = 0.0;
      });
    }
  }

  // ============================================================
  // SOS HUD COUNTDOWN
  // ============================================================

  void _triggerSosCountdown() async {
    final settings = await SettingsService().loadSettings();

    if (!mounted) return;

    _activeIncidentId = 'INC-${DateTime.now().millisecondsSinceEpoch}';

    // Broadcast detected event immediately to Firestore & Admin Web Portal
    try {
      final user = FirebaseAuth.instance.currentUser;
      final coords = LocationFusionService.instance.getEffectiveCoords();
      final effectiveLat = coords.lat ?? _telemetry.latitude ?? 28.4595;
      final effectiveLng = coords.lng ?? _telemetry.longitude ?? 77.0266;

      IncidentFirestoreService.instance.recordIncident(
        IncidentReport(
          id: _activeIncidentId!,
          riderId: user?.uid ?? 'RIDER-LOCAL',
          riderName: user?.displayName ?? 'MotoShield Rider',
          riderPhone: user?.phoneNumber ?? '--',
          deviceId: 'MOTO-HELMET-01',
          eventCategory: EventCategory.detectedEvent,
          status: IncidentStatus.unverified,
          timestamp: DateTime.now(),
          latitude: effectiveLat,
          longitude: effectiveLng,
          locationName: _locationStreet.isNotEmpty ? _locationStreet : 'Live Telemetry Location',
          city: _locationCity,
          roadName: _locationStreet.isNotEmpty ? _locationStreet : 'Live Highway Track',
          alertDeliveryStatus: AlertDeliveryStatus.pending,
          alertRecipientsCount: 0,
          gForce: _telemetry.acceleration,
          notes: 'Crash/distress incident detected by MotoShield. SOS countdown active (${settings.sosCountdownSeconds}s).',
        ),
      );
    } catch (_) {}

    setState(() {
      _isSosActive = true;
      _sosCountdownTotal = settings.sosCountdownSeconds; // Default 3s or user setting
      _sosCountdown = _sosCountdownTotal;
      _holdProgress = 0.0;
      _voiceCallStatus = EmergencyCallStatus.idle;
    });

    _sosTimer?.cancel();

    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_sosCountdown > 1) {
        setState(() {
          _sosCountdown--;
        });
      } else {
        timer.cancel();

        setState(() {
          _sosCountdown = 0;
        });

        // Record CRASH DETECTED event in History & In-App Notifications
        HistoryService.recordEvent(
          type: HistoryEventType.crashDetected,
          status: 'CRASH DISPATCHED',
          details: 'Critical crash incident detected by MotoShield. Emergency contacts notified.',
          latitude: _telemetry.latitude,
          longitude: _telemetry.longitude,
        );

        InAppNotificationService.instance.addNotification(
          title: 'CRASH DETECTED',
          message: 'Critical crash incident detected by MotoShield. Emergency contacts notified.',
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFE82127),
          isAlert: true,
        );

        _dispatchEmergencyAlerts();
      }
    });
  }

  void _cancelSos({bool logCancelled = true}) {
    _sosTimer?.cancel();
    BleService.instance.cancelSos(logCancelled: logCancelled);
    EmergencyVoiceService.instance.reset();

    if (mounted) {
      setState(() {
        _isSosActive = false;
        _sosCountdown = _sosCountdownTotal;
        _holdProgress = 0.0;
        _voiceCallStatus = EmergencyCallStatus.idle;
      });

      if (logCancelled) {
        // Record cancelled false alarm to Firestore
        try {
          final user = FirebaseAuth.instance.currentUser;
          final coords = LocationFusionService.instance.getEffectiveCoords();
          final effectiveLat = coords.lat ?? _telemetry.latitude ?? 28.4595;
          final effectiveLng = coords.lng ?? _telemetry.longitude ?? 77.0266;
          final incidentId = _activeIncidentId ?? 'INC-CAN-${DateTime.now().millisecondsSinceEpoch}';

          IncidentFirestoreService.instance.recordIncident(
            IncidentReport(
              id: incidentId,
              riderId: user?.uid ?? 'RIDER-LOCAL',
              riderName: user?.displayName ?? 'MotoShield Rider',
              riderPhone: user?.phoneNumber ?? '--',
              deviceId: 'MOTO-HELMET-01',
              eventCategory: EventCategory.detectedEvent,
              status: IncidentStatus.falseAlarm,
              timestamp: DateTime.now(),
              latitude: effectiveLat,
              longitude: effectiveLng,
              locationName: _locationStreet.isNotEmpty ? _locationStreet : 'Live Location',
              city: _locationCity,
              roadName: _locationStreet.isNotEmpty ? _locationStreet : 'City Road',
              alertDeliveryStatus: AlertDeliveryStatus.cancelledByRider,
              alertRecipientsCount: 0,
              gForce: _telemetry.acceleration,
              notes: 'Rider safely cancelled SOS during countdown (False Alarm).',
            ),
          );
        } catch (_) {}
        _activeIncidentId = null;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SOS ALERT CANCELLED • DISARMED',
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF2C2C2E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ============================================================
  // EMERGENCY SMS & PHONE CALL DISPATCH
  // ============================================================

  Future<void> _dispatchEmergencySms({List<ContactModel>? contacts}) async {
    final list = contacts ?? await ContactService().loadContacts();
    if (list.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No emergency contacts saved. Please add contacts in Contacts screen.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFE82127),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final coords = LocationFusionService.instance.getEffectiveCoords();
    final lat = coords.lat ?? _telemetry.latitude;
    final lng = coords.lng ?? _telemetry.longitude;
    final mapsUrl = await LocationFusionService.instance.getEmergencyMapsUrl();

    final message =
        'EMERGENCY SOS ALERT! MotoShield detected a crash/distress incident. Live Location: $mapsUrl. Please send help immediately!';

    final phoneNumbers = list
        .map((c) => ContactService.normalizePhoneNumber(c.phoneNumber))
        .toList();

    // Log event in History & In-App Notifications
    HistoryService.recordEvent(
      type: HistoryEventType.sosTriggered,
      status: 'SOS DISPATCHED',
      details: 'Emergency SOS alert sent to ${phoneNumbers.length} contact(s). Location: $mapsUrl',
      latitude: lat,
      longitude: lng,
    );
    InAppNotificationService.instance.addNotification(
      title: 'EMERGENCY SOS DISPATCHED',
      message: 'Emergency SOS alert sent to ${phoneNumbers.length} contact(s).',
      icon: Icons.emergency_rounded,
      accentColor: const Color(0xFFE82127),
      isAlert: true,
    );

    // 1. Direct Silent Background SMS via Native SmsManager
    bool backgroundSmsSent = false;
    try {
      final status = await Permission.sms.request();
      if (status.isGranted) {
        for (final phone in phoneNumbers) {
          await _smsChannel.invokeMethod('sendDirectSms', {
            'phone': phone,
            'message': message,
          });
        }
        backgroundSmsSent = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Emergency SOS SMS sent automatically in background to ${phoneNumbers.length} contact(s)!',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: const Color(0xFF34A853),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Direct background SMS error: $e');
    }

    // 2. Fallback: Launch System SMS app if direct background SMS is not allowed
    if (!backgroundSmsSent) {
      final combinedPhones = phoneNumbers.join(',');
      final smsUri = Uri.parse(
          'sms:$combinedPhones?body=${Uri.encodeComponent(message)}');

      try {
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      final singleUri = Uri.parse(
          'sms:${phoneNumbers.first}?body=${Uri.encodeComponent(message)}');
      try {
        await launchUrl(singleUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not launch SMS app: $e');
      }
    }
  }

  void _dispatchEmergencyAlerts() async {
    final contacts = await ContactService().loadContacts();
    final settings = await SettingsService().loadSettings();

    // Broadcast confirmed dispatched SOS incident to Firestore & Admin Web Portal
    try {
      final user = FirebaseAuth.instance.currentUser;
      final coords = LocationFusionService.instance.getEffectiveCoords();
      final effectiveLat = coords.lat ?? _telemetry.latitude ?? 28.4595;
      final effectiveLng = coords.lng ?? _telemetry.longitude ?? 77.0266;
      final incidentId = _activeIncidentId ?? 'INC-${DateTime.now().millisecondsSinceEpoch}';

      IncidentFirestoreService.instance.recordIncident(
        IncidentReport(
          id: incidentId,
          riderId: user?.uid ?? 'RIDER-LOCAL',
          riderName: user?.displayName ?? 'MotoShield Rider',
          riderPhone: user?.phoneNumber ?? (contacts.isNotEmpty ? contacts.first.phoneNumber : '--'),
          deviceId: 'MOTO-HELMET-01',
          eventCategory: EventCategory.confirmedAccident,
          status: IncidentStatus.verified,
          timestamp: DateTime.now(),
          latitude: effectiveLat,
          longitude: effectiveLng,
          locationName: _locationStreet.isNotEmpty ? _locationStreet : 'Live Telemetry Location',
          city: _locationCity,
          roadName: _locationStreet.isNotEmpty ? _locationStreet : 'Live Highway Track',
          alertDeliveryStatus: contacts.isNotEmpty ? AlertDeliveryStatus.delivered : AlertDeliveryStatus.failed,
          alertRecipientsCount: contacts.length,
          gForce: _telemetry.acceleration,
          notes: contacts.isNotEmpty
              ? 'Emergency SOS alert dispatched to ${contacts.length} contact(s).'
              : 'Emergency crash detected. No emergency contacts configured on device.',
        ),
      );
    } catch (_) {}
    _activeIncidentId = null;

    // 1. Direct Silent Background SMS via Native SmsManager / URL launcher
    _dispatchEmergencySms(contacts: contacts);

    // 2. Auto emergency voice call if enabled
    if (contacts.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ No emergency contacts saved! Add contacts in Contacts screen for auto calls.',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFFFF9500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (settings.autoEmergencyCallEnabled && contacts.isNotEmpty) {
      final mapsUrl = await LocationFusionService.instance.getEmergencyMapsUrl();

      EmergencyVoiceService.instance.initiateAutomaticVoiceCall(
        contacts: contacts,
        mapsUrl: mapsUrl,
        onStatusUpdate: (status, details) {
          if (mounted) {
            setState(() {
              _voiceCallStatus = status;
              _voiceCallDetails = details;
            });

            if (status == EmergencyCallStatus.callCompleted ||
                status == EmergencyCallStatus.voiceAlertCompleted ||
                status == EmergencyCallStatus.voiceAlertFailed) {
              Future.delayed(const Duration(milliseconds: 3500), () {
                if (mounted) {
                  _cancelSos(logCancelled: false);
                }
              });
            }
          }
        },
      );
    } else {
      // Cleanly disarm SOS HUD without showing popup dialog window
      _cancelSos(logCancelled: false);
    }
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      extendBody: true,
      appBar: _isSosActive ? null : _buildAppBar(),
      body: _isSosActive ? _buildSosHudOverlay() : _buildPageView(),
      bottomNavigationBar: _isSosActive ? null : _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // PAGE VIEW (SWIPE NAVIGATION BETWEEN TABS)
  // ============================================================

  Widget _buildPageView() {
    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (index) {
        if (_currentNavIndex != index) {
          setState(() {
            _currentNavIndex = index;
          });
        }
      },
      children: [
        _DashboardHomeTabWrapper(child: _buildDashboardBody()),
        const SettingsScreen(showBackButton: false),
        const HistoryScreen(),
        const ContactsScreen(),
      ],
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    final colors = AppColors.of(context);
    String subtitle;
    switch (_currentNavIndex) {
      case 0:
        subtitle = '/ DASHBOARD & TELEMETRY';
        break;
      case 1:
        subtitle = '/ SETTINGS';
        break;
      case 2:
        subtitle = '/ INCIDENT & RIDE LOGS';
        break;
      case 3:
        subtitle = '/ RESCUE MATRIX & SAFETY';
        break;
      default:
        subtitle = '/ DASHBOARD & TELEMETRY';
    }

    return AppBar(
      backgroundColor: colors.scaffoldBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          // Profile Photo Avatar on Top-Left
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Stack(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primaryAccent, width: 1.5),
                  ),
                  child: ClipOval(child: _buildUserAvatar()),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.scaffoldBackground, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'MotoShield',
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: GoogleFonts.jetBrainsMono(
                          color: colors.primaryAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TRANSCEIVER V2.4 ACTIVE',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF00E676),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Notification Bell Button on Top-Right Corner
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Container(
            decoration: BoxDecoration(
              color: colors.innerContainerBackground,
              shape: BoxShape.circle,
              border: Border.all(color: colors.cardBorder),
            ),
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: colors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: InAppNotificationService.instance.hasUnreadNotifier,
                  builder: (context, hasUnread, child) {
                    if (!hasUnread) return const SizedBox.shrink();
                    return Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF7A59),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DASHBOARD BODY
  // ============================================================

  Widget _buildDashboardBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top System Armed & Telemetry Banner
          _buildSubHeaderBar(),
          const SizedBox(height: 14),

          // Circular Ring Hero Card
          _buildHelmetHeroCard(),
          const SizedBox(height: 14),

          // Live Telemetry HUD Row (G-Force & Precision GPS)
          _buildLiveTelemetryHudRow(),
          const SizedBox(height: 14),

          // Emergency Config Matrix (2x2 Grid)
          _buildEmergencyConfigMatrix(),
          const SizedBox(height: 14),

          // Linked Device Transceiver Logs
          _buildLinkedDeviceTransceiverLogs(),
          const SizedBox(height: 14),

          // System Audit Trail
          _buildSystemAuditTrail(),
          const SizedBox(height: 16),

          // Full-width SOS Emergency Button
          _buildSosButtonSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ============================================================
  // SUB-HEADER BAR
  // ============================================================

  Widget _buildSubHeaderBar() {
    final colors = AppColors.of(context);
    final connected = _telemetry.connected;
    final battery = _telemetry.battery;

    final statusColor = connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59);
    final statusBg = statusColor.withValues(alpha: 0.15);
    final statusText = connected ? 'SYSTEM ARMED & SECURE' : 'HELMET DISCONNECTED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: GoogleFonts.jetBrainsMono(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                    color: connected ? colors.primaryAccent : const Color(0xFFFF7A59),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    connected ? 'BLE 5.2 ${battery ?? 0}%' : 'BLE OFFLINE',
                    style: GoogleFonts.jetBrainsMono(
                      color: connected ? colors.primaryAccent : const Color(0xFFFF7A59),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.ssid_chart_rounded,
                color: connected ? colors.primaryAccent : colors.textSecondary,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  connected
                      ? '3D Impact DSP Core Active • Real-time Monitoring'
                      : 'Helmet Not Connected • Connect ESP32 via BLE to start live monitoring',
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO HELMET CARD (HUD CIRCULAR ARC RING)
  // ============================================================

  Widget _buildHelmetHeroCard() {
    final colors = AppColors.of(context);
    final connected = _telemetry.connected;
    final battery = _telemetry.battery;

    final statusColor = connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59);
    final statusText = connected ? 'GYRO SYNCED' : 'HELMET OFFLINE';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BlePairingScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Circular Arc Gauge HUD Frame
            SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Segmented Radar Ring
                  AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: connected ? _radarController.value * 2 * 3.14159 : 0.0,
                        child: CustomPaint(
                          size: const Size(165, 165),
                          painter: RadarArcPainter(),
                        ),
                      );
                    },
                  ),
                  // Inner Glowing Circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.innerContainerBackground,
                      border: Border.all(color: connected ? colors.primaryAccent : colors.cardBorder, width: 2),
                      boxShadow: connected
                          ? [
                              BoxShadow(
                                color: colors.primaryAccent.withValues(alpha: 0.25),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_motorsports_rounded,
                          color: connected ? colors.primaryAccent : colors.textSecondary,
                          size: 42,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: GoogleFonts.jetBrainsMono(
                                color: statusColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Axis OK Pill (Top Left)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.innerContainerBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.cardBorder),
                      ),
                      child: Text(
                        connected ? 'AXIS: OK' : 'AXIS: --',
                        style: GoogleFonts.jetBrainsMono(
                          color: connected ? colors.textSecondary : colors.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // RT Pill (Bottom Right)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: connected
                            ? const Color(0xFF00E676).withValues(alpha: 0.15)
                            : colors.innerContainerBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: connected ? const Color(0xFF00E676) : colors.cardBorder),
                      ),
                      child: Text(
                        connected ? '12ms RT' : 'OFFLINE',
                        style: GoogleFonts.jetBrainsMono(
                          color: connected ? const Color(0xFF00E676) : colors.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Status row inside card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.innerContainerBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'IMPACT ALG',
                        style: GoogleFonts.jetBrainsMono(
                          color: colors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        connected ? 'ALGO-V4' : 'OFFLINE',
                        style: GoogleFonts.spaceGrotesk(
                          color: connected ? colors.primaryAccent : colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: colors.cardBorder),
                  Column(
                    children: [
                      Text(
                        'CRASH SOS',
                        style: GoogleFonts.jetBrainsMono(
                          color: colors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        connected ? 'STANDBY' : 'INACTIVE',
                        style: GoogleFonts.spaceGrotesk(
                          color: connected ? const Color(0xFF00E676) : colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: colors.cardBorder),
                  Column(
                    children: [
                      Text(
                        'BATTERY LIFE',
                        style: GoogleFonts.jetBrainsMono(
                          color: colors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        connected ? '${battery ?? 0}%' : '--',
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIVE TELEMETRY HUD ROW (G-FORCE & PRECISION GPS)
  // ============================================================

  Widget _buildLiveTelemetryHudRow() {
    final colors = AppColors.of(context);
    final connected = _telemetry.connected;
    final sats = _telemetry.satellites ?? 0;
    final accel = _telemetry.acceleration;
    final lat = _telemetry.latitude;
    final lng = _telemetry.longitude;

    return Row(
      children: [
        // G-FORCE CARD
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          color: connected ? colors.primaryAccent : colors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'G-FORCE',
                          style: GoogleFonts.jetBrainsMono(
                            color: colors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      connected ? 'NORMAL' : 'OFFLINE',
                      style: GoogleFonts.jetBrainsMono(
                        color: connected ? const Color(0xFF00E676) : colors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      connected ? (accel != null ? accel.toStringAsFixed(2) : '1.00') : '--',
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'G',
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  connected ? 'Threshold: 4.5G Safe' : 'Connect Helmet',
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 10),
                // 6-Segment Meter
                Row(
                  children: List.generate(6, (index) {
                    final isActive = connected && index < 4;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 3),
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? colors.primaryAccent
                              : colors.innerContainerBackground,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // PRECISION GPS CARD
        Expanded(
          child: Builder(
            builder: (context) {
              final double? effectiveLat = _fusedLocation?.latitude ?? lat;
              final double? effectiveLng = _fusedLocation?.longitude ?? lng;
              final bool hasGpsLock = effectiveLat != null &&
                  effectiveLng != null &&
                  (effectiveLat != 0.0 || effectiveLng != 0.0);

              String satsDisplay;
              String unitLabel;
              String badgeLabel;

              if (_fusedLocation != null) {
                switch (_fusedLocation!.source) {
                  case LocationSourceType.dualFused:
                    satsDisplay = _fusedLocation!.satellites > 0 ? '${_fusedLocation!.satellites}' : 'FUSED';
                    unitLabel = _fusedLocation!.satellites > 0 ? 'SATS' : 'A-GPS';
                    badgeLabel = _fusedLocation!.sourceLabel;
                    break;
                  case LocationSourceType.phoneGps:
                    satsDisplay = 'PHONE';
                    unitLabel = 'A-GPS';
                    badgeLabel = _fusedLocation!.sourceLabel;
                    break;
                  case LocationSourceType.helmetGps:
                    satsDisplay = '${_fusedLocation!.satellites}';
                    unitLabel = 'SATS';
                    badgeLabel = _fusedLocation!.sourceLabel;
                    break;
                  case LocationSourceType.none:
                    satsDisplay = '0';
                    unitLabel = 'SATS';
                    badgeLabel = 'GPS OFFLINE';
                    break;
                }
              } else if (connected && _telemetry.gpsFix && lat != null && lng != null) {
                satsDisplay = '$sats';
                unitLabel = 'SATS';
                badgeLabel = 'HELMET GPS ($sats SATS)';
              } else {
                satsDisplay = '0';
                unitLabel = 'SATS';
                badgeLabel = 'GPS OFFLINE';
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.satellite_alt_rounded,
                              color: hasGpsLock ? colors.primaryAccent : colors.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PRECISION GPS',
                              style: GoogleFonts.jetBrainsMono(
                                color: colors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: hasGpsLock ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          satsDisplay,
                          style: GoogleFonts.spaceGrotesk(
                            color: colors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unitLabel,
                          style: GoogleFonts.spaceGrotesk(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasGpsLock
                          ? '${effectiveLat.toStringAsFixed(4)}° N, ${effectiveLng.toStringAsFixed(4)}° E'
                          : 'No GPS Lock',
                      style: GoogleFonts.jetBrainsMono(
                        color: colors.textSecondary,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (hasGpsLock ? const Color(0xFF00E676) : const Color(0xFFFF7A59)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: hasGpsLock ? const Color(0xFF00E676) : const Color(0xFFFF7A59)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasGpsLock ? Icons.check : Icons.close,
                            color: hasGpsLock ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              badgeLabel,
                              style: GoogleFonts.jetBrainsMono(
                                color: hasGpsLock ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMERGENCY CONFIG MATRIX (2x2 GRID)
  // ============================================================

  Widget _buildEmergencyConfigMatrix() {
    final colors = AppColors.of(context);
    final connected = _telemetry.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EMERGENCY CONFIG MATRIX',
              style: GoogleFonts.jetBrainsMono(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              connected ? '4 Modules Engaged' : '0 Modules Engaged',
              style: GoogleFonts.inter(
                color: connected ? colors.textSecondary : const Color(0xFFFF7A59),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMatrixCard(
              colors: colors,
              icon: Icons.contact_emergency_rounded,
              tag: connected ? '1 / 5' : 'OFFLINE',
              title: 'PRIMARY SOS',
              mainText: connected ? 'Father (+91)' : 'No Helmet',
              subText: connected ? 'Instant SMS & Call' : 'Disarmed',
              onTap: () => _navigateToTab(3),
            ),
            _buildMatrixCard(
              colors: colors,
              icon: Icons.router_rounded,
              tag: connected ? '● Live' : '○ Offline',
              title: 'HARDWARE CORE',
              mainText: connected ? 'ESP32 Online' : 'ESP32 Offline',
              subText: connected ? 'Packet Loss 0.0%' : 'No BLE Link',
              onTap: () => _navigateToTab(1),
            ),
            _buildMatrixCard(
              colors: colors,
              icon: Icons.directions_bike_rounded,
              tag: connected ? 'HIGHWAY' : 'OFF',
              title: 'TRACKING MODE',
              mainText: connected ? '85 km/h Cap' : 'Tracking Off',
              subText: connected ? 'Auto-Threshold Dyn' : 'Connect Helmet',
              onTap: () => _navigateToTab(1),
            ),
            _buildMatrixCard(
              colors: colors,
              icon: Icons.fact_check_rounded,
              tag: connected ? 'PASSED' : 'OFFLINE',
              title: 'SELF-DIAGNOSTIC',
              mainText: connected ? 'Sensors 100%' : 'Sensors Off',
              subText: connected ? 'Tap to run audit' : 'Connect to audit',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      connected
                          ? 'All hardware sensors passed self-diagnostic check.'
                          : 'Helmet disconnected. Connect ESP32 via BLE to run diagnostics.',
                      style: GoogleFonts.inter(),
                    ),
                    backgroundColor: colors.cardBackground,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatrixCard({
    required AppColors colors,
    required IconData icon,
    required String tag,
    required String title,
    required String mainText,
    required String subText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.innerContainerBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF00E5FF), size: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.innerContainerBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF00E5FF),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.jetBrainsMono(
                color: colors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mainText,
              style: GoogleFonts.spaceGrotesk(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subText,
              style: GoogleFonts.inter(
                color: colors.textSecondary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LINKED DEVICE TRANSCEIVER LOGS
  // ============================================================

  Widget _buildLinkedDeviceTransceiverLogs() {
    final colors = AppColors.of(context);
    final connected = _telemetry.connected;
    final deviceName = BleService.instance.connectedDevice?.platformName;
    final displayName = (deviceName != null && deviceName.isNotEmpty) ? deviceName : 'MotoShield';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LINKED DEVICE TRANSCEIVER LOGS',
              style: GoogleFonts.jetBrainsMono(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              connected ? 'Sync #6409' : 'Disconnected',
              style: GoogleFonts.jetBrainsMono(
                color: connected ? colors.textSecondary : const Color(0xFFFF7A59),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildTransceiverCard(
                colors: colors,
                title: displayName,
                subtitle: connected ? 'Transceiver Active • BLE Linked' : 'Transceiver Offline • Tap to pair',
                tag: connected ? 'MCU BOARD V2 (CONNECTED)' : 'DISCONNECTED',
                tagColor: connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
              ),
              const SizedBox(width: 12),
              _buildTransceiverCard(
                colors: colors,
                title: 'Bluetooth Core',
                subtitle: connected ? 'Core Connected Nominal' : 'Core Idle',
                tag: 'SENSOR RIG',
                tagColor: connected ? colors.primaryAccent : colors.textSecondary,
              ),
              const SizedBox(width: 12),
              _buildTransceiverCard(
                colors: colors,
                title: 'G-Force Threshold',
                subtitle: connected ? 'Threshold: 4.5G Active' : 'Threshold Standby',
                tag: 'SETTINGS',
                tagColor: connected ? const Color(0xFF00E676) : colors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransceiverCard({
    required AppColors colors,
    required String title,
    required String subtitle,
    required String tag,
    required Color tagColor,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.memory_rounded,
                color: colors.primaryAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tagColor),
            ),
            child: Text(
              tag,
              style: GoogleFonts.jetBrainsMono(
                color: tagColor,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SYSTEM AUDIT TRAIL
  // ============================================================

  Widget _buildSystemAuditTrail() {
    final colors = AppColors.of(context);
    final connected = _telemetry.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SYSTEM AUDIT TRAIL',
              style: GoogleFonts.jetBrainsMono(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              connected ? 'All Normal' : 'Helmet Offline',
              style: GoogleFonts.inter(
                color: connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      connected ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                      color: connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected ? 'BLE Link Synchronized' : 'BLE Link Disconnected',
                          style: GoogleFonts.spaceGrotesk(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          connected ? 'Packet cycle zero dropped' : 'Waiting for ESP32 connection...',
                          style: GoogleFonts.inter(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    connected ? 'Just now' : 'Offline',
                    style: GoogleFonts.jetBrainsMono(
                      color: colors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Divider(color: colors.cardBorder, height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (connected ? colors.primaryAccent : colors.textSecondary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: connected ? colors.primaryAccent : colors.textSecondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected ? 'Auto-Calibration Completed' : 'Calibration Standby',
                          style: GoogleFonts.spaceGrotesk(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          connected ? '6-Axis Zero-G Reference set' : 'Connect helmet to calibrate',
                          style: GoogleFonts.inter(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    connected ? '10:14 AM' : '--:--',
                    style: GoogleFonts.jetBrainsMono(
                      color: colors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FULL WIDTH EMERGENCY SOS BANNER BUTTON
  // ============================================================

  Widget _buildSosButtonSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFE52E2E), Color(0xFFB31212)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE52E2E).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GestureDetector(
        onTapDown: (_) => _startHoldSos(),
        onTapUp: (_) => _cancelHoldSos(),
        onTapCancel: () => _cancelHoldSos(),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      'SOS',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY SOS',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _holdProgress > 0
                            ? 'HOLDING... ${(_holdProgress * 100).toInt()}%'
                            : 'HOLD 2 SEC TO DISPATCH',
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
            if (_holdProgress > 0.0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _holdProgress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FLOATING PILL BOTTOM NAVIGATION BAR (INSTAGRAM FROSTED GLASS & GESTURE)
  // ============================================================

  Widget _buildBottomNavigationBar() {
    final colors = AppColors.of(context);
    final items = [
      {'icon': Icons.speed_rounded, 'label': 'Home'},
      {'icon': Icons.tune_rounded, 'label': 'Setting'},
      {'icon': Icons.show_chart_rounded, 'label': 'History'},
      {'icon': Icons.shield_rounded, 'label': 'Safety'},
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 62,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.isDark
                    ? const Color(0xFF141924).withValues(alpha: 0.50)
                    : const Color(0xFF1E2634).withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  final pageValue = (_pageController.hasClients &&
                          _pageController.page != null)
                      ? _pageController.page!
                      : _currentNavIndex.toDouble();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final itemWidth = totalWidth / items.length;
                      final bubbleWidth = itemWidth - 8.0;

                      return Stack(
                        children: [
                          // Liquid Water Bubble Sliding Pill Container
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: pageValue),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            builder: (context, animVal, child) {
                              final bubbleLeft = (animVal * itemWidth) + 4.0;
                              return Positioned(
                                left: bubbleLeft.clamp(
                                  0.0,
                                  totalWidth - bubbleWidth,
                                ),
                                top: 0,
                                bottom: 0,
                                width: bubbleWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.isDark
                                        ? const Color(0xFF3B4454)
                                        : const Color(0xFF4C5568),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.25),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (colors.isDark
                                                ? const Color(0xFF3B4454)
                                                : const Color(0xFF4C5568))
                                            .withValues(alpha: 0.45),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          // Tab Items Row
                          Row(
                            children: List.generate(items.length, (index) {
                              final distance = (pageValue - index).abs();
                              final activeProgress =
                                  (1.0 - distance).clamp(0.0, 1.0);
                              final isSelected = activeProgress > 0.5;

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => _navigateToTab(index),
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        items[index]['icon'] as IconData,
                                        color: Color.lerp(
                                          Colors.white.withValues(alpha: 0.60),
                                          Colors.white,
                                          activeProgress,
                                        ),
                                        size: 20,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        items[index]['label'] as String,
                                        style: GoogleFonts.inter(
                                          color: Color.lerp(
                                            Colors.white
                                                .withValues(alpha: 0.60),
                                            Colors.white,
                                            activeProgress,
                                          ),
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SOS HUD OVERLAY (CRITICAL IMPACT OVERRIDE SCREEN - IMAGE 1)
  // ============================================================

  Widget _buildSosHudOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF070B14),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Row(
                children: [
                  GestureDetector(
                    onTap: _cancelSos,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1424),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1B2438)),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency Impact Override',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'SMART SOS HELMET',
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF8A99B5),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ClipOval(
                    child: Container(
                      width: 32,
                      height: 32,
                      color: const Color(0xFF1B2438),
                      child: _buildUserAvatar(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Badges
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE52E2E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CRITICAL CRASH ALERT',
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1424),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1B2438)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sensors_rounded,
                            color: Color(0xFF8A99B5),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'IMU HARDWARE SINK #09',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF8A99B5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Upper Impact Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1424),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1B2438)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFFF7A59),
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'CRITICAL IMPACT DETECTED',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A59).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LEVEL 4 ALARM',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFFFF7A59),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PEAK VECTOR DECELERATION',
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFF8A99B5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '5.8',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'G',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: const Color(0xFFFF7A59),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROTATIONAL DELTA',
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFF8A99B5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '342°/s',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Hero Circular Timer Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1424),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1B2438)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: _sosCountdownTotal > 0
                                  ? (_sosCountdown / _sosCountdownTotal)
                                  : 0.0,
                              strokeWidth: 8,
                              backgroundColor: const Color(0xFF1B2438),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF7A59),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_sosCountdown',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'SECONDS LEFT',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF7A59),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'AUTO-DISPATCHING SOS & RESCUE IN $_sosCountdown SECONDS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'If no cancellation occurs, helmet siren activates & responders are mobilized.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8A99B5),
                        fontSize: 12,
                      ),
                    ),
                    if (_voiceCallStatus != EmergencyCallStatus.idle) ...[
                      const SizedBox(height: 12),
                      _buildVoiceCallStatusBadge(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live Collision Coordinates Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1424),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1B2438)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFF00E5FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LIVE COLLISION COORDINATES',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF8A99B5),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _locationStreet,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _fusedLocation != null
                                ? '$_locationCity • ${_fusedLocation!.sourceLabel}'
                                : '$_locationCity • GPS Lock: ±1.2m',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8A99B5),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Broadcast Protocol Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1424),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1B2438)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cell_tower_rounded,
                        color: Color(0xFF00E676),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AUTOMATED BROADCAST PROTOCOL',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF8A99B5),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, height: 1.3),
                              children: const [
                                TextSpan(text: 'Synthesizing voice call & SMS with live telemetry to '),
                                TextSpan(
                                  text: '5 emergency contacts',
                                  style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ' & local EMS.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              // Cancel Button
              // Action Buttons
              // Cancel Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _cancelSos(logCancelled: true),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1424),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E676),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.black, size: 14),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'I AM OK — CANCEL SOS',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.touch_app_outlined, color: Color(0xFF00E676), size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Call 911 Direct Call Button
              ElevatedButton.icon(
                onPressed: () {
                  final uri = Uri.parse('tel:911');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.call_rounded),
                label: Text(
                  'CALL 911 / RESCUE NOW',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A59),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Medical ID Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.medical_services_outlined, color: Color(0xFF8A99B5), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'RIDER: ALEX CHEN • BLOOD O+ • NO ALLERGIES',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF8A99B5),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'VIEW MED-ID',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF00E5FF),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceCallStatusBadge() {
    if (_voiceCallStatus == EmergencyCallStatus.idle) {
      return const SizedBox.shrink();
    }

    Color color;
    IconData icon;

    switch (_voiceCallStatus) {
      case EmergencyCallStatus.calling:
        color = const Color(0xFFFFCC00);
        icon = Icons.ring_volume_rounded;
        break;
      case EmergencyCallStatus.callConnected:
        color = const Color(0xFF00E676);
        icon = Icons.phone_in_talk_rounded;
        break;
      case EmergencyCallStatus.voiceAlertPlaying:
        color = const Color(0xFF00E5FF);
        icon = Icons.record_voice_over_rounded;
        break;
      case EmergencyCallStatus.voiceAlertCompleted:
        color = const Color(0xFF00E676);
        icon = Icons.check_circle_rounded;
        break;
      case EmergencyCallStatus.voiceAlertFailed:
        color = const Color(0xFFE52E2E);
        icon = Icons.phone_disabled_rounded;
        break;
      case EmergencyCallStatus.callCompleted:
        color = const Color(0xFF00E676);
        icon = Icons.call_end_rounded;
        break;
      default:
        color = Colors.white;
        icon = Icons.phone_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _voiceCallDetails.isNotEmpty
                  ? 'CALL STATUS: ${_voiceCallStatus.label.toUpperCase()} (${_voiceCallDetails.toUpperCase()})'
                  : 'CALL STATUS: ${_voiceCallStatus.label.toUpperCase()}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// RADAR ARC PAINTER FOR HERO CARD
// ================================================================

class RadarArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final Paint cyanPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final Paint trackPaint = Paint()
      ..color = const Color(0xFF1B2438)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, trackPaint);

    // Cyan arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5,
      2.4,
      false,
      cyanPaint,
    );

    // Green arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.2,
      1.8,
      false,
      greenPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardHomeTabWrapper extends StatefulWidget {
  final Widget child;
  const _DashboardHomeTabWrapper({required this.child});

  @override
  State<_DashboardHomeTabWrapper> createState() =>
      _DashboardHomeTabWrapperState();
}

class _DashboardHomeTabWrapperState extends State<_DashboardHomeTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

