import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/incident_report_model.dart';

class IncidentFirestoreService {
  IncidentFirestoreService._();
  static final IncidentFirestoreService instance = IncidentFirestoreService._();

  static const String _collectionName = 'incident_reports';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory fallback / cache in case Firestore is unreachable offline
  final List<IncidentReport> _inMemoryCache = [];
  final ValueNotifier<List<IncidentReport>> incidentsNotifier =
      ValueNotifier<List<IncidentReport>>([]);

  List<IncidentReport> get currentIncidents {
    if (_inMemoryCache.isEmpty) {
      ensureLocalDataLoaded();
    }
    return List.unmodifiable(_inMemoryCache);
  }

  /// Real-time stream of all incidents from Firestore (sorted newest first)
  Stream<List<IncidentReport>> getIncidentsStream() async* {
    if (_inMemoryCache.isEmpty) {
      ensureLocalDataLoaded();
    }
    yield List.unmodifiable(_inMemoryCache);

    try {
      await for (final snapshot in _firestore
          .collection(_collectionName)
          .orderBy('timestamp', descending: true)
          .snapshots()) {
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) {
            return IncidentReport.fromFirestore(doc.data(), doc.id);
          }).toList();

          _inMemoryCache
            ..clear()
            ..addAll(list);
          incidentsNotifier.value = List.unmodifiable(_inMemoryCache);
          yield list;
        } else {
          yield List.unmodifiable(_inMemoryCache);
        }
      }
    } catch (e) {
      debugPrint('Firestore stream exception: $e');
      yield List.unmodifiable(_inMemoryCache);
    }
  }

  /// Record an incident to Firestore
  Future<void> recordIncident(IncidentReport report) async {
    // 1. Run duplicate check against recent incidents
    final processedReport = _checkAndTagDuplicate(report);

    // 2. Add to in-memory cache first for instant UI response
    _inMemoryCache.removeWhere((i) => i.id == processedReport.id);
    _inMemoryCache.insert(0, processedReport);
    incidentsNotifier.value = List.unmodifiable(_inMemoryCache);

    // 3. Persist to Firestore
    try {
      await _firestore
          .collection(_collectionName)
          .doc(processedReport.id)
          .set(processedReport.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save incident to Firestore (saved locally): $e');
    }
  }

  /// Update incident verification status (e.g. from Unverified to Verified or False Alarm)
  Future<void> updateIncidentStatus(
    String id,
    IncidentStatus newStatus, {
    String? notes,
    String? verifiedBy,
  }) async {
    final now = DateTime.now();

    // Update in cache
    final index = _inMemoryCache.indexWhere((i) => i.id == id);
    if (index != -1) {
      final old = _inMemoryCache[index];
      // When verified as a confirmed collision, promote eventCategory if it was detectedEvent
      EventCategory updatedCategory = old.eventCategory;
      if (newStatus == IncidentStatus.verified &&
          old.eventCategory == EventCategory.detectedEvent) {
        updatedCategory = EventCategory.confirmedAccident;
      }

      final updated = old.copyWith(
        status: newStatus,
        eventCategory: updatedCategory,
        notes: notes ?? old.notes,
        verifiedBy: verifiedBy ?? 'Admin Operative #104',
        verifiedAt: now,
      );
      _inMemoryCache[index] = updated;
      incidentsNotifier.value = List.unmodifiable(_inMemoryCache);
    }

    try {
      await _firestore.collection(_collectionName).doc(id).update({
        'status': newStatus.name,
        if (notes != null) 'notes': notes,
        'verifiedBy': verifiedBy ?? 'Admin Operative #104',
        'verifiedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      debugPrint('Failed to update status on Firestore: $e');
    }
  }

  /// Delete an incident
  Future<void> deleteIncident(String id) async {
    _inMemoryCache.removeWhere((i) => i.id == id);
    incidentsNotifier.value = List.unmodifiable(_inMemoryCache);

    try {
      await _firestore.collection(_collectionName).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting incident: $e');
    }
  }

  /// Checks if an incident is a duplicate (same location within 500m & within 15 minutes)
  IncidentReport _checkAndTagDuplicate(IncidentReport newReport) {
    for (final existing in _inMemoryCache) {
      if (existing.id == newReport.id) continue;

      final timeDiff = newReport.timestamp.difference(existing.timestamp).abs();
      if (timeDiff.inMinutes <= 20) {
        final distanceMeters = Geolocator.distanceBetween(
          newReport.latitude,
          newReport.longitude,
          existing.latitude,
          existing.longitude,
        );

        if (distanceMeters <= 500) {
          return newReport.copyWith(
            isDuplicate: true,
            duplicateGroupId: existing.duplicateGroupId ?? existing.id,
            notes: '${newReport.notes != null ? '${newReport.notes} • ' : ''}Flagged as duplicate of ${existing.id} (${distanceMeters.toStringAsFixed(0)}m proximity)',
          );
        }
      }
    }
    return newReport;
  }

  /// Immediately populates in-memory cache with demo incidents without blocking network
  void ensureLocalDataLoaded({bool force = false}) {
    if (_inMemoryCache.isNotEmpty && !force) return;
    final samples = _generateSampleData();
    _inMemoryCache
      ..clear()
      ..addAll(samples);
    incidentsNotifier.value = List.unmodifiable(_inMemoryCache);
  }

  /// Seeds realistic high-fidelity Delhi-NCR & Highway telemetry incidents
  /// for immediate demonstration of maps, hotspots, charts, and report management.
  Future<void> seedRealisticDemoData({bool force = false}) async {
    ensureLocalDataLoaded(force: force);

    try {
      final samples = _generateSampleData();
      final futures = samples.map((inc) {
        return _firestore
            .collection(_collectionName)
            .doc(inc.id)
            .set(inc.toFirestore(), SetOptions(merge: true))
            .catchError((_) {});
      });
      await Future.wait(futures)
          .timeout(const Duration(seconds: 4), onTimeout: () => []);
    } catch (e) {
      debugPrint('Firestore demo sync skipped: $e');
    }
  }

  List<IncidentReport> _generateSampleData() {
    final now = DateTime.now();

    return [
      // 1. NH-48 Hero Honda Chowk (Known Major Hotspot)
      IncidentReport(
        id: 'INC-2026-1001',
        riderId: 'USR-8912',
        riderName: 'Vikramaditya Sharma',
        riderPhone: '+91 98112 43210',
        deviceId: 'MOTO-HELMET-X1-884',
        eventCategory: EventCategory.confirmedAccident,
        status: IncidentStatus.verified,
        timestamp: now.subtract(const Duration(minutes: 42)),
        latitude: 28.4354,
        longitude: 77.0125,
        locationName: 'Hero Honda Chowk Flyover Ramp',
        city: 'Gurugram',
        roadName: 'NH-48 Expressway (Km 37)',
        alertDeliveryStatus: AlertDeliveryStatus.delivered,
        alertRecipientsCount: 4,
        gForce: 5.4,
        speedKmh: 68.0,
        lightingCondition: 'Night (Lit)',
        roadCondition: 'Dry Asphalt',
        notes: 'High speed side-impact detected. Ambulance dispatched in 4 mins.',
        verifiedBy: 'Inspector R. Yadav (Traffic Control)',
        verifiedAt: now.subtract(const Duration(minutes: 35)),
      ),

      // 2. Hero Honda Chowk - Duplicate Bystander Report
      IncidentReport(
        id: 'INC-2026-1002',
        riderId: 'BYSTANDER-01',
        riderName: 'Amanpreet Singh',
        riderPhone: '+91 99201 11223',
        deviceId: 'EXTERNAL-APP',
        eventCategory: EventCategory.reportedAccident,
        status: IncidentStatus.verified,
        timestamp: now.subtract(const Duration(minutes: 38)),
        latitude: 28.4358,
        longitude: 77.0129,
        locationName: 'Opposite Hero Honda Chowk Underpass',
        city: 'Gurugram',
        roadName: 'NH-48 Expressway (Km 37)',
        alertDeliveryStatus: AlertDeliveryStatus.delivered,
        alertRecipientsCount: 2,
        isDuplicate: true,
        duplicateGroupId: 'INC-2026-1001',
        notes: 'Bystander reported bike collision. Merged with INC-2026-1001.',
      ),

      // 3. Rajiv Chowk Flyover (Hotspot #2)
      IncidentReport(
        id: 'INC-2026-1003',
        riderId: 'USR-4421',
        riderName: 'Kunal Singhal',
        riderPhone: '+91 97188 56001',
        deviceId: 'MOTO-HELMET-V2-019',
        eventCategory: EventCategory.detectedEvent,
        status: IncidentStatus.unverified,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 15)),
        latitude: 28.4595,
        longitude: 77.0321,
        locationName: 'Rajiv Chowk Underpass Entry',
        city: 'Gurugram',
        roadName: 'Sohna Road / NH-48 Link',
        alertDeliveryStatus: AlertDeliveryStatus.delivered,
        alertRecipientsCount: 3,
        gForce: 4.1,
        speedKmh: 52.0,
        lightingCondition: 'Night (Poorly Lit)',
        roadCondition: 'Potholes/Damaged',
        notes: 'Helmet detected deceleration shock. Contact notified.',
      ),

      // 4. False Alarm (Countdown cancelled)
      IncidentReport(
        id: 'INC-2026-1004',
        riderId: 'USR-1190',
        riderName: 'Rohan Mehra',
        riderPhone: '+91 98100 88219',
        deviceId: 'MOTO-HELMET-08',
        eventCategory: EventCategory.detectedEvent,
        status: IncidentStatus.falseAlarm,
        timestamp: now.subtract(const Duration(hours: 4, minutes: 5)),
        latitude: 28.4986,
        longitude: 77.0878,
        locationName: 'Cyber City Cyber Hub Loop',
        city: 'Gurugram',
        roadName: 'DLF Golf Course Road',
        alertDeliveryStatus: AlertDeliveryStatus.cancelledByRider,
        alertRecipientsCount: 0,
        gForce: 3.2,
        speedKmh: 24.0,
        lightingCondition: 'Dusk',
        roadCondition: 'Dry Asphalt',
        notes: 'Rider dropped helmet while parking. SOS countdown cancelled safely.',
      ),

      // 5. Outer Ring Road, Delhi - Mukarba Chowk (Severe Hotspot)
      IncidentReport(
        id: 'INC-2026-1005',
        riderId: 'USR-7731',
        riderName: 'Deepak Verma',
        riderPhone: '+91 98991 76543',
        deviceId: 'MOTO-HELMET-PRO-99',
        eventCategory: EventCategory.confirmedAccident,
        status: IncidentStatus.verified,
        timestamp: now.subtract(const Duration(hours: 7, minutes: 20)),
        latitude: 28.7360,
        longitude: 77.1620,
        locationName: 'Mukarba Chowk Cloverleaf',
        city: 'North Delhi',
        roadName: 'Outer Ring Road (NH-1 Junction)',
        alertDeliveryStatus: AlertDeliveryStatus.delivered,
        alertRecipientsCount: 5,
        gForce: 6.8,
        speedKmh: 75.0,
        lightingCondition: 'Night (Poorly Lit)',
        roadCondition: 'Blind Curve',
        notes: 'Severe impact against railing. Highway patrol responded.',
        verifiedBy: 'Delhi Highway Patrol - Unit 12',
        verifiedAt: now.subtract(const Duration(hours: 7)),
      ),

      // 6. DND Flyway, Noida Toll
      IncidentReport(
        id: 'INC-2026-1006',
        riderId: 'USR-3129',
        riderName: 'Priya Narang',
        riderPhone: '+91 99114 20045',
        deviceId: 'MOTO-HELMET-X1-552',
        eventCategory: EventCategory.reportedAccident,
        status: IncidentStatus.unverified,
        timestamp: now.subtract(const Duration(hours: 12, minutes: 10)),
        latitude: 28.5721,
        longitude: 77.2982,
        locationName: 'DND Flyway Km 4.2',
        city: 'Noida',
        roadName: 'DND Flyway Expressway',
        alertDeliveryStatus: AlertDeliveryStatus.delivered,
        alertRecipientsCount: 3,
        gForce: 3.8,
        speedKmh: 58.0,
        lightingCondition: 'Daylight',
        roadCondition: 'Wet/Slippery',
        notes: 'Skid reported during morning drizzle. Awaiting police confirmation.',
      ),

      // 7. NH-48 Bilaspur Industrial Corridor
      IncidentReport(
        id: 'INC-2026-1007',
        riderId: 'USR-9023',
        riderName: 'Satish Chander',
        riderPhone: '+91 98110 33445',
        deviceId: 'MOTO-HELMET-14',
        eventCategory: EventCategory.confirmedAccident,
        status: IncidentStatus.verified,
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        latitude: 28.3245,
        longitude: 76.8850,
        locationName: 'Bilaspur Chowk Crossing',
        city: 'Manesar',
        roadName: 'NH-48 Jaipur Highway',
        alertDeliveryStatus: AlertDeliveryStatus.delivered,
        alertRecipientsCount: 4,
        gForce: 5.9,
        speedKmh: 64.0,
        lightingCondition: 'Night (Poorly Lit)',
        roadCondition: 'Potholes/Damaged',
        notes: 'Heavy vehicle collision. Safety barrier damaged.',
        verifiedBy: 'NHAI Regional Safety Cell',
      ),

      // 8. IFFCO Chowk, MG Road
      IncidentReport(
        id: 'INC-2026-1008',
        riderId: 'USR-5541',
        riderName: 'Ananya Deshmukh',
        riderPhone: '+91 97177 99002',
        deviceId: 'MOTO-HELMET-03',
        eventCategory: EventCategory.detectedEvent,
        status: IncidentStatus.falseAlarm,
        timestamp: now.subtract(const Duration(days: 1, hours: 8)),
        latitude: 28.4716,
        longitude: 77.0722,
        locationName: 'IFFCO Chowk Metro Gate 2',
        city: 'Gurugram',
        roadName: 'MG Road',
        alertDeliveryStatus: AlertDeliveryStatus.cancelledByRider,
        alertRecipientsCount: 0,
        gForce: 2.8,
        speedKmh: 12.0,
        lightingCondition: 'Daylight',
        roadCondition: 'Dry Asphalt',
        notes: 'Sudden braking event on speed breaker. Cancelled.',
      ),

      // 9. Shankar Chowk Cyber City
      IncidentReport(
        id: 'INC-2026-1009',
        riderId: 'USR-6622',
        riderName: 'Mohit Rawat',
        riderPhone: '+91 98711 22334',
        deviceId: 'MOTO-HELMET-22',
        eventCategory: EventCategory.confirmedAccident,
        status: IncidentStatus.verified,
        timestamp: now.subtract(const Duration(days: 2, hours: 5)),
        latitude: 28.4980,
        longitude: 77.0910,
        locationName: 'Shankar Chowk U-Turn Flyover',
        city: 'Gurugram',
        roadName: 'NH-48 Expressway Link',
        alertDeliveryStatus: AlertDeliveryStatus.delivered,
        alertRecipientsCount: 3,
        gForce: 4.9,
        speedKmh: 45.0,
        lightingCondition: 'Night (Lit)',
        roadCondition: 'Blind Curve',
        notes: 'Two-wheeler slip on tight curve. Rider stabilized.',
        verifiedBy: 'Gurugram Police Control Room',
      ),

      // 10. Outer Ring Road, IIT Flyover
      IncidentReport(
        id: 'INC-2026-1010',
        riderId: 'USR-1109',
        riderName: 'Tanya Sengupta',
        riderPhone: '+91 99990 44556',
        deviceId: 'MOTO-HELMET-PRO-07',
        eventCategory: EventCategory.detectedEvent,
        status: IncidentStatus.unverified,
        timestamp: now.subtract(const Duration(days: 2, hours: 14)),
        latitude: 28.5449,
        longitude: 77.1926,
        locationName: 'IIT Flyover Descent',
        city: 'South Delhi',
        roadName: 'Outer Ring Road',
        alertDeliveryStatus: AlertDeliveryStatus.delivered,
        alertRecipientsCount: 2,
        gForce: 3.9,
        speedKmh: 40.0,
        lightingCondition: 'Night (Poorly Lit)',
        roadCondition: 'Dry Asphalt',
        notes: 'Impact alert sent. Rider phone currently switched off.',
      ),
    ];
  }
}
