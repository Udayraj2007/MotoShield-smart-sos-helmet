import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import 'history_model.dart';
import 'history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final HistoryService _historyService = HistoryService();
  List<HistoryModel> _allEvents = [];
  List<HistoryModel> _filteredEvents = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
    HistoryService.eventNotifier.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    HistoryService.eventNotifier.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) {
      _loadHistoryData();
    }
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);
    final events = await _historyService.loadHistory();
    setState(() {
      _allEvents = events;
      _applyFilter(_selectedFilter);
      _isLoading = false;
    });
  }

  void _applyFilter(String filter) {
    _selectedFilter = filter;
    if (filter == 'ALL') {
      _filteredEvents = List.from(_allEvents);
    } else if (filter == 'CRASHES') {
      _filteredEvents = _allEvents
          .where((e) => e.eventType == HistoryEventType.crashDetected)
          .toList();
    } else if (filter == 'SOS ALERTS') {
      _filteredEvents = _allEvents
          .where(
            (e) =>
                e.eventType == HistoryEventType.sosTriggered ||
                e.eventType == HistoryEventType.sosCancelled,
          )
          .toList();
    } else if (filter == 'SESSIONS') {
      _filteredEvents = _allEvents
          .where((e) => e.eventType == HistoryEventType.ridingSession)
          .toList();
    } else if (filter == 'BLE LINK') {
      _filteredEvents = _allEvents
          .where(
            (e) =>
                e.eventType == HistoryEventType.helmetConnected ||
                e.eventType == HistoryEventType.helmetDisconnected,
          )
          .toList();
    }
  }

  Future<void> _deleteEvent(HistoryModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C2C2E), width: 1.5),
        ),
        title: Text(
          'DELETE EVENT LOG',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Remove this "${event.typeLabel}" record permanently from your local device storage?',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF8E8E93),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE82127),
            ),
            child: Text(
              'DELETE',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.deleteEvent(event.id);
      await _loadHistoryData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Event record deleted',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF141414),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF2C2C2E)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C2C2E), width: 1.5),
        ),
        title: Text(
          'CLEAR ALL HISTORY',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFFE82127),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to clear all history records? This cannot be undone.',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF8E8E93),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE82127),
            ),
            child: Text(
              'CLEAR ALL',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearHistory();
      await _loadHistoryData();
    }
  }

  void _showAddEventDialog() {
    HistoryEventType selectedType = HistoryEventType.crashDetected;
    final statusController = TextEditingController(
      text: 'SIMULATED CRASH DISPATCH',
    );
    final detailsController = TextEditingController(
      text: 'Peak Impact Force: 5.2G | GPS Sent via Cellular Transmitter',
    );
    final locationController = TextEditingController(
      text: 'Electronic City Phase 1, Bengaluru',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF2C2C2E), width: 1.5),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LOG SIMULATED EVENT',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white60,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Event Type Dropdown
                  Text(
                    'EVENT TYPE',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF8E8E93),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2C2C2E)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<HistoryEventType>(
                        value: selectedType,
                        dropdownColor: const Color(0xFF141414),
                        isExpanded: true,
                        style: GoogleFonts.inter(color: Colors.white),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedType = val;
                              if (val == HistoryEventType.crashDetected) {
                                statusController.text =
                                    'DISPATCHED TO 2 CONTACTS';
                                detailsController.text =
                                    'Peak Impact Force: 5.2G | GPS Transmitted';
                              } else if (val == HistoryEventType.sosTriggered) {
                                statusController.text = 'MANUAL SOS PANIC';
                                detailsController.text =
                                    'Handlebar panic button engaged by rider';
                              } else if (val == HistoryEventType.sosCancelled) {
                                statusController.text = 'CANCELLED BY USER PIN';
                                detailsController.text =
                                    'Safe countdown cancelled by PIN authorization';
                              } else if (val ==
                                  HistoryEventType.helmetConnected) {
                                statusController.text = 'BLUETOOTH LINK OK';
                                detailsController.text =
                                    'ESP32 Module paired | Battery: 100%';
                              } else if (val ==
                                  HistoryEventType.helmetDisconnected) {
                                statusController.text = 'BLE LINK TERMINATED';
                                detailsController.text =
                                    'Disconnection detected | Safe idle mode';
                              } else if (val ==
                                  HistoryEventType.ridingSession) {
                                statusController.text = 'SESSION COMPLETED';
                                detailsController.text =
                                    'Distance: 18.2 km | Avg Speed: 46 km/h';
                              }
                            });
                          }
                        },
                        items: HistoryEventType.values.map((type) {
                          final dummy = HistoryModel(
                            id: '0',
                            eventType: type,
                            dateTime: DateTime.now(),
                            status: '',
                            details: '',
                          );
                          return DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(
                                  dummy.icon,
                                  color: dummy.accentColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  dummy.typeLabel,
                                  style: GoogleFonts.spaceGrotesk(fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  Text(
                    'LOCATION NAME',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF8E8E93),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: _inputDecoration('e.g. Ring Road, Bengaluru'),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  Text(
                    'STATUS SUMMARY',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF8E8E93),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: statusController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: _inputDecoration('e.g. DISPATCHED / COMPLETED'),
                  ),
                  const SizedBox(height: 16),

                  // Details
                  Text(
                    'EVENT TELEMETRY / DETAILS',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF8E8E93),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailsController,
                    maxLines: 2,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: _inputDecoration('Detailed notes'),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: () async {
                      final newEvent = HistoryModel(
                        id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
                        eventType: selectedType,
                        dateTime: DateTime.now(),
                        latitude: 12.9716,
                        longitude: 77.5946,
                        locationName: locationController.text.trim(),
                        status: statusController.text.trim().toUpperCase(),
                        details: detailsController.text.trim(),
                      );
                      await _historyService.logEvent(newEvent);
                      Navigator.pop(context);
                      await _loadHistoryData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE82127),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'SAVE TO LOCAL LOGS',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0D0D0D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE82127), width: 1.5),
      ),
    );
  }

  void _showEventDetailModal(HistoryModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: event.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: event.accentColor, width: 1.5),
                  ),
                  child: Icon(event.icon, color: event.accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.typeLabel,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(event.dateTime),
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF8E8E93),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: event.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    event.status,
                    style: GoogleFonts.jetBrainsMono(
                      color: event.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Location Box
            if (event.locationName != null || event.latitude != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFE82127),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.locationName ?? 'GPS Position Captured',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.latitude != null && event.longitude != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'LAT: ${event.latitude!.toStringAsFixed(4)}° N | LNG: ${event.longitude!.toStringAsFixed(4)}° E',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF8E8E93),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Details Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TELEMETRY LOG DETAILS',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF8E8E93),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.details.isNotEmpty
                        ? event.details
                        : 'No additional details logged.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteEvent(event);
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFE82127),
                      size: 18,
                    ),
                    label: Text(
                      'DELETE LOG',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFE82127),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE82127)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'CLOSE',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = monthNames[dt.month - 1];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month, $hour:$minute $ampm';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    final crashCount = _allEvents
        .where((e) => e.eventType == HistoryEventType.crashDetected)
        .length;
    final rideCount = _allEvents
        .where((e) => e.eventType == HistoryEventType.ridingSession)
        .length;

    final colors = AppColors.of(context);
    final Widget mainContent = Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 650 : double.infinity,
        ),
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE82127),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),

                      // Top Sub-Header Bar with Clear Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E5FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'HISTORICAL TELEMETRY LOGS',
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFF00E5FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_allEvents.isNotEmpty)
                            GestureDetector(
                              onTap: _clearAllHistory,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_sweep_rounded,
                                    color: colors.textSecondary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'CLEAR ALL',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: colors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Metrics KPI bar
                      _buildSummaryKpiBar(
                        _allEvents.length,
                        crashCount,
                        rideCount,
                      ),
                      const SizedBox(height: 16),

                      // Filter chips bar
                      _buildFilterChipsBar(),
                      const SizedBox(height: 16),

                      // Events list
                      Expanded(
                        child: _filteredEvents.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 120),
                                itemCount: _filteredEvents.length,
                                itemBuilder: (context, index) {
                                  final event = _filteredEvents[index];
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.0, end: 1.0),
                                    duration: Duration(
                                      milliseconds: 150 + (index * 80),
                                    ),
                                    builder: (context, value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, (1.0 - value) * 15),
                                        child: Opacity(
                                          opacity: value,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _buildHistoryCard(event),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );

    return Stack(
      children: [
        mainContent,
        Positioned(
          right: 16,
          bottom: 84,
          child: FloatingActionButton.extended(
            onPressed: _showAddEventDialog,
            backgroundColor: const Color(0xFFE82127),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: Text(
              'LOG TEST EVENT',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryKpiBar(int total, int crashes, int rides) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildKpiItem('TOTAL LOGS', '$total', Colors.white)),
          Container(width: 1, height: 30, color: const Color(0xFF2C2C2E)),
          Expanded(child: _buildKpiItem('CRASHES', '$crashes', const Color(0xFFE82127))),
          Container(width: 1, height: 30, color: const Color(0xFF2C2C2E)),
          Expanded(child: _buildKpiItem('RIDES', '$rides', const Color(0xFF30D158))),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF8E8E93),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChipsBar() {
    final filters = ['ALL', 'CRASHES', 'SOS ALERTS', 'SESSIONS', 'BLE LINK'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                f,
                style: GoogleFonts.jetBrainsMono(
                  color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFE82127),
              backgroundColor: const Color(0xFF141414),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFE82127)
                    : const Color(0xFF2C2C2E),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _applyFilter(f));
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                color: Color(0xFFE82127),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No History Events Found',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'ALL'
                  ? 'All crash events, SOS triggers, BLE connections, and riding sessions will appear here.'
                  : 'No logs match the "$_selectedFilter" filter criteria.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF8E8E93),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _showAddEventDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('CREATE SIMULATED LOG'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE82127),
                side: const BorderSide(color: Color(0xFFE82127)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(HistoryModel event) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEventDetailModal(event),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Type, Icon & Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: event.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: event.accentColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        event.icon,
                        color: event.accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.typeLabel,
                            style: GoogleFonts.spaceGrotesk(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimestamp(event.dateTime),
                            style: GoogleFonts.jetBrainsMono(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: event.accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        event.status,
                        style: GoogleFonts.jetBrainsMono(
                          color: event.accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Middle Row: Location (if present)
                if (event.locationName != null &&
                    event.locationName!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF8E8E93),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.locationName!,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Bottom Details text
                Text(
                  event.details,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8E8E93),
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
