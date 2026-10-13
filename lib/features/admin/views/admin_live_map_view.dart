import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/incident_report_model.dart';

class AdminLiveMapView extends StatefulWidget {
  final List<IncidentReport> incidents;

  const AdminLiveMapView({
    super.key,
    required this.incidents,
  });

  @override
  State<AdminLiveMapView> createState() => _AdminLiveMapViewState();
}

class _AdminLiveMapViewState extends State<AdminLiveMapView> {
  final MapController _mapController = MapController();
  IncidentReport? _selectedIncident;
  String _selectedFilter = 'ALL'; // ALL, CONFIRMED, DETECTED, REPORTED
  String _mapTileTheme = 'street'; // 'street' (Voyager OpenStreetMap Color), 'dark', 'osm', 'light'

  LatLng _computeInitialCenter(List<IncidentReport> list) {
    if (list.isNotEmpty) {
      return LatLng(list.first.latitude, list.first.longitude);
    }
    return const LatLng(28.6139, 77.2090); // Delhi-NCR Central fallback
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _recenterToLatest(List<IncidentReport> list) {
    if (list.isNotEmpty) {
      final latest = list.first;
      _mapController.move(LatLng(latest.latitude, latest.longitude), 13.5);
      setState(() {
        _selectedIncident = latest;
      });
    } else {
      _mapController.move(const LatLng(28.6139, 77.2090), 10.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.incidents.where((i) {
      if (_selectedFilter == 'CONFIRMED') {
        return i.eventCategory == EventCategory.confirmedAccident || i.status == IncidentStatus.verified;
      }
      if (_selectedFilter == 'DETECTED') {
        return i.eventCategory == EventCategory.detectedEvent;
      }
      if (_selectedFilter == 'REPORTED') {
        return i.eventCategory == EventCategory.reportedAccident;
      }
      return true;
    }).toList();

    // Hotspot clustering by road name
    final Map<String, List<IncidentReport>> roadClusters = {};
    for (final inc in widget.incidents) {
      roadClusters.putIfAbsent(inc.roadName, () => []).add(inc);
    }
    final sortedRoads = roadClusters.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 950;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Filter Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Map & Accident Hotspot Clusters',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real OpenStreetMap GPS satellite matrix, live collision markers & cluster overlays.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8E8E93),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildFilterChip('ALL', 'All Events'),
                      _buildFilterChip('CONFIRMED', 'Confirmed 🔴'),
                      _buildFilterChip('DETECTED', 'Detected 🟠'),
                      _buildFilterChip('REPORTED', 'Reported 🔵'),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00E5FF),
                          side: const BorderSide(color: Color(0xFF00E5FF)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () async {
                          final uri = Uri.parse('/map.html');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 13),
                        label: Text(
                          'Leaflet MapView 🌐',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Map & Detail Panel Grid
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Visual Map Radar Panel
                    Expanded(
                      flex: 7,
                      child: _buildInteractiveMapPanel(filtered, roadClusters),
                    ),
                    const SizedBox(width: 16),
                    // Side Hotspot Risk Ranking & Selected Telemetry
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          if (_selectedIncident != null) ...[
                            _buildSelectedIncidentCard(_selectedIncident!),
                            const SizedBox(height: 16),
                          ],
                          _buildHighRiskRoadsCard(sortedRoads),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildInteractiveMapPanel(filtered, roadClusters),
                    const SizedBox(height: 16),
                    if (_selectedIncident != null) ...[
                      _buildSelectedIncidentCard(_selectedIncident!),
                      const SizedBox(height: 16),
                    ],
                    _buildHighRiskRoadsCard(sortedRoads),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5E3A) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5E3A) : const Color(0xFF2C2C2E),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: isSelected ? Colors.white : const Color(0xFF8E8E93),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveMapPanel(
    List<IncidentReport> list,
    Map<String, List<IncidentReport>> clusters,
  ) {
    final initialCenter = _computeInitialCenter(list);

    // Build Hotspot Circles for cluster zones
    final List<CircleMarker> hotspotCircles = [];
    clusters.forEach((road, incList) {
      if (incList.length >= 2) {
        final avgLat = incList.map((e) => e.latitude).reduce((a, b) => a + b) / incList.length;
        final avgLng = incList.map((e) => e.longitude).reduce((a, b) => a + b) / incList.length;
        hotspotCircles.add(
          CircleMarker(
            point: LatLng(avgLat, avgLng),
            radius: 45.0,
            useRadiusInMeter: false,
            color: const Color(0xFFE82127).withValues(alpha: 0.15),
            borderColor: const Color(0xFFE82127).withValues(alpha: 0.6),
            borderStrokeWidth: 1.5,
          ),
        );
      }
    });

    return Container(
      height: 560,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Stack(
        children: [
          // Real OpenStreetMap via flutter_map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 10.5,
              minZoom: 3.0,
              maxZoom: 19.0,
            ),
            children: [
              // 1. Dynamic Real Map Tile Layer
              if (_mapTileTheme == 'street')
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.smart.sos.helmet',
                )
              else if (_mapTileTheme == 'osm')
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.smart.sos.helmet',
                )
              else if (_mapTileTheme == 'dark')
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.smart.sos.helmet',
                )
              else
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.smart.sos.helmet',
                ),

              // 2. Hotspot Cluster Radii Circles
              CircleLayer(circles: hotspotCircles),

              // 3. Real GPS Incident Markers
              MarkerLayer(
                markers: list.map((item) {
                  final isSelected = _selectedIncident?.id == item.id;

                  Color pinColor = const Color(0xFFFF9500); // Detected
                  if (item.eventCategory == EventCategory.confirmedAccident || item.status == IncidentStatus.verified) {
                    pinColor = const Color(0xFFE82127); // Confirmed Accident
                  } else if (item.eventCategory == EventCategory.reportedAccident) {
                    pinColor = const Color(0xFF00E5FF); // Reported
                  } else if (item.status == IncidentStatus.falseAlarm) {
                    pinColor = const Color(0xFF8E8E93); // False Alarm
                  }

                  return Marker(
                    point: LatLng(item.latitude, item.longitude),
                    width: isSelected ? 130 : 90,
                    height: isSelected ? 65 : 50,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedIncident = item);
                        _mapController.move(LatLng(item.latitude, item.longitude), 14.5);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSelected ? 7 : 5),
                            decoration: BoxDecoration(
                              color: pinColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.black,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: pinColor.withValues(alpha: 0.7),
                                  blurRadius: isSelected ? 14 : 7,
                                  spreadRadius: isSelected ? 3 : 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              item.eventCategory == EventCategory.confirmedAccident
                                  ? Icons.warning_rounded
                                  : (item.status == IncidentStatus.falseAlarm
                                      ? Icons.close_rounded
                                      : Icons.my_location_rounded),
                              color: Colors.white,
                              size: isSelected ? 16 : 12,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141518).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: pinColor.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              item.locationName.isNotEmpty ? item.locationName : item.roadName,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Header Badge (Top Left)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF141518).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2C2C2E)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_rounded, color: Color(0xFF00E5FF), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'OPENSTREETMAP LIVE GPS MATRIX (${list.length} PLOTTED)',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Style Switcher (Top Right)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF141518).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2C2C2E)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  _buildThemeButton('street', 'Street Map 🗺️'),
                  const SizedBox(width: 4),
                  _buildThemeButton('osm', 'OpenStreetMap 🌐'),
                  const SizedBox(width: 4),
                  _buildThemeButton('dark', 'Dark Cyber 🌙'),
                  const SizedBox(width: 4),
                  _buildThemeButton('light', 'Light ☀️'),
                ],
              ),
            ),
          ),

          // Interactive Zoom & Recenter Controls (Bottom Right)
          Positioned(
            bottom: 60,
            right: 16,
            child: Column(
              children: [
                _buildMapFloatingBtn(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recenter to Latest Incident',
                  onTap: () => _recenterToLatest(list),
                ),
                const SizedBox(height: 8),
                _buildMapFloatingBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),
                _buildMapFloatingBtn(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),

          // Bottom Status Legend
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141518).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2E)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLegendItem(const Color(0xFFE82127), 'Confirmed Accident'),
                  _buildLegendItem(const Color(0xFFFF9500), 'Helmet Detected Event'),
                  _buildLegendItem(const Color(0xFF00E5FF), 'Bystander Reported SOS'),
                  _buildLegendItem(const Color(0xFF8E8E93), 'False Alarm (Cancelled)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton(String themeKey, String label) {
    final isSelected = _mapTileTheme == themeKey;
    return InkWell(
      onTap: () => setState(() => _mapTileTheme = themeKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5E3A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : const Color(0xFF8E8E93),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMapFloatingBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2C2C2E)),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF8E8E93),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedIncidentCard(IncidentReport inc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF5E3A).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5E3A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  inc.eventCategory.label.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFFFF5E3A),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, color: Color(0xFF8E8E93), size: 16),
                onPressed: () => setState(() => _selectedIncident = null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            inc.locationName,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${inc.roadName} • ${inc.city}',
            style: GoogleFonts.inter(
              color: const Color(0xFF8E8E93),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildTelemetryRow('Rider Name', inc.riderName),
                _buildTelemetryRow('Phone Number', inc.riderPhone),
                _buildTelemetryRow('Helmet BLE Device', inc.deviceId),
                _buildTelemetryRow('Timestamp', DateFormat('dd MMM, hh:mm a').format(inc.timestamp)),
                _buildTelemetryRow('Impact G-Force', inc.gForce != null ? '${inc.gForce}G' : 'N/A'),
                _buildTelemetryRow('GPS Coordinates', inc.formattedCoords),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(inc.mapsUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: Text(
                'Open in Google Maps',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: const Color(0xFF8E8E93), fontSize: 11),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighRiskRoadsCard(List<MapEntry<String, List<IncidentReport>>> sortedRoads) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REPEAT ACCIDENT HOTSPOTS',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE82127), size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'High-risk corridors identified by frequent cluster triggers',
            style: GoogleFonts.inter(
              color: const Color(0xFF8E8E93),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedRoads.take(5).map((entry) {
            final road = entry.key;
            final count = entry.value.length;
            final isCritical = count >= 3;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCritical
                      ? const Color(0xFFE82127).withValues(alpha: 0.4)
                      : const Color(0xFF2C2C2E),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isCritical ? const Color(0xFFE82127) : const Color(0xFFFF9500))
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: GoogleFonts.spaceGrotesk(
                          color: isCritical ? const Color(0xFFE82127) : const Color(0xFFFF9500),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          road,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isCritical ? 'CRITICAL HOTSPOT • Road Audit Recommended' : 'Moderate Frequency',
                          style: GoogleFonts.jetBrainsMono(
                            color: isCritical ? const Color(0xFFE82127) : const Color(0xFF8E8E93),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
