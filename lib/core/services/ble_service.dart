import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/history/presentation/screens/history_model.dart';
import '../../features/history/presentation/screens/history_service.dart';
import '../../features/settings/settings_model.dart';
import '../../features/settings/settings_service.dart';
import 'in_app_notification_service.dart';
import 'notification_service.dart';

/// Real-time data received from the MotoShield.
class HelmetTelemetry {
  final bool connected;
  final int? battery;
  final double? latitude;
  final double? longitude;
  final int? satellites;
  final bool gpsFix;
  final double? acceleration;
  final bool crashDetected;
  final bool sosActive;
  final String status;
  final DateTime timestamp;

  const HelmetTelemetry({
    this.connected = false,
    this.battery,
    this.latitude,
    this.longitude,
    this.satellites,
    this.gpsFix = false,
    this.acceleration,
    this.crashDetected = false,
    this.sosActive = false,
    this.status = 'DISCONNECTED',
    required this.timestamp,
  });

  HelmetTelemetry copyWith({
    bool? connected,
    int? battery,
    double? latitude,
    double? longitude,
    int? satellites,
    bool? gpsFix,
    double? acceleration,
    bool? crashDetected,
    bool? sosActive,
    String? status,
  }) {
    return HelmetTelemetry(
      connected: connected ?? this.connected,
      battery: battery ?? this.battery,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      satellites: satellites ?? this.satellites,
      gpsFix: gpsFix ?? this.gpsFix,
      acceleration: acceleration ?? this.acceleration,
      crashDetected: crashDetected ?? this.crashDetected,
      sosActive: sosActive ?? this.sosActive,
      status: status ?? this.status,
      timestamp: DateTime.now(),
    );
  }
}

class BleService {
  BleService._();

  static final BleService instance = BleService._();

  // ============================================================
  // SMART SOS HELMET BLE UUIDs
  // ============================================================

  static const String serviceUuid = '12345678-1234-1234-1234-1234567890AB';
  static const String fallbackServiceUuid = '4FAFC201-1FB5-459E-8FCC-C5C9C331914B';

  static const String characteristicUuid =
      '12345678-1234-1234-1234-1234567890AC';
  static const String fallbackCharacteristicUuid =
      'BEB5483E-36E1-4688-B7F5-EA07361B26A8';

  // ============================================================
  // BLE STATE
  // ============================================================

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _helmetCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;

  // ============================================================
  // STREAMS
  // ============================================================

  final StreamController<HelmetTelemetry> _telemetryController =
      StreamController<HelmetTelemetry>.broadcast();

  final StreamController<BluetoothConnectionState> _connectionController =
      StreamController<BluetoothConnectionState>.broadcast();

  final StreamController<String> _eventController =
      StreamController<String>.broadcast();

  Stream<HelmetTelemetry> get telemetry => _telemetryController.stream;

  Stream<BluetoothConnectionState> get connectionState =>
      _connectionController.stream;

  Stream<String> get events => _eventController.stream;

  // ============================================================
  // CURRENT DATA
  // ============================================================

  HelmetTelemetry _currentTelemetry = HelmetTelemetry(
    timestamp: DateTime.now(),
  );

  HelmetTelemetry get currentTelemetry => _currentTelemetry;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  bool get isConnected =>
      _connectedDevice != null && _currentTelemetry.connected;

  // ============================================================
  // BLUETOOTH AVAILABILITY
  // ============================================================

  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // SCAN
  // ============================================================

  Future<List<ScanResult>> scanForHelmet({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final results = <ScanResult>[];

    if (!await isBluetoothAvailable()) {
      return results;
    }

    await stopScan();

    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((scanResults) {
        for (final result in scanResults) {
          final name = result.device.platformName.toUpperCase();

          final isHelmet =
              name.contains('SMART SOS') ||
              name.contains('SMARTSOS') ||
              name.contains('SOS HELMET') ||
              name.contains('ESP32') ||
              name.contains('HELMET');

          if (isHelmet) {
            final alreadyAdded = results.any(
              (item) => item.device.remoteId == result.device.remoteId,
            );

            if (!alreadyAdded) {
              results.add(result);
            }
          }
        }
      }, onError: (_) {});

      await FlutterBluePlus.startScan(timeout: timeout);

      await Future.delayed(timeout);
    } catch (_) {
      // Ignore scan errors.
    }

    await stopScan();

    return results;
  }

  Stream<ScanResult> get scanStream {
    return FlutterBluePlus.scanResults.expand((results) => results);
  }

  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // ============================================================
  // CONNECT
  // ============================================================

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await disconnect();

      _connectedDevice = device;

      _currentTelemetry = HelmetTelemetry(
        connected: false,
        status: 'CONNECTING',
        timestamp: DateTime.now(),
      );

      _emitTelemetry();

      // Listen to connection changes.
      _connectionSubscription = device.connectionState.listen((state) {
        _connectionController.add(state);

        if (state == BluetoothConnectionState.connected) {
          _currentTelemetry = _currentTelemetry.copyWith(
            connected: true,
            status: 'CONNECTED',
          );

          _emitTelemetry();
          _eventController.add('HELMET_CONNECTED');
          NotificationService.instance.showHelmetConnectedNotification();
          InAppNotificationService.instance.addNotification(
            title: 'HELMET CONNECTED',
            message: 'ESP32 Helmet Transceiver paired successfully.',
            icon: Icons.bluetooth_connected_rounded,
            accentColor: const Color(0xFF30D158),
          );
          HistoryService.recordEvent(
            type: HistoryEventType.helmetConnected,
            status: 'BLUETOOTH LINK OK',
            details: 'ESP32 Helmet Transceiver paired successfully.',
            latitude: _currentTelemetry.latitude,
            longitude: _currentTelemetry.longitude,
          );
          HistoryService.recordEvent(
            type: HistoryEventType.ridingSession,
            status: 'SESSION ACTIVE',
            details: 'Riding session started with ESP32 Smart Helmet.',
            latitude: _currentTelemetry.latitude,
            longitude: _currentTelemetry.longitude,
          );
          syncSavedSettingsToEsp32();
        }

        if (state == BluetoothConnectionState.disconnected) {
          _currentTelemetry = HelmetTelemetry(
            connected: false,
            status: 'DISCONNECTED',
            timestamp: DateTime.now(),
          );

          _emitTelemetry();
          _eventController.add('HELMET_DISCONNECTED');
          NotificationService.instance.showHelmetDisconnectedNotification();
          InAppNotificationService.instance.addNotification(
            title: 'HELMET DISCONNECTED',
            message: 'ESP32 Helmet Transceiver disconnected.',
            icon: Icons.bluetooth_disabled_rounded,
            accentColor: const Color(0xFF8E8E93),
          );
          HistoryService.recordEvent(
            type: HistoryEventType.helmetDisconnected,
            status: 'BLE LINK TERMINATED',
            details: 'ESP32 Helmet Transceiver disconnected.',
          );
          HistoryService.recordEvent(
            type: HistoryEventType.ridingSession,
            status: 'SESSION COMPLETED',
            details: 'Riding session ended.',
          );
        }
      });

      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Discover services.
      final services = await device.discoverServices();

      BluetoothCharacteristic? targetCharacteristic;

      // 1. Try matching preferred UUIDs
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          final cUuid = characteristic.uuid.toString().toUpperCase();
          if (cUuid == characteristicUuid.toUpperCase() ||
              cUuid == fallbackCharacteristicUuid.toUpperCase()) {
            targetCharacteristic = characteristic;
            break;
          }
        }
        if (targetCharacteristic != null) break;
      }

      // 2. Fallback: Find any characteristic with notify or indicate enabled
      if (targetCharacteristic == null) {
        for (final service in services) {
          for (final characteristic in service.characteristics) {
            if (characteristic.properties.notify ||
                characteristic.properties.indicate) {
              targetCharacteristic = characteristic;
              break;
            }
          }
          if (targetCharacteristic != null) break;
        }
      }

      if (targetCharacteristic == null) {
        throw Exception('MotoShield BLE characteristic not found.');
      }

      _helmetCharacteristic = targetCharacteristic;

      // Enable notifications.
      if (targetCharacteristic.properties.notify ||
          targetCharacteristic.properties.indicate) {
        await targetCharacteristic.setNotifyValue(true);

        _notificationSubscription =
            targetCharacteristic.lastValueStream.listen(
          _handleNotification,
          onError: (_) {},
        );
      }

      // Ask ESP32 for current status.
      await sendCommand('STATUS');

      _currentTelemetry = _currentTelemetry.copyWith(
        connected: true,
        status: 'CONNECTED',
      );

      _emitTelemetry();

      _eventController.add('HELMET_READY');

      // Save last connected device for automatic reconnection
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLastDeviceId, device.remoteId.str);
        await prefs.setString(_prefLastDeviceName, device.platformName);
        _autoReconnectEnabled = true;
      } catch (_) {}

      return true;
    } catch (e) {
      _eventController.add('BLE_ERROR:$e');

      _currentTelemetry = HelmetTelemetry(
        connected: false,
        status: 'CONNECTION_FAILED',
        timestamp: DateTime.now(),
      );

      _emitTelemetry();

      await disconnect();

      return false;
    }
  }

  // ============================================================
  // NOTIFICATION HANDLER
  // ============================================================

  void _handleNotification(List<int> value) {
    if (value.isEmpty) return;

    try {
      final message = utf8.decode(value, allowMalformed: true).trim();

      if (message.isEmpty) return;

      // ESP32 may send multiple lines in one notification.
      final messages = message.split(RegExp(r'[\r\n]+'));

      for (final singleMessage in messages) {
        final cleanMessage = singleMessage.trim();

        if (cleanMessage.isEmpty) continue;

        _eventController.add(cleanMessage);

        _parseTelemetry(cleanMessage);
      }
    } catch (_) {
      // Ignore malformed BLE packet.
    }
  }

  // ============================================================
  // TELEMETRY PARSER
  // ============================================================

  void _parseTelemetry(String message) {
    final upperMessage = message.trim().toUpperCase();

    // Check for raw standalone trigger commands
    if (upperMessage == 'SOS' ||
        upperMessage == 'SOS_ACTIVE' ||
        upperMessage == 'SOS_TRIGGERED' ||
        upperMessage == 'SOS_2SEC' ||
        upperMessage == 'SOS_PRESS') {
      if (!_currentTelemetry.sosActive) {
        _currentTelemetry = _currentTelemetry.copyWith(
          sosActive: true,
          status: 'SOS ACTIVE',
        );
        _emitTelemetry();
        _eventController.add('SOS_ACTIVE');
        NotificationService.instance.showSosDispatchedNotification();
        InAppNotificationService.instance.addNotification(
          title: 'SOS DISPATCHED',
          message: 'Emergency SOS distress alert activated.',
          icon: Icons.emergency_rounded,
          accentColor: const Color(0xFFE82127),
          isAlert: true,
        );
        HistoryService.recordEvent(
          type: HistoryEventType.sosTriggered,
          status: 'SOS ACTIVE',
          details: 'Emergency SOS distress alert activated.',
          latitude: _currentTelemetry.latitude,
          longitude: _currentTelemetry.longitude,
        );
      }
      return;
    }

    if (upperMessage == 'CRASH' ||
        upperMessage == 'CRASH_DETECTED' ||
        upperMessage == 'CRASH_ACTIVE') {
      if (!_currentTelemetry.crashDetected) {
        _currentTelemetry = _currentTelemetry.copyWith(
          crashDetected: true,
          status: 'CRASH DETECTED',
        );
        _emitTelemetry();
        _eventController.add('CRASH_DETECTED');
        NotificationService.instance.showCrashNotification();
        InAppNotificationService.instance.addNotification(
          title: 'CRASH DETECTED',
          message: 'Impact G-Force anomaly detected by helmet sensor.',
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFE82127),
          isAlert: true,
        );
        HistoryService.recordEvent(
          type: HistoryEventType.crashDetected,
          status: 'CRASH DETECTED',
          details: 'Impact G-Force anomaly detected by helmet sensor.',
          latitude: _currentTelemetry.latitude,
          longitude: _currentTelemetry.longitude,
        );
      }
      return;
    }

    if (upperMessage == 'SOS_CANCELLED' || upperMessage == 'SOS_CLEARED') {
      if (_currentTelemetry.sosActive || _currentTelemetry.crashDetected) {
        _currentTelemetry = _currentTelemetry.copyWith(
          sosActive: false,
          crashDetected: false,
          status: 'READY',
        );
        _emitTelemetry();
        _eventController.add('SOS_CANCELLED');
        InAppNotificationService.instance.addNotification(
          title: 'SOS CANCELLED',
          message: 'SOS alarm disarmed and resolved cleanly.',
          icon: Icons.cancel_outlined,
          accentColor: const Color(0xFFFF9500),
        );
        HistoryService.recordEvent(
          type: HistoryEventType.sosCancelled,
          status: 'SOS CANCELLED',
          details: 'SOS alarm disarmed and resolved cleanly.',
          latitude: _currentTelemetry.latitude,
          longitude: _currentTelemetry.longitude,
        );
      }
      return;
    }

    final delimiter = message.contains(':') ? ':' : ',';
    final parts = message.split(delimiter);

    if (parts.isEmpty) return;

    final type = parts[0].trim().toUpperCase();

    switch (type) {
      // --------------------------------------------------------
      // STATUS
      // --------------------------------------------------------

      case 'STATUS':
        if (parts.length >= 2) {
          final status = parts[1].trim().toUpperCase();

          if (status == 'CONNECTED' ||
              status == 'READY' ||
              status == 'ONLINE') {
            _currentTelemetry = _currentTelemetry.copyWith(
              connected: true,
              status: status,
            );
          } else {
            _currentTelemetry = _currentTelemetry.copyWith(status: status);
          }

          _emitTelemetry();
        }
        break;

      // --------------------------------------------------------
      // BATTERY
      // --------------------------------------------------------

      case 'BATTERY':
      case 'BAT':
        if (parts.length >= 3) {
          final batteryPct = int.tryParse(parts[2].trim()) ??
              (double.tryParse(parts[2].trim())?.round());

          if (batteryPct != null) {
            final clampedPct = batteryPct.clamp(0, 100);
            if (clampedPct < 15 && (_currentTelemetry.battery == null || _currentTelemetry.battery! >= 15)) {
              NotificationService.instance.showLowBatteryNotification(clampedPct);
            }
            _currentTelemetry = _currentTelemetry.copyWith(
              battery: clampedPct,
            );
            _emitTelemetry();
          }
        } else if (parts.length >= 2) {
          final val = double.tryParse(parts[1].trim());
          if (val != null) {
            int pct;
            if (val <= 5.0) {
              pct = (((val - 3.3) / (4.2 - 3.3)) * 100).round();
            } else {
              pct = val.round();
            }
            final clampedPct = pct.clamp(0, 100);
            if (clampedPct < 15 && (_currentTelemetry.battery == null || _currentTelemetry.battery! >= 15)) {
              NotificationService.instance.showLowBatteryNotification(clampedPct);
            }
            _currentTelemetry = _currentTelemetry.copyWith(
              battery: clampedPct,
            );
            _emitTelemetry();
          }
        }
        break;

      // --------------------------------------------------------
      // GPS & SOSGPS
      // --------------------------------------------------------

      case 'GPS':
      case 'SOSGPS':
        if (parts.length >= 3) {
          final latitude = double.tryParse(parts[1].trim());
          final longitude = double.tryParse(parts[2].trim());

          if (latitude != null && longitude != null) {
            bool fix = true;
            int? satellites;

            if (parts.length >= 4) {
              final thirdParam = parts[3].trim();
              final parsedSat = int.tryParse(thirdParam);
              if (parsedSat != null) {
                satellites = parsedSat;
              } else {
                fix = thirdParam == '1' || thirdParam.toUpperCase() == 'TRUE';
              }
            }

            if (parts.length >= 5) {
              satellites = int.tryParse(parts[4].trim());
            }

            _currentTelemetry = _currentTelemetry.copyWith(
              latitude: latitude,
              longitude: longitude,
              gpsFix: fix,
              satellites: satellites ?? _currentTelemetry.satellites,
            );

            _emitTelemetry();
          }
        }
        break;

      // --------------------------------------------------------
      // ACCELERATION & GFORCE
      // --------------------------------------------------------

      case 'GFORCE':
      case 'ACCEL':
        if (parts.length >= 2) {
          final totalAcceleration = double.tryParse(parts.last.trim());

          if (totalAcceleration != null) {
            _currentTelemetry = _currentTelemetry.copyWith(
              acceleration: totalAcceleration,
            );

            _emitTelemetry();
          }
        }
        break;

      // --------------------------------------------------------
      // CRASH
      // --------------------------------------------------------

      case 'CRASH':
        if (parts.length >= 2) {
          final crashState = parts[1].trim().toUpperCase();

          if (crashState == 'DETECTED' || crashState == 'ACTIVE') {
            _currentTelemetry = _currentTelemetry.copyWith(
              crashDetected: true,
              status: 'CRASH DETECTED',
            );

            _eventController.add('CRASH_DETECTED');
          }

          if (crashState == 'CLEARED' || crashState == 'CANCELLED') {
            _currentTelemetry = _currentTelemetry.copyWith(
              crashDetected: false,
              status: 'READY',
            );
          }

          _emitTelemetry();
        }
        break;

      // --------------------------------------------------------
      // SOS
      // --------------------------------------------------------

      case 'SOS':
        if (parts.length >= 2) {
          final sosState = parts[1].trim().toUpperCase();

          if (sosState == 'ACTIVE' ||
              sosState == 'TRIGGERED' ||
              sosState == 'DISPATCHED') {
            _currentTelemetry = _currentTelemetry.copyWith(
              sosActive: true,
              status: 'SOS ACTIVE',
            );

            _eventController.add('SOS_ACTIVE');
          }

          if (sosState == 'CANCELLED' || sosState == 'CLEARED') {
            _currentTelemetry = _currentTelemetry.copyWith(
              sosActive: false,
              status: 'READY',
            );

            _eventController.add('SOS_CANCELLED');
          }

          _emitTelemetry();
        }
        break;

      // --------------------------------------------------------
      // PING & COUNTDOWN
      // --------------------------------------------------------

      case 'COUNTDOWN':
        if (parts.length >= 2) {
          _eventController.add('COUNTDOWN:${parts[1].trim()}');
        }
        break;

      case 'PING':
        _eventController.add('PONG');
        break;
    }
  }

  // ============================================================
  // SEND COMMAND TO ESP32
  // ============================================================

  Future<bool> sendCommand(String command) async {
    final characteristic = _helmetCharacteristic;

    if (characteristic == null) {
      return false;
    }

    try {
      final data = utf8.encode('$command\n');

      try {
        await characteristic.write(data, withoutResponse: false);
        return true;
      } catch (_) {
        await characteristic.write(data, withoutResponse: true);
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // MANUAL SOS
  // ============================================================

  Future<bool> triggerManualSos() async {
    await sendCommand('SOS,ACTIVE');
    return sendCommand('SOS');
  }

  // ============================================================
  // SYNC APP SETTINGS TO ESP32
  // ============================================================

  Future<bool> sendSettingsToEsp32({
    required bool crashEnabled,
    required double gForceThreshold,
    required int sosDelay,
    bool soundAlerts = true,
    bool vibrationAlerts = true,
    bool autoSos = true,
    bool gpsEnabled = true,
  }) async {
    final res1 = await sendCommand('SET_CRASH_DETECT,${crashEnabled ? 1 : 0}');
    final res2 = await sendCommand(
        'SET_THRESHOLD,${gForceThreshold.toStringAsFixed(1)}');
    final res3 = await sendCommand('SET_SOS_DELAY,$sosDelay');
    final res4 = await sendCommand('SET_BUZZER,${soundAlerts ? 1 : 0}');
    final res5 = await sendCommand('SET_VIB,${vibrationAlerts ? 1 : 0}');
    final res6 = await sendCommand('SET_AUTO_SOS,${autoSos ? 1 : 0}');
    final res7 = await sendCommand('SET_GPS,${gpsEnabled ? 1 : 0}');
    return res1 || res2 || res3 || res4 || res5 || res6 || res7;
  }

  Future<bool> syncSettingsToEsp32(SettingsModel settings) async {
    return sendSettingsToEsp32(
      crashEnabled: settings.crashDetectionEnabled,
      gForceThreshold: settings.crashGForceThreshold,
      sosDelay: settings.sosCountdownSeconds,
      soundAlerts: settings.soundAlertsEnabled,
      vibrationAlerts: settings.vibrationAlertsEnabled,
      autoSos: settings.automaticSosEnabled,
      gpsEnabled: settings.gpsTrackingEnabled,
    );
  }

  Future<bool> syncSavedSettingsToEsp32() async {
    final settings = await SettingsService().loadSettings();
    return syncSettingsToEsp32(settings);
  }

  // ============================================================
  // CANCEL SOS
  // ============================================================

  void resetSosState({bool logCancelled = true}) {
    final wasActive = _currentTelemetry.sosActive || _currentTelemetry.crashDetected;
    _currentTelemetry = _currentTelemetry.copyWith(
      sosActive: false,
      crashDetected: false,
      status: 'READY',
    );
    _emitTelemetry();
    _eventController.add('SOS_CANCELLED');
    if (wasActive && logCancelled) {
      InAppNotificationService.instance.addNotification(
        title: 'SOS CANCELLED',
        message: 'SOS alarm disarmed and resolved cleanly.',
        icon: Icons.cancel_outlined,
        accentColor: const Color(0xFFFF9500),
      );
      HistoryService.recordEvent(
        type: HistoryEventType.sosCancelled,
        status: 'SOS CANCELLED',
        details: 'SOS distress alarm disarmed and resolved cleanly.',
        latitude: _currentTelemetry.latitude,
        longitude: _currentTelemetry.longitude,
      );
    }
  }

  Future<bool> cancelSos({bool logCancelled = true}) async {
    resetSosState(logCancelled: logCancelled);
    return sendCommand('CANCEL');
  }

  // ============================================================
  // STATUS REQUEST
  // ============================================================

  Future<bool> requestStatus() async {
    return sendCommand('STATUS');
  }

  // ============================================================
  // EMIT TELEMETRY
  // ============================================================

  void _emitTelemetry() {
    if (!_telemetryController.isClosed) {
      _telemetryController.add(_currentTelemetry);
    }
  }

  // ============================================================
  // AUTO RECONNECT ENGINE
  // ============================================================

  Timer? _autoReconnectTimer;
  bool _isAutoConnecting = false;
  bool _autoReconnectEnabled = true;

  static const String _prefLastDeviceId = 'last_helmet_device_id';
  static const String _prefLastDeviceName = 'last_helmet_device_name';

  void initAutoReconnect() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (isConnected || _isAutoConnecting || !_autoReconnectEnabled) {
        return;
      }

      if (!await isBluetoothAvailable()) {
        return;
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final lastDeviceId = prefs.getString(_prefLastDeviceId);
        final lastDeviceName = prefs.getString(_prefLastDeviceName);

        if (lastDeviceId == null || lastDeviceId.isEmpty) {
          return;
        }

        _isAutoConnecting = true;

        final results = await scanForHelmet(timeout: const Duration(seconds: 3));

        BluetoothDevice? targetDevice;
        for (final result in results) {
          final devId = result.device.remoteId.str;
          final name = result.device.platformName.toUpperCase();

          if (devId == lastDeviceId ||
              (lastDeviceName != null && result.device.platformName == lastDeviceName) ||
              name.contains('HELMET') ||
              name.contains('SMART SOS') ||
              name.contains('ESP32')) {
            targetDevice = result.device;
            break;
          }
        }

        if (targetDevice != null) {
          _eventController.add('AUTO_RECONNECTING');
          await connect(targetDevice);
        }
      } catch (_) {
        // Silently retry next interval
      } finally {
        _isAutoConnecting = false;
      }
    });
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> disconnect({bool isUserAction = false}) async {
    if (isUserAction) {
      _autoReconnectEnabled = false;
    }

    await _notificationSubscription?.cancel();
    _notificationSubscription = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    try {
      if (_helmetCharacteristic != null) {
        await _helmetCharacteristic!.setNotifyValue(false);
      }
    } catch (_) {}

    _helmetCharacteristic = null;

    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}

    _connectedDevice = null;

    _currentTelemetry = HelmetTelemetry(
      connected: false,
      status: 'DISCONNECTED',
      timestamp: DateTime.now(),
    );

    _emitTelemetry();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;

    await disconnect();
    await stopScan();

    await _telemetryController.close();
    await _connectionController.close();
    await _eventController.close();
  }
}
