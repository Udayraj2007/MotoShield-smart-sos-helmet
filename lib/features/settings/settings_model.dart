import 'dart:convert';

class SettingsModel {
  // Helmet Settings
  final bool isBleConnected;
  final String deviceName;
  final int batteryLevel; // -1 indicates telemetry unavailable

  // Crash Detection Settings
  final bool crashDetectionEnabled;
  final double crashGForceThreshold;
  final int sosCountdownSeconds; // 3, 5, 10, or 15

  // SOS Alert Settings
  final bool automaticSosEnabled;
  final bool autoEmergencyCallEnabled;
  final String sosAlertMethod; // 'SMS', 'Phone Call', 'SMS + Call'
  final bool emergencyAlertConfirmation;

  // Cloud Emergency Voice Gateway Configuration
  final String twilioAccountSid;
  final String twilioAuthToken;
  final String twilioFromNumber;
  final String backendVoiceUrl; // Secure backend URL endpoint

  // Location Settings
  final bool gpsTrackingEnabled;
  final bool locationSharingEnabled;
  final String locationAccuracy; // 'High', 'Balanced', 'Battery Saving'

  // Alerts & Notifications
  final bool notifySosAlerts;
  final bool notifyCrashDetection;
  final bool notifyHelmetConnection;
  final bool notifyLowBattery;

  // Sound & Vibration Feedback
  final bool soundAlertsEnabled;
  final bool vibrationAlertsEnabled;
  final bool voiceAlertsEnabled;

  // Riding Mode
  final bool autoStartRidingSession;
  final bool automaticRideHistory;
  final bool ridingSessionTracking;

  const SettingsModel({
    this.isBleConnected = true,
    this.deviceName = 'MotoShield',
    this.batteryLevel = 87,
    this.crashDetectionEnabled = true,
    this.crashGForceThreshold = 4.5,
    this.sosCountdownSeconds = 5,
    this.automaticSosEnabled = true,
    this.autoEmergencyCallEnabled = true,
    this.sosAlertMethod = 'SMS + Call',
    this.emergencyAlertConfirmation = true,
    this.twilioAccountSid = '',
    this.twilioAuthToken = '',
    this.twilioFromNumber = '',
    this.backendVoiceUrl = '',
    this.gpsTrackingEnabled = true,
    this.locationSharingEnabled = true,
    this.locationAccuracy = 'High',
    this.notifySosAlerts = true,
    this.notifyCrashDetection = true,
    this.notifyHelmetConnection = true,
    this.notifyLowBattery = true,
    this.soundAlertsEnabled = true,
    this.vibrationAlertsEnabled = true,
    this.voiceAlertsEnabled = false,
    this.autoStartRidingSession = true,
    this.automaticRideHistory = true,
    this.ridingSessionTracking = true,
  });

  factory SettingsModel.defaults() => const SettingsModel();

  SettingsModel copyWith({
    bool? isBleConnected,
    String? deviceName,
    int? batteryLevel,
    bool? crashDetectionEnabled,
    double? crashGForceThreshold,
    int? sosCountdownSeconds,
    bool? automaticSosEnabled,
    bool? autoEmergencyCallEnabled,
    String? sosAlertMethod,
    bool? emergencyAlertConfirmation,
    String? twilioAccountSid,
    String? twilioAuthToken,
    String? twilioFromNumber,
    String? backendVoiceUrl,
    bool? gpsTrackingEnabled,
    bool? locationSharingEnabled,
    String? locationAccuracy,
    bool? notifySosAlerts,
    bool? notifyCrashDetection,
    bool? notifyHelmetConnection,
    bool? notifyLowBattery,
    bool? soundAlertsEnabled,
    bool? vibrationAlertsEnabled,
    bool? voiceAlertsEnabled,
    bool? autoStartRidingSession,
    bool? automaticRideHistory,
    bool? ridingSessionTracking,
  }) {
    return SettingsModel(
      isBleConnected: isBleConnected ?? this.isBleConnected,
      deviceName: deviceName ?? this.deviceName,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      crashDetectionEnabled:
          crashDetectionEnabled ?? this.crashDetectionEnabled,
      crashGForceThreshold: crashGForceThreshold ?? this.crashGForceThreshold,
      sosCountdownSeconds: sosCountdownSeconds ?? this.sosCountdownSeconds,
      automaticSosEnabled: automaticSosEnabled ?? this.automaticSosEnabled,
      autoEmergencyCallEnabled:
          autoEmergencyCallEnabled ?? this.autoEmergencyCallEnabled,
      sosAlertMethod: sosAlertMethod ?? this.sosAlertMethod,
      emergencyAlertConfirmation:
          emergencyAlertConfirmation ?? this.emergencyAlertConfirmation,
      twilioAccountSid: twilioAccountSid ?? this.twilioAccountSid,
      twilioAuthToken: twilioAuthToken ?? this.twilioAuthToken,
      twilioFromNumber: twilioFromNumber ?? this.twilioFromNumber,
      backendVoiceUrl: backendVoiceUrl ?? this.backendVoiceUrl,
      gpsTrackingEnabled: gpsTrackingEnabled ?? this.gpsTrackingEnabled,
      locationSharingEnabled:
          locationSharingEnabled ?? this.locationSharingEnabled,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      notifySosAlerts: notifySosAlerts ?? this.notifySosAlerts,
      notifyCrashDetection: notifyCrashDetection ?? this.notifyCrashDetection,
      notifyHelmetConnection:
          notifyHelmetConnection ?? this.notifyHelmetConnection,
      notifyLowBattery: notifyLowBattery ?? this.notifyLowBattery,
      soundAlertsEnabled: soundAlertsEnabled ?? this.soundAlertsEnabled,
      vibrationAlertsEnabled:
          vibrationAlertsEnabled ?? this.vibrationAlertsEnabled,
      voiceAlertsEnabled: voiceAlertsEnabled ?? this.voiceAlertsEnabled,
      autoStartRidingSession:
          autoStartRidingSession ?? this.autoStartRidingSession,
      automaticRideHistory: automaticRideHistory ?? this.automaticRideHistory,
      ridingSessionTracking:
          ridingSessionTracking ?? this.ridingSessionTracking,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isBleConnected': isBleConnected,
      'deviceName': deviceName,
      'batteryLevel': batteryLevel,
      'crashDetectionEnabled': crashDetectionEnabled,
      'crashGForceThreshold': crashGForceThreshold,
      'sosCountdownSeconds': sosCountdownSeconds,
      'automaticSosEnabled': automaticSosEnabled,
      'autoEmergencyCallEnabled': autoEmergencyCallEnabled,
      'sosAlertMethod': sosAlertMethod,
      'emergencyAlertConfirmation': emergencyAlertConfirmation,
      'twilioAccountSid': twilioAccountSid,
      'twilioAuthToken': twilioAuthToken,
      'twilioFromNumber': twilioFromNumber,
      'backendVoiceUrl': backendVoiceUrl,
      'gpsTrackingEnabled': gpsTrackingEnabled,
      'locationSharingEnabled': locationSharingEnabled,
      'locationAccuracy': locationAccuracy,
      'notifySosAlerts': notifySosAlerts,
      'notifyCrashDetection': notifyCrashDetection,
      'notifyHelmetConnection': notifyHelmetConnection,
      'notifyLowBattery': notifyLowBattery,
      'soundAlertsEnabled': soundAlertsEnabled,
      'vibrationAlertsEnabled': vibrationAlertsEnabled,
      'voiceAlertsEnabled': voiceAlertsEnabled,
      'autoStartRidingSession': autoStartRidingSession,
      'automaticRideHistory': automaticRideHistory,
      'ridingSessionTracking': ridingSessionTracking,
    };
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      isBleConnected: json['isBleConnected'] as bool? ?? true,
      deviceName: json['deviceName'] as String? ?? 'MotoShield',
      batteryLevel: json['batteryLevel'] as int? ?? 87,
      crashDetectionEnabled: json['crashDetectionEnabled'] as bool? ?? true,
      crashGForceThreshold:
          (json['crashGForceThreshold'] as num?)?.toDouble() ?? 4.5,
      sosCountdownSeconds: json['sosCountdownSeconds'] as int? ?? 5,
      automaticSosEnabled: json['automaticSosEnabled'] as bool? ?? true,
      autoEmergencyCallEnabled:
          json['autoEmergencyCallEnabled'] as bool? ?? true,
      sosAlertMethod: json['sosAlertMethod'] as String? ?? 'SMS + Call',
      emergencyAlertConfirmation:
          json['emergencyAlertConfirmation'] as bool? ?? true,
      twilioAccountSid: json['twilioAccountSid'] as String? ?? '',
      twilioAuthToken: json['twilioAuthToken'] as String? ?? '',
      twilioFromNumber: json['twilioFromNumber'] as String? ?? '',
      backendVoiceUrl: json['backendVoiceUrl'] as String? ?? '',
      gpsTrackingEnabled: json['gpsTrackingEnabled'] as bool? ?? true,
      locationSharingEnabled: json['locationSharingEnabled'] as bool? ?? true,
      locationAccuracy: json['locationAccuracy'] as String? ?? 'High',
      notifySosAlerts: json['notifySosAlerts'] as bool? ?? true,
      notifyCrashDetection: json['notifyCrashDetection'] as bool? ?? true,
      notifyHelmetConnection: json['notifyHelmetConnection'] as bool? ?? true,
      notifyLowBattery: json['notifyLowBattery'] as bool? ?? true,
      soundAlertsEnabled: json['soundAlertsEnabled'] as bool? ?? true,
      vibrationAlertsEnabled: json['vibrationAlertsEnabled'] as bool? ?? true,
      voiceAlertsEnabled: json['voiceAlertsEnabled'] as bool? ?? false,
      autoStartRidingSession: json['autoStartRidingSession'] as bool? ?? true,
      automaticRideHistory: json['automaticRideHistory'] as bool? ?? true,
      ridingSessionTracking: json['ridingSessionTracking'] as bool? ?? true,
    );
  }

  String encodeJson() => jsonEncode(toJson());

  factory SettingsModel.decodeJson(String source) =>
      SettingsModel.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
