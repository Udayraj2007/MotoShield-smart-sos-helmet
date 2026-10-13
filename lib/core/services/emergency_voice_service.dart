import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../../features/contacts/models/contact_model.dart';
import '../../features/contacts/services/contact_service.dart';
import '../../features/settings/settings_service.dart';
import 'ble_service.dart';

enum EmergencyCallStatus {
  idle,
  calling,
  callConnected,
  voiceAlertPlaying,
  voiceAlertCompleted,
  voiceAlertFailed,
  callCompleted,
}

extension EmergencyCallStatusExtension on EmergencyCallStatus {
  String get label {
    switch (this) {
      case EmergencyCallStatus.idle:
        return 'IDLE';
      case EmergencyCallStatus.calling:
        return 'CALLING';
      case EmergencyCallStatus.callConnected:
        return 'CALL CONNECTED';
      case EmergencyCallStatus.voiceAlertPlaying:
        return 'VOICE ALERT PLAYING';
      case EmergencyCallStatus.voiceAlertCompleted:
        return 'VOICE ALERT COMPLETED';
      case EmergencyCallStatus.voiceAlertFailed:
        return 'VOICE ALERT FAILED';
      case EmergencyCallStatus.callCompleted:
        return 'CALL COMPLETED';
    }
  }
}

class EmergencyVoiceService {
  EmergencyVoiceService._();
  static final EmergencyVoiceService instance = EmergencyVoiceService._();

  static const MethodChannel _smsChannel =
      MethodChannel('com.udayraj.smartsoshelmet/direct_sms');

  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  final StreamController<EmergencyCallStatus> _statusController =
      StreamController<EmergencyCallStatus>.broadcast();
  Stream<EmergencyCallStatus> get statusStream => _statusController.stream;

  EmergencyCallStatus _currentStatus = EmergencyCallStatus.idle;
  EmergencyCallStatus get currentStatus => _currentStatus;

  static const String emergencyVoiceMessage =
      "Hello, this is MotoShield. An accident has been detected. The emergency location has been shared. Please provide immediate assistance.";

  String get _backendVoiceUrl {
    final configured = SettingsService.instance.settings.backendVoiceUrl.trim();
    if (configured.isNotEmpty) return configured;
    return const String.fromEnvironment('BACKEND_VOICE_URL', defaultValue: '');
  }

  String get _twilioAccountSid {
    final configured = SettingsService.instance.settings.twilioAccountSid.trim();
    if (configured.isNotEmpty) return configured;
    return const String.fromEnvironment('TWILIO_ACCOUNT_SID', defaultValue: '');
  }

  String get _twilioAuthToken {
    final configured = SettingsService.instance.settings.twilioAuthToken.trim();
    if (configured.isNotEmpty) return configured;
    return const String.fromEnvironment('TWILIO_AUTH_TOKEN', defaultValue: '');
  }

  String get _twilioFromNumber {
    final configured = SettingsService.instance.settings.twilioFromNumber.trim();
    if (configured.isNotEmpty) return configured;
    return const String.fromEnvironment('TWILIO_FROM_NUMBER', defaultValue: '');
  }

  Future<void> _initTts() async {
    if (_ttsInitialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ttsInitialized = true;
    } catch (e) {
      debugPrint("TTS Init Error: $e");
    }
  }

  void _setStatus(EmergencyCallStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }

    // Transmit exact BLE status update to ESP32
    switch (status) {
      case EmergencyCallStatus.calling:
        BleService.instance.sendCommand('STATUS,CALLING');
        break;
      case EmergencyCallStatus.callConnected:
        BleService.instance.sendCommand('STATUS,CALL_CONNECTED');
        break;
      case EmergencyCallStatus.voiceAlertPlaying:
        BleService.instance.sendCommand('STATUS,VOICE_ALERT');
        break;
      case EmergencyCallStatus.voiceAlertCompleted:
        BleService.instance.sendCommand('STATUS,EMERGENCY_COMPLETED');
        reset();
        break;
      case EmergencyCallStatus.voiceAlertFailed:
        BleService.instance.sendCommand('STATUS,VOICE_FAILED');
        reset();
        break;
      case EmergencyCallStatus.callCompleted:
        BleService.instance.sendCommand('STATUS,EMERGENCY_COMPLETED');
        reset();
        break;
      default:
        break;
    }
  }

  /// Initiates automatic voice call sequence starting with the Primary Emergency Contact.
  Future<bool> initiateAutomaticVoiceCall({
    required List<ContactModel> contacts,
    required String mapsUrl,
    Function(EmergencyCallStatus status, String details)? onStatusUpdate,
  }) async {
    if (contacts.isEmpty) {
      _setStatus(EmergencyCallStatus.voiceAlertFailed);
      onStatusUpdate?.call(
        EmergencyCallStatus.voiceAlertFailed,
        "No emergency contacts configured.",
      );
      return false;
    }

    // Sort: Primary contact first, then by priority integer
    final sortedContacts = List<ContactModel>.from(contacts);
    sortedContacts.sort((a, b) {
      if (a.isPrimary && !b.isPrimary) return -1;
      if (!a.isPrimary && b.isPrimary) return 1;
      return a.priority.compareTo(b.priority);
    });

    for (int i = 0; i < sortedContacts.length; i++) {
      final contact = sortedContacts[i];
      final targetPhone =
          ContactService.normalizePhoneNumber(contact.phoneNumber);

      _setStatus(EmergencyCallStatus.calling);
      onStatusUpdate?.call(
        EmergencyCallStatus.calling,
        "Initiating call to ${contact.name} ($targetPhone)...",
      );

      await Future.delayed(const Duration(milliseconds: 800));

      bool callSuccess = false;

      // 1. Try Secure Backend Gateway if configured
      if (_backendVoiceUrl.isNotEmpty) {
        callSuccess = await _makeBackendVoiceCall(
          toPhoneNumber: targetPhone,
          contactName: contact.name,
          mapsUrl: mapsUrl,
          onStatusUpdate: onStatusUpdate,
        );
      }

      // 2. Try Direct Twilio Cloud Voice REST API Gateway if configured
      if (!callSuccess &&
          _twilioAccountSid.isNotEmpty &&
          _twilioAuthToken.isNotEmpty &&
          _twilioFromNumber.isNotEmpty) {
        callSuccess = await _makeTwilioVoiceCall(
          toPhoneNumber: targetPhone,
          contactName: contact.name,
          onStatusUpdate: onStatusUpdate,
        );
      }

      // 3. Fallback to Direct Native Call + Speakerphone + Looped Local TTS Audio Engine
      if (!callSuccess) {
        callSuccess = await _makeDirectNativeVoiceCall(
          targetPhone: targetPhone,
          contactName: contact.name,
          onStatusUpdate: onStatusUpdate,
        );
      }

      if (callSuccess) {
        _setStatus(EmergencyCallStatus.callCompleted);
        onStatusUpdate?.call(
          EmergencyCallStatus.callCompleted,
          "Emergency voice dispatch completed for ${contact.name}.",
        );
        return true;
      } else {
        _setStatus(EmergencyCallStatus.voiceAlertFailed);
        onStatusUpdate?.call(
          EmergencyCallStatus.voiceAlertFailed,
          "Call/Voice dispatch failed for ${contact.name}. Attempting next...",
        );
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    _setStatus(EmergencyCallStatus.voiceAlertFailed);
    onStatusUpdate?.call(
      EmergencyCallStatus.voiceAlertFailed,
      "Emergency call attempts failed for all saved contacts.",
    );
    return false;
  }

  /// Calls secure backend server endpoint (which keeps Twilio secrets safe on backend)
  Future<bool> _makeBackendVoiceCall({
    required String toPhoneNumber,
    required String contactName,
    required String mapsUrl,
    Function(EmergencyCallStatus status, String details)? onStatusUpdate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_backendVoiceUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': toPhoneNumber,
          'contactName': contactName,
          'mapsUrl': mapsUrl,
          'message': emergencyVoiceMessage,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final String? callSid = data['callSid'];

        _setStatus(EmergencyCallStatus.callConnected);
        onStatusUpdate?.call(
          EmergencyCallStatus.callConnected,
          "Call connected to $contactName.",
        );

        _setStatus(EmergencyCallStatus.voiceAlertPlaying);
        onStatusUpdate?.call(
          EmergencyCallStatus.voiceAlertPlaying,
          "Playing automated TwiML voice message...",
        );

        if (callSid != null && callSid.isNotEmpty) {
          await _pollTwilioCallStatus(callSid, onStatusUpdate);
        } else {
          await Future.delayed(const Duration(seconds: 6));
        }

        _setStatus(EmergencyCallStatus.voiceAlertCompleted);
        onStatusUpdate?.call(
          EmergencyCallStatus.voiceAlertCompleted,
          "Automated voice alert completed.",
        );
        return true;
      } else {
        debugPrint("Backend Call Error ${response.statusCode}: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Backend Exception: $e");
      return false;
    }
  }

  /// Makes automated IVR voice call via Twilio REST API with TwiML <Say> tag
  Future<bool> _makeTwilioVoiceCall({
    required String toPhoneNumber,
    required String contactName,
    Function(EmergencyCallStatus status, String details)? onStatusUpdate,
  }) async {
    try {
      final url = Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Calls.json');

      final twiml =
          '<Response><Say language="en-IN" voice="Polly.Aditi">$emergencyVoiceMessage</Say></Response>';

      final authHeader =
          'Basic ${base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'))}';

      final response = await http.post(
        url,
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': toPhoneNumber,
          'From': _twilioFromNumber,
          'Twiml': twiml,
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        final String? callSid = responseData['sid'];

        _setStatus(EmergencyCallStatus.callConnected);
        onStatusUpdate?.call(
          EmergencyCallStatus.callConnected,
          "Call connected to $contactName.",
        );

        _setStatus(EmergencyCallStatus.voiceAlertPlaying);
        onStatusUpdate?.call(
          EmergencyCallStatus.voiceAlertPlaying,
          "Playing automated TwiML voice message...",
        );

        if (callSid != null && callSid.isNotEmpty) {
          await _pollTwilioCallStatus(callSid, onStatusUpdate);
        } else {
          await Future.delayed(const Duration(seconds: 6));
        }

        _setStatus(EmergencyCallStatus.voiceAlertCompleted);
        onStatusUpdate?.call(
          EmergencyCallStatus.voiceAlertCompleted,
          "Automated voice alert completed.",
        );
        return true;
      } else {
        debugPrint("Twilio API Error ${response.statusCode}: ${response.body}");
        _setStatus(EmergencyCallStatus.voiceAlertFailed);
        onStatusUpdate?.call(
          EmergencyCallStatus.voiceAlertFailed,
          "Twilio Cloud Call Failed (${response.statusCode}).",
        );
        return false;
      }
    } catch (e) {
      debugPrint("Twilio Exception: $e");
      _setStatus(EmergencyCallStatus.voiceAlertFailed);
      onStatusUpdate?.call(
        EmergencyCallStatus.voiceAlertFailed,
        "Twilio Gateway Exception: $e",
      );
      return false;
    }
  }

  /// Polls Twilio Call SID until completed or failed
  Future<void> _pollTwilioCallStatus(
    String callSid,
    Function(EmergencyCallStatus status, String details)? onStatusUpdate,
  ) async {
    final statusUrl = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Calls/$callSid.json');
    final authHeader =
        'Basic ${base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'))}';

    final maxAttempts = 15;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final res = await http.get(statusUrl, headers: {'Authorization': authHeader});
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final String callStatus = data['status'] ?? '';
          if (callStatus == 'in-progress') {
            _setStatus(EmergencyCallStatus.voiceAlertPlaying);
          } else if (callStatus == 'completed') {
            break;
          } else if (callStatus == 'failed' ||
              callStatus == 'busy' ||
              callStatus == 'no-answer' ||
              callStatus == 'canceled') {
            _setStatus(EmergencyCallStatus.voiceAlertFailed);
            break;
          }
        }
      } catch (e) {
        debugPrint("Poll Twilio Error: $e");
      }
    }
  }

  /// Direct Android Native Call via Intent + Speakerphone + Looped Local TTS Audio Fallback
  Future<bool> _makeDirectNativeVoiceCall({
    required String targetPhone,
    required String contactName,
    Function(EmergencyCallStatus status, String details)? onStatusUpdate,
  }) async {
    try {
      await _initTts();

      _setStatus(EmergencyCallStatus.callConnected);
      onStatusUpdate?.call(
        EmergencyCallStatus.callConnected,
        "Connected with $contactName ($targetPhone).",
      );

      await Future.delayed(const Duration(milliseconds: 600));

      try {
        final status = await Permission.phone.request();
        if (!status.isGranted) {
          debugPrint("PHONE permission denied.");
        }
      } catch (e) {
        debugPrint("Phone permission request error: $e");
      }

      try {
        await _smsChannel.invokeMethod('enableSpeakerphone');
      } catch (e) {
        debugPrint("Enable speakerphone error: $e");
      }

      await _smsChannel.invokeMethod('makeDirectCall', {
        'phone': targetPhone,
      });

      _setStatus(EmergencyCallStatus.voiceAlertPlaying);
      onStatusUpdate?.call(
        EmergencyCallStatus.voiceAlertPlaying,
        "Broadcasting automated emergency voice alert...",
      );

      for (int i = 1; i <= 2; i++) {
        if (_currentStatus == EmergencyCallStatus.idle) break;
        await _tts.speak(emergencyVoiceMessage);
        await Future.delayed(const Duration(seconds: 2));
      }

      _setStatus(EmergencyCallStatus.voiceAlertCompleted);
      onStatusUpdate?.call(
        EmergencyCallStatus.voiceAlertCompleted,
        "Voice alert broadcasting completed.",
      );
      return true;
    } catch (e) {
      debugPrint("Direct Native Call Error: $e");
      _setStatus(EmergencyCallStatus.voiceAlertFailed);
      onStatusUpdate?.call(
        EmergencyCallStatus.voiceAlertFailed,
        "Direct Native Call Exception: $e",
      );
      return false;
    }
  }

  /// Stop ongoing speech synthesis or reset status
  Future<void> reset() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _setStatus(EmergencyCallStatus.idle);
  }
}
