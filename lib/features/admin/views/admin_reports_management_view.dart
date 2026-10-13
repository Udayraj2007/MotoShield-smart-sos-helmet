import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/incident_report_model.dart';
import '../services/incident_firestore_service.dart';

class AdminReportsManagementView extends StatefulWidget {
  final List<IncidentReport> incidents;

  const AdminReportsManagementView({
    super.key,
    required this.incidents,
  });

  @override
  State<AdminReportsManagementView> createState() => _AdminReportsManagementViewState();
}

class _AdminReportsManagementViewState extends State<AdminReportsManagementView> {
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, UNVERIFIED, VERIFIED, FALSE_ALARM
  String _categoryFilter = 'ALL'; // ALL, DETECTED, CONFIRMED, REPORTED

  @override
  Widget build(BuildContext context) {
    final filtered = widget.incidents.where((item) {
      // 1. Search Query
      final query = _searchQuery.toLowerCase().trim();
      if (query.isNotEmpty) {
        final matches = item.riderName.toLowerCase().contains(query) ||
            item.riderPhone.toLowerCase().contains(query) ||
            item.roadName.toLowerCase().contains(query) ||
            item.locationName.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query);
        if (!matches) return false;
      }

      // 2. Status Filter
      if (_statusFilter == 'UNVERIFIED' && item.status != IncidentStatus.unverified) return false;
      if (_statusFilter == 'VERIFIED' && item.status != IncidentStatus.verified) return false;
      if (_statusFilter == 'FALSE_ALARM' && item.status != IncidentStatus.falseAlarm) return false;

      // 3. Category Filter
      if (_categoryFilter == 'DETECTED' && item.eventCategory != EventCategory.detectedEvent) return false;
      if (_categoryFilter == 'CONFIRMED' && item.eventCategory != EventCategory.confirmedAccident) return false;
      if (_categoryFilter == 'REPORTED' && item.eventCategory != EventCategory.reportedAccident) return false;

      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accident Reports & Dispatch Management',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review telemetry, confirm collision validity, flag false positives & identify duplicates.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8E8E93),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                'Showing ${filtered.length} of ${widget.incidents.length} Records',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF8E8E93),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Search & Filter Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141518),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2C2C2E)),
                        ),
                        child: TextField(
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by Rider Name, Phone, Road, Incident ID...',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF636366), fontSize: 12),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93), size: 18),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterButton('ALL', 'All Status', _statusFilter, (v) => setState(() => _statusFilter = v)),
                        _buildFilterButton('UNVERIFIED', 'Unverified ⏳', _statusFilter, (v) => setState(() => _statusFilter = v)),
                        _buildFilterButton('VERIFIED', 'Verified (Confirmed) ✅', _statusFilter, (v) => setState(() => _statusFilter = v)),
                        _buildFilterButton('FALSE_ALARM', 'False Alarm ❌', _statusFilter, (v) => setState(() => _statusFilter = v)),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterButton('ALL', 'All Categories', _categoryFilter, (v) => setState(() => _categoryFilter = v)),
                        _buildFilterButton('CONFIRMED', 'Confirmed', _categoryFilter, (v) => setState(() => _categoryFilter = v)),
                        _buildFilterButton('DETECTED', 'Detected', _categoryFilter, (v) => setState(() => _categoryFilter = v)),
                        _buildFilterButton('REPORTED', 'Reported', _categoryFilter, (v) => setState(() => _categoryFilter = v)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Incident Reports List / Table
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF141518),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.inbox_outlined, color: Color(0xFF8E8E93), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'No incident records match the filter.',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildIncidentRowCard(item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String val, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == val;
    return InkWell(
      onTap: () => onSelect(val),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5E3A).withValues(alpha: 0.15) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5E3A) : const Color(0xFF2C2C2E),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? const Color(0xFFFF5E3A) : const Color(0xFF8E8E93),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentRowCard(IncidentReport item) {
    Color categoryColor = const Color(0xFFFF9500);
    if (item.eventCategory == EventCategory.confirmedAccident || item.status == IncidentStatus.verified) {
      categoryColor = const Color(0xFFE82127);
    } else if (item.eventCategory == EventCategory.reportedAccident) {
      categoryColor = const Color(0xFF00E5FF);
    }

    Color statusColor = const Color(0xFFFF9500);
    if (item.status == IncidentStatus.verified) {
      statusColor = const Color(0xFF00E676);
    } else if (item.status == IncidentStatus.falseAlarm) {
      statusColor = const Color(0xFF636366);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isDuplicate
              ? const Color(0xFFFF9500).withValues(alpha: 0.4)
              : const Color(0xFF2C2C2E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Category, Duplicate Badge, Status Badge & Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: categoryColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      item.eventCategory.label.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        color: categoryColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (item.isDuplicate)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, color: Color(0xFFFF9500), size: 10),
                          const SizedBox(width: 4),
                          Text(
                            'DUPLICATE REPORT DETECTED',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFFFF9500),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.status.label.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(item.timestamp),
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF8E8E93),
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Main Details Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.locationName,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.roadName} • ${item.city}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8E8E93),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GPS: ${item.formattedCoords}',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF00E5FF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.riderName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Phone: ${item.riderPhone}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8E8E93),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Device: ${item.deviceId}',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF636366),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.alertDeliveryStatus.label,
                      style: GoogleFonts.jetBrainsMono(
                        color: item.alertDeliveryStatus == AlertDeliveryStatus.delivered
                            ? const Color(0xFF00E676)
                            : (item.alertDeliveryStatus == AlertDeliveryStatus.cancelledByRider
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFFE82127)),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${item.alertRecipientsCount} contacts alerted',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8E8E93),
                        fontSize: 10,
                      ),
                    ),
                    if (item.gForce != null)
                      Text(
                        'Impact: ${item.gForce}G',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFFFF5E3A),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              // Action Buttons
              Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Open in Google Maps',
                    icon: const Icon(Icons.map_outlined, color: Color(0xFF00E5FF), size: 18),
                    onPressed: () async {
                      final uri = Uri.parse(item.mapsUrl);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
                  if (item.status != IncidentStatus.verified)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF00E676),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF00E676)),
                        ),
                      ),
                      onPressed: () {
                        IncidentFirestoreService.instance.updateIncidentStatus(
                          item.id,
                          IncidentStatus.verified,
                          notes: 'Confirmed by Admin Operator',
                        );
                      },
                      child: Text('Confirm Crash', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  if (item.status != IncidentStatus.falseAlarm)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8E8E93),
                        side: const BorderSide(color: Color(0xFF2C2C2E)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        IncidentFirestoreService.instance.updateIncidentStatus(
                          item.id,
                          IncidentStatus.falseAlarm,
                          notes: 'Marked as False Alarm by Admin',
                        );
                      },
                      child: Text('False Alarm', style: GoogleFonts.inter(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ),

          if (item.notes != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Notes: ${item.notes}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8E8E93),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
