import 'package:cloud_firestore/cloud_firestore.dart';

/// The core distinction requested for MotoShield incidents:
/// 1. Detected event: Helmet ne possible crash detect kiya (sensors / telemetry).
/// 2. Confirmed accident: Incident ko reliable evidence ya verification se confirm kiya gaya.
/// 3. Reported accident: Kisi user ya external source ne accident report kiya.
enum EventCategory {
  detectedEvent,
  confirmedAccident,
  reportedAccident;

  String get label {
    switch (this) {
      case EventCategory.detectedEvent:
        return 'Detected Event';
      case EventCategory.confirmedAccident:
        return 'Confirmed Accident';
      case EventCategory.reportedAccident:
        return 'Reported Accident';
    }
  }

  String get badgeDescription {
    switch (this) {
      case EventCategory.detectedEvent:
        return 'Helmet Sensor Trigger (G-Force / Impact)';
      case EventCategory.confirmedAccident:
        return 'Verified Critical Collision';
      case EventCategory.reportedAccident:
        return 'External / Bystander SOS Report';
    }
  }
}

enum IncidentStatus {
  unverified,
  verified,
  falseAlarm;

  String get label {
    switch (this) {
      case IncidentStatus.unverified:
        return 'Unverified';
      case IncidentStatus.verified:
        return 'Verified (Confirmed)';
      case IncidentStatus.falseAlarm:
        return 'False Alarm';
    }
  }
}

enum AlertDeliveryStatus {
  delivered,
  pending,
  failed,
  cancelledByRider;

  String get label {
    switch (this) {
      case AlertDeliveryStatus.delivered:
        return 'Delivered';
      case AlertDeliveryStatus.pending:
        return 'Pending';
      case AlertDeliveryStatus.failed:
        return 'Failed';
      case AlertDeliveryStatus.cancelledByRider:
        return 'Cancelled by Rider (10s countdown)';
    }
  }
}

class IncidentReport {
  final String id;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final String deviceId; // Helmet BLE ID / Serial
  final EventCategory eventCategory;
  final IncidentStatus status;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String locationName; // Street / landmark
  final String city;
  final String roadName; // e.g. "NH-48 Expressway", "Outer Ring Road"
  final AlertDeliveryStatus alertDeliveryStatus;
  final int alertRecipientsCount;
  final double? gForce;
  final double? speedKmh;
  final String lightingCondition; // "Daylight", "Dusk", "Night (Poorly Lit)", "Night (Lit)"
  final String roadCondition; // "Dry Asphalt", "Wet/Slippery", "Potholes/Damaged", "Blind Curve"
  final bool isDuplicate;
  final String? duplicateGroupId;
  final String? notes;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  const IncidentReport({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.deviceId,
    required this.eventCategory,
    required this.status,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.city,
    required this.roadName,
    required this.alertDeliveryStatus,
    this.alertRecipientsCount = 0,
    this.gForce,
    this.speedKmh,
    this.lightingCondition = 'Daylight',
    this.roadCondition = 'Dry Asphalt',
    this.isDuplicate = false,
    this.duplicateGroupId,
    this.notes,
    this.verifiedBy,
    this.verifiedAt,
  });

  String get mapsUrl => 'https://maps.google.com/?q=$latitude,$longitude';

  String get formattedCoords =>
      '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E';

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'id': id,
      'riderId': riderId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'deviceId': deviceId,
      'eventCategory': eventCategory.name,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'city': city,
      'roadName': roadName,
      'alertDeliveryStatus': alertDeliveryStatus.name,
      'alertRecipientsCount': alertRecipientsCount,
      'lightingCondition': lightingCondition,
      'roadCondition': roadCondition,
      'isDuplicate': isDuplicate,
    };
    if (gForce != null) map['gForce'] = gForce;
    if (speedKmh != null) map['speedKmh'] = speedKmh;
    if (duplicateGroupId != null) map['duplicateGroupId'] = duplicateGroupId;
    if (notes != null) map['notes'] = notes;
    if (verifiedBy != null) map['verifiedBy'] = verifiedBy;
    if (verifiedAt != null) map['verifiedAt'] = Timestamp.fromDate(verifiedAt!);
    return map;
  }

  factory IncidentReport.fromFirestore(Map<String, dynamic> data, String docId) {
    DateTime parsedTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      parsedTime = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is String) {
      parsedTime = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
    }

    DateTime? parsedVerifiedAt;
    if (data['verifiedAt'] is Timestamp) {
      parsedVerifiedAt = (data['verifiedAt'] as Timestamp).toDate();
    }

    EventCategory category = EventCategory.detectedEvent;
    final catStr = data['eventCategory']?.toString();
    if (catStr == 'confirmedAccident') {
      category = EventCategory.confirmedAccident;
    } else if (catStr == 'reportedAccident') {
      category = EventCategory.reportedAccident;
    }

    IncidentStatus incStatus = IncidentStatus.unverified;
    final statStr = data['status']?.toString();
    if (statStr == 'verified') {
      incStatus = IncidentStatus.verified;
    } else if (statStr == 'falseAlarm') {
      incStatus = IncidentStatus.falseAlarm;
    }

    AlertDeliveryStatus deliveryStatus = AlertDeliveryStatus.delivered;
    final delStr = data['alertDeliveryStatus']?.toString();
    if (delStr == 'pending') {
      deliveryStatus = AlertDeliveryStatus.pending;
    } else if (delStr == 'failed') {
      deliveryStatus = AlertDeliveryStatus.failed;
    } else if (delStr == 'cancelledByRider') {
      deliveryStatus = AlertDeliveryStatus.cancelledByRider;
    }

    return IncidentReport(
      id: data['id'] ?? docId,
      riderId: data['riderId'] ?? '',
      riderName: data['riderName'] ?? 'Anonymous Rider',
      riderPhone: data['riderPhone'] ?? '--',
      deviceId: data['deviceId'] ?? 'MOTO-HELMET-01',
      eventCategory: category,
      status: incStatus,
      timestamp: parsedTime,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      locationName: data['locationName'] ?? 'Unknown Road',
      city: data['city'] ?? 'Sector Area',
      roadName: data['roadName'] ?? 'City Expressway',
      alertDeliveryStatus: deliveryStatus,
      alertRecipientsCount: (data['alertRecipientsCount'] as num?)?.toInt() ?? 0,
      gForce: (data['gForce'] as num?)?.toDouble(),
      speedKmh: (data['speedKmh'] as num?)?.toDouble(),
      lightingCondition: data['lightingCondition'] ?? 'Daylight',
      roadCondition: data['roadCondition'] ?? 'Dry Asphalt',
      isDuplicate: data['isDuplicate'] == true,
      duplicateGroupId: data['duplicateGroupId'],
      notes: data['notes'],
      verifiedBy: data['verifiedBy'],
      verifiedAt: parsedVerifiedAt,
    );
  }

  IncidentReport copyWith({
    String? id,
    String? riderId,
    String? riderName,
    String? riderPhone,
    String? deviceId,
    EventCategory? eventCategory,
    IncidentStatus? status,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? locationName,
    String? city,
    String? roadName,
    AlertDeliveryStatus? alertDeliveryStatus,
    int? alertRecipientsCount,
    double? gForce,
    double? speedKmh,
    String? lightingCondition,
    String? roadCondition,
    bool? isDuplicate,
    String? duplicateGroupId,
    String? notes,
    String? verifiedBy,
    DateTime? verifiedAt,
  }) {
    return IncidentReport(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      deviceId: deviceId ?? this.deviceId,
      eventCategory: eventCategory ?? this.eventCategory,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      city: city ?? this.city,
      roadName: roadName ?? this.roadName,
      alertDeliveryStatus: alertDeliveryStatus ?? this.alertDeliveryStatus,
      alertRecipientsCount: alertRecipientsCount ?? this.alertRecipientsCount,
      gForce: gForce ?? this.gForce,
      speedKmh: speedKmh ?? this.speedKmh,
      lightingCondition: lightingCondition ?? this.lightingCondition,
      roadCondition: roadCondition ?? this.roadCondition,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateGroupId: duplicateGroupId ?? this.duplicateGroupId,
      notes: notes ?? this.notes,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}
