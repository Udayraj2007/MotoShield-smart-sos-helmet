import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'ble_service.dart';

enum LocationSourceType {
  helmetGps,
  phoneGps,
  dualFused,
  none,
}

class FusedLocation {
  final double latitude;
  final double longitude;
  final LocationSourceType source;
  final String sourceLabel;
  final double? accuracyMeters;
  final int satellites;
  final String street;
  final String city;
  final DateTime timestamp;

  const FusedLocation({
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.sourceLabel,
    this.accuracyMeters,
    this.satellites = 0,
    required this.street,
    required this.city,
    required this.timestamp,
  });

  String get mapsUrl => 'https://maps.google.com/?q=$latitude,$longitude';

  String get readableCoordinates =>
      '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E';
}

class LocationFusionService {
  static final LocationFusionService instance =
      LocationFusionService._internal();
  LocationFusionService._internal();

  final _locationController = StreamController<FusedLocation>.broadcast();
  Stream<FusedLocation> get locationStream => _locationController.stream;

  final ValueNotifier<FusedLocation?> locationNotifier =
      ValueNotifier<FusedLocation?>(null);
  FusedLocation? get currentLocation => locationNotifier.value;

  StreamSubscription<Position>? _phonePositionSub;
  StreamSubscription<HelmetTelemetry>? _telemetrySub;

  Position? _latestPhonePosition;
  HelmetTelemetry? _latestHelmetTelemetry;

  String _cachedStreet = 'Acquiring GPS Signal...';
  String _cachedCity = 'Searching Satellites';
  double? _lastGeocodedLat;
  double? _lastGeocodedLng;
  bool _isGeocoding = false;

  void init() {
    _startPhoneGpsMonitoring();
    _startHelmetGpsMonitoring();
  }

  Future<void> _startPhoneGpsMonitoring() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services disabled on phone
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // 1. Instant last-known fix (0ms latency)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && _latestPhonePosition == null) {
          _latestPhonePosition = lastKnown;
          _recomputeBestLocation();
        }
      } catch (_) {}

      // 2. High-accuracy immediate phone fix
      try {
        final initialPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        _latestPhonePosition = initialPos;
        _recomputeBestLocation();
      } catch (_) {}

      // Continuous high accuracy phone stream
      _phonePositionSub?.cancel();
      _phonePositionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen(
        (Position pos) {
          _latestPhonePosition = pos;
          _recomputeBestLocation();
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _startHelmetGpsMonitoring() {
    _telemetrySub?.cancel();
    _telemetrySub = BleService.instance.telemetry.listen((telemetry) {
      _latestHelmetTelemetry = telemetry;
      _recomputeBestLocation();
    });
  }

  bool _isHelmetGpsValid(HelmetTelemetry? t) {
    if (t == null) return false;
    final lat = t.latitude;
    final lng = t.longitude;
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return t.gpsFix || (t.satellites != null && t.satellites! >= 3);
  }

  bool _isPhoneGpsValid(Position? p) {
    if (p == null) return false;
    if (p.latitude == 0.0 && p.longitude == 0.0) return false;
    return true;
  }

  void _recomputeBestLocation() {
    final hasHelmet = _isHelmetGpsValid(_latestHelmetTelemetry);
    final hasPhone = _isPhoneGpsValid(_latestPhonePosition);

    if (!hasHelmet && !hasPhone) {
      return;
    }

    double bestLat;
    double bestLng;
    LocationSourceType source;
    String sourceLabel;
    double? accuracy;
    int sats = _latestHelmetTelemetry?.satellites ?? 0;

    if (hasHelmet && hasPhone) {
      // Both available: Dual Fused!
      final phoneAcc = _latestPhonePosition!.accuracy;
      if (sats >= 6 && phoneAcc > 15) {
        bestLat = _latestHelmetTelemetry!.latitude!;
        bestLng = _latestHelmetTelemetry!.longitude!;
        source = LocationSourceType.dualFused;
        sourceLabel = 'DUAL FUSED • HELMET ($sats SATS)';
        accuracy = 5.0;
      } else {
        bestLat = _latestPhonePosition!.latitude;
        bestLng = _latestPhonePosition!.longitude;
        source = LocationSourceType.dualFused;
        sourceLabel =
            'DUAL FUSED • PHONE (±${phoneAcc.toStringAsFixed(0)}m)';
        accuracy = phoneAcc;
      }
    } else if (hasPhone && !hasHelmet) {
      // Helmet GPS unavailable (e.g. indoor / searching) -> Phone GPS fallback!
      bestLat = _latestPhonePosition!.latitude;
      bestLng = _latestPhonePosition!.longitude;
      source = LocationSourceType.phoneGps;
      final acc = _latestPhonePosition!.accuracy;
      sourceLabel = 'PHONE GPS (±${acc.toStringAsFixed(0)}m)';
      accuracy = acc;
    } else {
      // Phone GPS unavailable -> Helmet GPS!
      bestLat = _latestHelmetTelemetry!.latitude!;
      bestLng = _latestHelmetTelemetry!.longitude!;
      source = LocationSourceType.helmetGps;
      sourceLabel = 'HELMET GPS ($sats SATS)';
      accuracy = 10.0;
    }

    _updateAddressIfNeeded(bestLat, bestLng);

    final fused = FusedLocation(
      latitude: bestLat,
      longitude: bestLng,
      source: source,
      sourceLabel: sourceLabel,
      accuracyMeters: accuracy,
      satellites: sats,
      street: _cachedStreet,
      city: _cachedCity,
      timestamp: DateTime.now(),
    );

    locationNotifier.value = fused;
    if (!_locationController.isClosed) {
      _locationController.add(fused);
    }
  }

  Future<void> _updateAddressIfNeeded(double lat, double lng) async {
    if (_isGeocoding) return;

    if (_lastGeocodedLat != null && _lastGeocodedLng != null) {
      final distance = Geolocator.distanceBetween(
        _lastGeocodedLat!,
        _lastGeocodedLng!,
        lat,
        lng,
      );
      if (distance < 25.0) return;
    }

    _isGeocoding = true;
    _lastGeocodedLat = lat;
    _lastGeocodedLng = lng;

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _cachedStreet = p.street?.isNotEmpty == true
            ? p.street!
            : (p.subLocality?.isNotEmpty == true
                ? p.subLocality!
                : 'Current Location');
        _cachedCity =
            '${p.locality ?? ""}, ${p.administrativeArea ?? ""} • ${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E';

        if (locationNotifier.value != null) {
          final cur = locationNotifier.value!;
          final updated = FusedLocation(
            latitude: cur.latitude,
            longitude: cur.longitude,
            source: cur.source,
            sourceLabel: cur.sourceLabel,
            accuracyMeters: cur.accuracyMeters,
            satellites: cur.satellites,
            street: _cachedStreet,
            city: _cachedCity,
            timestamp: cur.timestamp,
          );
          locationNotifier.value = updated;
          if (!_locationController.isClosed) {
            _locationController.add(updated);
          }
        }
      }
    } catch (_) {
      _cachedCity =
          '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E';
    } finally {
      _isGeocoding = false;
    }
  }

  Future<String> getEmergencyMapsUrl() async {
    if (locationNotifier.value != null) {
      return locationNotifier.value!.mapsUrl;
    }

    if (_isHelmetGpsValid(_latestHelmetTelemetry)) {
      return 'https://maps.google.com/?q=${_latestHelmetTelemetry!.latitude},${_latestHelmetTelemetry!.longitude}';
    }

    if (_isPhoneGpsValid(_latestPhonePosition)) {
      return 'https://maps.google.com/?q=${_latestPhonePosition!.latitude},${_latestPhonePosition!.longitude}';
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 2),
        ),
      );
      return 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    } catch (_) {}

    return '$_cachedStreet, $_cachedCity';
  }

  ({double? lat, double? lng}) getEffectiveCoords() {
    if (locationNotifier.value != null) {
      return (
        lat: locationNotifier.value!.latitude,
        lng: locationNotifier.value!.longitude,
      );
    }
    return (
      lat: _latestPhonePosition?.latitude ??
          _latestHelmetTelemetry?.latitude,
      lng: _latestPhonePosition?.longitude ??
          _latestHelmetTelemetry?.longitude,
    );
  }

  void dispose() {
    _phonePositionSub?.cancel();
    _telemetrySub?.cancel();
    _locationController.close();
  }
}
