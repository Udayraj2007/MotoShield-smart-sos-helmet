import 'package:flutter/material.dart';

enum HistoryEventType {
  crashDetected,
  sosTriggered,
  sosCancelled,
  helmetConnected,
  helmetDisconnected,
  ridingSession,
}

class HistoryModel {
  final String id;
  final HistoryEventType eventType;
  final DateTime dateTime;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String status;
  final String details;

  HistoryModel({
    required this.id,
    required this.eventType,
    required this.dateTime,
    this.latitude,
    this.longitude,
    this.locationName,
    required this.status,
    required this.details,
  });

  String get eventTypeKey {
    switch (eventType) {
      case HistoryEventType.crashDetected:
        return 'crash_detected';
      case HistoryEventType.sosTriggered:
        return 'sos_triggered';
      case HistoryEventType.sosCancelled:
        return 'sos_cancelled';
      case HistoryEventType.helmetConnected:
        return 'helmet_connected';
      case HistoryEventType.helmetDisconnected:
        return 'helmet_disconnected';
      case HistoryEventType.ridingSession:
        return 'riding_session';
    }
  }

  static HistoryEventType parseEventType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'crash_detected':
      case 'crash':
        return HistoryEventType.crashDetected;
      case 'sos_triggered':
      case 'sos':
        return HistoryEventType.sosTriggered;
      case 'sos_cancelled':
      case 'cancelled':
        return HistoryEventType.sosCancelled;
      case 'helmet_connected':
      case 'connected':
        return HistoryEventType.helmetConnected;
      case 'helmet_disconnected':
      case 'disconnected':
        return HistoryEventType.helmetDisconnected;
      case 'riding_session':
      case 'riding':
      default:
        return HistoryEventType.ridingSession;
    }
  }

  String get typeLabel {
    switch (eventType) {
      case HistoryEventType.crashDetected:
        return 'CRASH DETECTED';
      case HistoryEventType.sosTriggered:
        return 'SOS TRIGGERED';
      case HistoryEventType.sosCancelled:
        return 'SOS CANCELLED';
      case HistoryEventType.helmetConnected:
        return 'HELMET CONNECTED';
      case HistoryEventType.helmetDisconnected:
        return 'HELMET DISCONNECTED';
      case HistoryEventType.ridingSession:
        return 'RIDING SESSION';
    }
  }

  Color get accentColor {
    switch (eventType) {
      case HistoryEventType.crashDetected:
      case HistoryEventType.sosTriggered:
        return const Color(0xFFE82127); // Electric Red
      case HistoryEventType.sosCancelled:
        return const Color(0xFFFF9500); // Alert Amber
      case HistoryEventType.helmetConnected:
      case HistoryEventType.ridingSession:
        return const Color(0xFF30D158); // Neon Green
      case HistoryEventType.helmetDisconnected:
        return const Color(0xFF8E8E93); // Industrial Grey
    }
  }

  IconData get icon {
    switch (eventType) {
      case HistoryEventType.crashDetected:
        return Icons.warning_amber_rounded;
      case HistoryEventType.sosTriggered:
        return Icons.emergency_rounded;
      case HistoryEventType.sosCancelled:
        return Icons.cancel_outlined;
      case HistoryEventType.helmetConnected:
        return Icons.bluetooth_connected_rounded;
      case HistoryEventType.helmetDisconnected:
        return Icons.bluetooth_disabled_rounded;
      case HistoryEventType.ridingSession:
        return Icons.two_wheeler_rounded;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventType': eventTypeKey,
      'dateTime': dateTime.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'status': status,
      'details': details,
    };
  }

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      id:
          json['id'] as String? ??
          'evt_${DateTime.now().millisecondsSinceEpoch}',
      eventType: parseEventType(
        json['eventType'] as String? ?? 'riding_session',
      ),
      dateTime:
          DateTime.tryParse(json['dateTime'] as String? ?? '') ??
          DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['locationName'] as String?,
      status: json['status'] as String? ?? 'LOGGED',
      details: json['details'] as String? ?? '',
    );
  }

  HistoryModel copyWith({
    String? id,
    HistoryEventType? eventType,
    DateTime? dateTime,
    double? latitude,
    double? longitude,
    String? locationName,
    String? status,
    String? details,
  }) {
    return HistoryModel(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      dateTime: dateTime ?? this.dateTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      status: status ?? this.status,
      details: details ?? this.details,
    );
  }
}
