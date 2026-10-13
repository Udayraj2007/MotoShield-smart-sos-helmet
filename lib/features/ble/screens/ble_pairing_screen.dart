import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/ble_service.dart';

class BlePairingScreen extends StatefulWidget {
  const BlePairingScreen({super.key});

  @override
  State<BlePairingScreen> createState() => _BlePairingScreenState();
}

class _BlePairingScreenState extends State<BlePairingScreen> {
  final List<ScanResult> _scanResults = [];

  StreamSubscription<ScanResult>? _scanSubscription;
  StreamSubscription<String>? _eventSubscription;
  StreamSubscription<HelmetTelemetry>? _telemetrySubscription;

  bool _isScanning = false;
  String _status = 'Disconnected';
  String _lastEvent = 'No event received';

  @override
  void initState() {
    super.initState();
    _initBleState();
  }

  void _initBleState() {
    final ble = BleService.instance;
    _status = ble.currentTelemetry.connected
        ? 'Connected (${ble.currentTelemetry.status})'
        : 'Disconnected';

    _telemetrySubscription = ble.telemetry.listen((telemetry) {
      if (!mounted) return;
      setState(() {
        _status = telemetry.connected
            ? 'Connected • Battery: ${telemetry.battery ?? "--"}%'
            : telemetry.status;
      });
    });

    _eventSubscription = ble.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _lastEvent = event;
      });

      if (event.contains('CRASH')) {
        _showCrashAlert();
      }
    });
  }

  Future<void> _scanForHelmet() async {
    if (_isScanning) return;

    setState(() {
      _scanResults.clear();
      _isScanning = true;
      _status = 'Scanning...';
    });

    try {
      if (!await BleService.instance.isBluetoothAvailable()) {
        _showMessage('Bluetooth is not supported or powered OFF.');
        return;
      }

      _scanSubscription?.cancel();
      _scanSubscription = BleService.instance.scanStream.listen((result) {
        if (!mounted) return;
        setState(() {
          final alreadyAdded = _scanResults.any(
            (item) => item.device.remoteId == result.device.remoteId,
          );
          if (!alreadyAdded) {
            _scanResults.add(result);
          }
        });
      });

      final results = await BleService.instance.scanForHelmet();
      if (mounted) {
        setState(() {
          for (final res in results) {
            final exists = _scanResults.any(
              (item) => item.device.remoteId == res.device.remoteId,
            );
            if (!exists) _scanResults.add(res);
          }
        });
      }
    } catch (e) {
      _showMessage('BLE scan error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          if (_scanResults.isEmpty) {
            _status = 'No helmet found';
          } else {
            _status = 'Helmet(s) found';
          }
        });
      }
    }
  }

  Future<void> _connectToHelmet(BluetoothDevice device) async {
    try {
      setState(() {
        _status = 'Connecting...';
      });

      final success = await BleService.instance.connect(device);

      if (mounted) {
        if (success) {
          setState(() {
            _status = 'Helmet Connected';
          });
          _showMessage('Successfully connected to MotoShield!');
        } else {
          setState(() {
            _status = 'Connection failed';
          });
          _showMessage('Could not connect to helmet. Check if device is in range.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Connection failed';
        });
      }
      _showMessage('Connection error:\n$e');
    }
  }

  Future<void> _disconnectHelmet() async {
    await BleService.instance.disconnect(isUserAction: true);

    if (!mounted) return;

    setState(() {
      _status = 'Disconnected';
      _lastEvent = 'No event received';
    });
  }

  void _showCrashAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE82127), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE82127),
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CRASH DETECTED',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'The MotoShield has detected a possible crash.',
            style: GoogleFonts.inter(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'ACKNOWLEDGE',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFE82127),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF141414),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _deviceName(ScanResult result) {
    final name = result.device.platformName;

    if (name.isNotEmpty) {
      return name;
    }

    return 'Unknown BLE Device';
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _eventSubscription?.cancel();
    _telemetrySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = BleService.instance.isConnected;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'HELMET CONNECTION',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.3,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatusCard(connected),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanForHelmet,
                  icon: Icon(
                    _isScanning
                        ? Icons.bluetooth_searching_rounded
                        : Icons.search_rounded,
                  ),
                  label: Text(
                    _isScanning ? 'SCANNING...' : 'SCAN FOR HELMET',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE82127),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AVAILABLE DEVICES',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF8E8E93),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: _scanResults.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _scanResults.length,
                        itemBuilder: (context, index) {
                          final result = _scanResults[index];

                          return _buildDeviceCard(result);
                        },
                      ),
              ),

              _buildEventCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool connected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected ? Colors.green : const Color(0xFF2C2C2E),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.green : const Color(0xFF636366),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BLE STATUS',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF8E8E93),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _status,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (connected)
            IconButton(
              onPressed: _disconnectHelmet,
              icon: const Icon(
                Icons.bluetooth_disabled_rounded,
                color: Color(0xFFE82127),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ScanResult result) {
    final device = result.device;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE82127)),
          ),
          child: const Icon(Icons.bluetooth_rounded, color: Color(0xFFE82127)),
        ),
        title: Text(
          _deviceName(result),
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          device.remoteId.str,
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF636366),
            fontSize: 10,
          ),
        ),
        trailing: Text(
          '${result.rssi} dBm',
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF8E8E93),
            fontSize: 10,
          ),
        ),
        onTap: () => _connectToHelmet(device),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_disabled_rounded,
            color: Color(0xFF636366),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No BLE devices found',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap SCAN FOR HELMET when the ESP32 is powered.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF636366),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors_rounded, color: Color(0xFF8E8E93), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'EVENT: $_lastEvent',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF8E8E93),
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
