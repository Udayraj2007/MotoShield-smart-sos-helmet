import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/ble_service.dart';
import '../../core/theme/app_colors.dart';
import '../ble/screens/ble_pairing_screen.dart';
import '../history/presentation/screens/history_model.dart';
import '../history/presentation/screens/history_service.dart';
import 'settings_model.dart';
import 'settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBackButton;

  const SettingsScreen({super.key, this.showBackButton = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  final SettingsService _settingsService = SettingsService();
  final HistoryService _historyService = HistoryService();

  SettingsModel _settings = SettingsModel.defaults();
  bool _isLoading = true;

  StreamSubscription<HelmetTelemetry>? _telemetrySub;
  HelmetTelemetry _telemetry = BleService.instance.currentTelemetry;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _telemetrySub = BleService.instance.telemetry.listen((data) {
      if (mounted) {
        setState(() {
          _telemetry = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final loaded = await _settingsService.loadSettings();

    if (!mounted) return;

    setState(() {
      _settings = loaded;
      _isLoading = false;
    });

    if (BleService.instance.isConnected) {
      BleService.instance.syncSettingsToEsp32(loaded);
    }
  }

  Future<void> _updateSettings(SettingsModel newSettings) async {
    if (!mounted) return;

    setState(() {
      _settings = newSettings;
    });

    await _settingsService.saveSettings(newSettings);

    if (BleService.instance.isConnected) {
      final synced = await BleService.instance.syncSettingsToEsp32(newSettings);
      if (synced) {
        _showSnackBar('Settings updated & synced with ESP32 Transceiver!');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFFE82127)
            : const Color(0xFF141414),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TWILIO DIALOG
  // ---------------------------------------------------------------------------

  void _showTwilioDialog() {
    final colors = AppColors.of(context);
    final sidController =
        TextEditingController(text: _settings.twilioAccountSid);
    final tokenController =
        TextEditingController(text: _settings.twilioAuthToken);
    final fromController =
        TextEditingController(text: _settings.twilioFromNumber);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.cardBorder, width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.cloud_outlined,
                  color: Color(0xFFE82127), size: 24),
              const SizedBox(width: 10),
              Text(
                'Twilio Voice Gateway',
                style: GoogleFonts.spaceGrotesk(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Optional: Enter Twilio credentials for cloud PSTN automated voice calls directly into receiver earpiece.',
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: sidController,
                  style: GoogleFonts.jetBrainsMono(
                      color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Account SID',
                    labelStyle: TextStyle(color: colors.textSecondary),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE82127))),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tokenController,
                  obscureText: true,
                  style: GoogleFonts.jetBrainsMono(
                      color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Auth Token',
                    labelStyle: TextStyle(color: colors.textSecondary),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE82127))),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fromController,
                  style: GoogleFonts.jetBrainsMono(
                      color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Twilio Phone Number (e.g. +18005550199)',
                    labelStyle: TextStyle(color: colors.textSecondary),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE82127))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'CANCEL',
                style:
                    GoogleFonts.jetBrainsMono(color: colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _updateSettings(_settings.copyWith(
                  twilioAccountSid: sidController.text.trim(),
                  twilioAuthToken: tokenController.text.trim(),
                  twilioFromNumber: fromController.text.trim(),
                ));
                Navigator.pop(dialogContext);
                _showSnackBar('Twilio credentials saved successfully');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE82127),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'SAVE',
                style: GoogleFonts.jetBrainsMono(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SAFETY TEST
  // ---------------------------------------------------------------------------

  void _openSafetyTestDialog() {
    final colors = AppColors.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE82127), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.science_rounded,
                color: Color(0xFFE82127),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'TEST MODE',
                style: GoogleFonts.spaceGrotesk(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'This is only a simulation. No emergency message or phone call will be sent.',
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'CANCEL',
                style: GoogleFonts.jetBrainsMono(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _runSimulatedTest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE82127),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'RUN TEST',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runSimulatedTest() async {
    final colors = AppColors.of(context);
    int countdown = 3;

    late StateSetter dialogStateSetter;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogStateSetter = setDialogState;

            return AlertDialog(
              backgroundColor: colors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF30D158), width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF30D158),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SIMULATED TEST ACTIVE',
                    style: GoogleFonts.spaceGrotesk(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.innerContainerBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$countdown',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFFE82127),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    countdown > 0
                        ? 'Simulating crash telemetry impact & SOS delay...'
                        : 'TEST PASSED: Transceiver signal nominal.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        countdown--;

        dialogStateSetter(() {});
      } else {
        timer.cancel();
      }
    });

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) {
      timer.cancel();
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    final event = HistoryModel(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      eventType: HistoryEventType.sosTriggered,
      dateTime: DateTime.now(),
      latitude: 12.9716,
      longitude: 77.5946,
      locationName: 'System Diagnostic Test Mode',
      status: 'Test Passed',
      details: 'Self-diagnostic test passed. No emergency alert dispatched.',
    );

    await _historyService.logEvent(event);

    if (!mounted) return;

    _showSnackBar('SAFETY TEST PASSED • Event recorded in History');
  }

  // ---------------------------------------------------------------------------
  // RESET SETTINGS
  // ---------------------------------------------------------------------------

  void _openResetConfirmationDialog() {
    final colors = AppColors.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.cardBorder, width: 1.5),
          ),
          title: Text(
            'Reset all settings?',
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Your saved preferences will be restored to their default values.',
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'CANCEL',
                style: GoogleFonts.jetBrainsMono(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                final resetObj = await _settingsService.resetSettings();

                if (!mounted) return;

                setState(() {
                  _settings = resetObj;
                });

                _showSnackBar('All settings restored to defaults.');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE82127),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'RESET',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);

    final Widget bodyContent = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFFE82127)),
          )
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(
                      'Configure your helmet, safety and emergency preferences',
                      style: GoogleFonts.inter(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SUB-HEADER BAR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _telemetry.connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _telemetry.connected ? 'LIVE TELEMETRY LINK ACTIVE' : 'TELEMETRY LINK DISCONNECTED',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: _telemetry.connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _telemetry.connected ? 'LATENCY: 14MS' : 'LATENCY: OFFLINE',
                          style: GoogleFonts.jetBrainsMono(
                            color: colors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // HARDWARE MODULE CARD (IMAGE 2)
                    Container(
                      padding: const EdgeInsets.all(16),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'HARDWARE MODULE',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: colors.textSecondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'MotoShield Pro',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: colors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'ESP32 Transceiver v2.4',
                                      style: GoogleFonts.inter(
                                        color: colors.textSecondary,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_telemetry.connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59)).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _telemetry.connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59)),
                                  ),
                                  child: Text(
                                    _telemetry.connected ? '● BLE -58 dBm (Strong)' : '○ BLE DISCONNECTED',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: _telemetry.connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: _telemetry.connected ? ((_telemetry.battery ?? 0) / 100.0) : 0.0,
                                      strokeWidth: 5,
                                      backgroundColor: colors.innerContainerBackground,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _telemetry.connected ? const Color(0xFF00E5FF) : colors.cardBorder,
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _telemetry.connected ? '${_telemetry.battery ?? 0}%' : '0%',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: _telemetry.connected ? colors.textPrimary : colors.textSecondary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Icon(
                                          Icons.bolt,
                                          color: _telemetry.connected ? const Color(0xFF00E5FF) : colors.textSecondary,
                                          size: 10,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                                        children: [
                                          const TextSpan(text: 'POWER RESERVE '),
                                          TextSpan(
                                            text: _telemetry.connected ? 'Nominal (4.12V)' : 'Disconnected',
                                            style: TextStyle(
                                              color: _telemetry.connected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _telemetry.connected ? '~14h ride time remaining' : 'No battery status • Helmet disconnected',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: colors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _telemetry.connected ? 'MPU-6050 Gyro + NEO-6M GPS locked' : 'Connect ESP32 via BLE to sync telemetry',
                                      style: GoogleFonts.inter(
                                        color: colors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    BleService.instance.disconnect();
                                  },
                                  icon: const Icon(Icons.link_off_rounded, size: 16),
                                  label: const Text('Disconnect'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.textSecondary,
                                    side: BorderSide(color: colors.cardBorder),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const BlePairingScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.bluetooth_searching_rounded, size: 16),
                                  label: const Text('Pair Transceiver'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.innerContainerBackground,
                                    foregroundColor: const Color(0xFF00E5FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CRASH & IMPACT ENGINE
                    _buildSectionHeader('CRASH & IMPACT ENGINE', colors),
                    const SizedBox(height: 10),
                    _buildCardWrapper([
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.sensors_rounded,
                        title: 'Crash Detection',
                        subtitle: 'Monitors 3D accelerometer sudden deceleration and impact spikes in real-time.',
                        value: _settings.crashDetectionEnabled,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(crashDetectionEnabled: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSelectorTile<double>(
                        colors: colors,
                        icon: Icons.speed_rounded,
                        title: 'G-Force Sensitivity',
                        subtitle: '4.5 G filters pothole bumps while immediately sensing head impacts.',
                        currentValue: _settings.crashGForceThreshold,
                        options: const [2.0, 2.5, 3.5, 4.5, 6.0],
                        labelBuilder: (val) => '$val G',
                        onSelected: (val) {
                          _updateSettings(
                            _settings.copyWith(crashGForceThreshold: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.screen_rotation_rounded,
                        title: 'Fall & Gyro Tilt Matrix',
                        subtitle: 'Triggers when helmet angle remains stationary beyond 65° tilt for > 8 seconds.',
                        value: true,
                        onChanged: (val) {},
                      ),
                    ], colors),
                    const SizedBox(height: 24),

                    // SOS ALERT
                    _buildSectionHeader('SOS ALERT', colors),
                    const SizedBox(height: 10),
                    _buildCardWrapper([
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.warning_amber_rounded,
                        title: 'Automatic SOS',
                        subtitle:
                            'Auto-dispatches alerts upon crash expiration',
                        value: _settings.automaticSosEnabled,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(automaticSosEnabled: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSelectorTile<int>(
                        colors: colors,
                        icon: Icons.timer_rounded,
                        title: 'SOS Countdown Duration',
                        subtitle:
                            'Time window before emergency alert dispatches',
                        currentValue: _settings.sosCountdownSeconds,
                        options: const [3, 5, 10, 15, 20, 30],
                        labelBuilder: (val) => '$val sec',
                        onSelected: (val) {
                          _updateSettings(
                            _settings.copyWith(sosCountdownSeconds: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.phone_in_talk_rounded,
                        title: 'Automatic Emergency Voice Call',
                        subtitle:
                            'Autocalls Primary Contact with Voice Synthesis on Crash',
                        value: _settings.autoEmergencyCallEnabled,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(autoEmergencyCallEnabled: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildTile(
                        colors: colors,
                        icon: Icons.cloud_outlined,
                        title: 'Twilio Cloud Voice Gateway',
                        subtitle: _settings.twilioAccountSid.isNotEmpty
                            ? 'Configured (${_settings.twilioAccountSid.substring(0, 6)}...)'
                            : 'Optional: Leave empty for default direct calling (No setup required)',
                        trailingText: _settings.twilioAccountSid.isNotEmpty
                            ? 'ACTIVE'
                            : 'OPTIONAL',
                        onTap: _showTwilioDialog,
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSelectorTile<String>(
                        colors: colors,
                        icon: Icons.send_rounded,
                        title: 'SOS Alert Method',
                        subtitle: 'Primary emergency dispatch channel',
                        currentValue: _settings.sosAlertMethod,
                        options: const ['SMS', 'Phone Call', 'SMS + Call'],
                        labelBuilder: (val) => val,
                        onSelected: (val) {
                          _updateSettings(
                            _settings.copyWith(sosAlertMethod: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.touch_app_outlined,
                        title: 'Emergency Alert Confirmation',
                        subtitle:
                            'Requires manual confirm before alert disarms',
                        value: _settings.emergencyAlertConfirmation,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(emergencyAlertConfirmation: val),
                          );
                        },
                      ),
                    ], colors),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Automatic SOS alerts are sent after the configured crash countdown expires.',
                        style: GoogleFonts.inter(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // LOCATION
                    _buildSectionHeader('LOCATION', colors),
                    const SizedBox(height: 10),
                    _buildCardWrapper([
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.gps_fixed_rounded,
                        title: 'GPS Tracking',
                        subtitle: 'Hardware GPS sensor coordinate acquisition',
                        value: _settings.gpsTrackingEnabled,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(gpsTrackingEnabled: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.share_location_rounded,
                        title: 'Location Sharing',
                        subtitle:
                            'Include pin-point coordinates in SOS payload',
                        value: _settings.locationSharingEnabled,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(locationSharingEnabled: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSelectorTile<String>(
                        colors: colors,
                        icon: Icons.my_location_rounded,
                        title: 'Location Accuracy',
                        subtitle: 'Power consumption vs precision balance',
                        currentValue: _settings.locationAccuracy,
                        options: const ['High', 'Balanced', 'Battery Saving'],
                        labelBuilder: (val) => val,
                        onSelected: (val) {
                          _updateSettings(
                            _settings.copyWith(locationAccuracy: val),
                          );
                        },
                      ),
                    ], colors),
                    const SizedBox(height: 24),

                    // ALERTS
                    _buildSectionHeader('ALERTS & NOTIFICATIONS', colors),
                    const SizedBox(height: 10),
                    _buildCardWrapper([
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.notifications_active_rounded,
                        title: 'SOS Notifications',
                        subtitle: 'Push notifications for distress events',
                        value: _settings.notifySosAlerts,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(notifySosAlerts: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.my_location_rounded,
                        title: 'Crash Detection Notifications',
                        subtitle:
                            'Real-time alert on impact threshold crossing',
                        value: _settings.notifyCrashDetection,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(notifyCrashDetection: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.bluetooth_connected_rounded,
                        title: 'Helmet Connection Notifications',
                        subtitle: 'Alert on BLE transceiver attach / detach',
                        value: _settings.notifyHelmetConnection,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(notifyHelmetConnection: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.battery_alert_rounded,
                        title: 'Low Battery Notifications',
                        subtitle: 'Notify when helmet battery drops under 15%',
                        value: _settings.notifyLowBattery,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(notifyLowBattery: val),
                          );
                        },
                      ),
                    ], colors),
                    const SizedBox(height: 24),

                    // ALERT FEEDBACK
                    _buildSectionHeader('ALERT FEEDBACK', colors),
                    const SizedBox(height: 10),
                    _buildCardWrapper([
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.volume_up_rounded,
                        title: 'Buzzer / Sound Alerts',
                        subtitle: 'High-decibel acoustic siren tone',
                        value: _settings.soundAlertsEnabled,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(soundAlertsEnabled: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.vibration_rounded,
                        title: 'Vibration',
                        subtitle: 'Haptic feedback on smartphone & helmet',
                        value: _settings.vibrationAlertsEnabled,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(vibrationAlertsEnabled: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.record_voice_over_rounded,
                        title: 'Voice Alerts',
                        subtitle: 'Audible speech synthesis guidance',
                        value: _settings.voiceAlertsEnabled,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(voiceAlertsEnabled: val),
                          );
                        },
                      ),
                    ], colors),
                    const SizedBox(height: 24),

                    // RIDING MODE
                    _buildSectionHeader('RIDING MODE', colors),
                    const SizedBox(height: 10),
                    _buildCardWrapper([
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.directions_bike_rounded,
                        title: 'Auto Start Riding Session',
                        subtitle:
                            'Initiate telemetry logging when motion is detected',
                        value: _settings.autoStartRidingSession,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(autoStartRidingSession: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.history_edu_rounded,
                        title: 'Automatic Ride History',
                        subtitle: 'Record telemetry & incident logs to history',
                        value: _settings.automaticRideHistory,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(automaticRideHistory: val),
                          );
                        },
                      ),
                      Divider(color: colors.cardBorder, height: 1),
                      _buildSwitchTile(
                        colors: colors,
                        icon: Icons.timeline_rounded,
                        title: 'Riding Session Tracking',
                        subtitle:
                            'Keep session analytics & peak g-force active',
                        value: _settings.ridingSessionTracking,
                        onChanged: (val) {
                          _updateSettings(
                            _settings.copyWith(ridingSessionTracking: val),
                          );
                        },
                      ),
                    ], colors),
                    const SizedBox(height: 24),

                    // SAFETY TEST
                    _buildSectionHeader('SAFETY TEST', colors),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SOS Alert Diagnostic',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Verify countdown timer & disarm sequence',
                                  style: GoogleFonts.inter(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _openSafetyTestDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE82127),
                              side: const BorderSide(color: Color(0xFFE82127)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              'Test SOS Alert',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // RESET
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _openResetConfirmationDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE82127),
                          side: const BorderSide(
                            color: Color(0xFFE82127),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Reset All Settings',
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFFE82127),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );

    if (widget.showBackButton) {
      return Scaffold(
        backgroundColor: colors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: colors.scaffoldBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: true,
          title: Text(
            'Settings',
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: SafeArea(child: bodyContent),
      );
    }

    return bodyContent;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title, AppColors colors) {
    return Text(
      title,
      style: GoogleFonts.jetBrainsMono(
        color: colors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCardWrapper(List<Widget> children, AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder, width: 1.2),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    String? trailingText,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.innerContainerBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.textPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: subtitleColor ?? colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: GoogleFonts.jetBrainsMono(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (trailing != null)
              trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.innerContainerBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colors.textPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFFFF5E3A),
            activeTrackColor: const Color(0xFFFF5E3A).withValues(alpha: 0.4),
            inactiveThumbColor: colors.textSecondary,
            inactiveTrackColor: colors.cardBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTile<T>({
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required T currentValue,
    required List<T> options,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.innerContainerBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.textPrimary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: options.map((opt) {
              final isSelected = opt == currentValue;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onSelected(opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE82127)
                            : colors.innerContainerBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFE82127)
                              : colors.cardBorder,
                        ),
                      ),
                      child: Text(
                        labelBuilder(opt),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jetBrainsMono(
                          color: isSelected ? Colors.white : colors.textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
