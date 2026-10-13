import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/ble_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';
import '../widgets/add_contact_dialog.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with AutomaticKeepAliveClientMixin {
  final ContactService _contactService = ContactService();
  List<ContactModel> _contacts = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });
    final contacts = await _contactService.loadContacts();
    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
  }

  Future<void> _saveContacts() async {
    // Sort before saving to maintain priority order
    _contacts.sort((a, b) => a.priority.compareTo(b.priority));
    await _contactService.saveContacts(_contacts);
    setState(() {});
  }

  void _addContact() async {
    if (_contacts.length >= 5) {
      _showErrorSnackBar('Maximum 5 emergency contacts allowed.');
      return;
    }

    final result = await showDialog<ContactModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AddContactDialog(existingContacts: _contacts),
    );

    if (result != null) {
      setState(() {
        _contacts.add(result);
      });
      await _saveContacts();
      _showSuccessSnackBar('Contact "${result.name}" added successfully.');
    }
  }

  void _editContact(ContactModel contact) async {
    final result = await showDialog<ContactModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          AddContactDialog(contactToEdit: contact, existingContacts: _contacts),
    );

    if (result != null) {
      final index = _contacts.indexWhere((c) => c.id == contact.id);
      if (index != -1) {
        setState(() {
          _contacts[index] = result;
        });
        await _saveContacts();
        _showSuccessSnackBar('Contact updated successfully.');
      }
    }
  }

  void _deleteContact(ContactModel contact) async {
    final confirmed = await _showDeleteConfirmation(contact.name);
    if (confirmed) {
      setState(() {
        _contacts.removeWhere((c) => c.id == contact.id);
      });
      await _saveContacts();
      _showSuccessSnackBar(
        'Removed "${contact.name}" from emergency contacts.',
      );
    }
  }

  Future<bool> _showDeleteConfirmation(String name) async {
    final colors = AppColors.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: colors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.cardBorder, width: 1.5),
              ),
              title: Text(
                'DELETE CONTACT',
                style: GoogleFonts.spaceGrotesk(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              content: Text(
                'Are you sure you want to remove $name from your Emergency Contacts list?',
                style: GoogleFonts.inter(
                  color: colors.textSecondary,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.jetBrainsMono(
                      color: colors.textSecondary,
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
                    'REMOVE',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _syncToHelmet() async {
    // Current behaviour required: Show a SnackBar "Helmet Sync Coming Soon"
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.bluetooth_searching_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Helmet Sync Coming Soon',
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE82127),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );

    // Prepare architecture simulation
    await _contactService.syncContactsToHelmet(_contacts);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF00C853),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141414),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF34A853), width: 1),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE82127),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141414),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFE82127), width: 1),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 600 : double.infinity,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00E5FF),
                      ),
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
                    children: [
                      const SizedBox(height: 8),

                      // Top Sub-Header Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00E676)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00E676),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'RF MATRIX ARMED',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: const Color(0xFF00E676),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.innerContainerBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.cardBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.link_rounded, color: Color(0xFF00E5FF), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'E-911 SYNC: LATCHED',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: const Color(0xFF00E5FF),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Capacity Header Card (Image 3)
                      _buildCapacityHeader(colors),
                      const SizedBox(height: 16),

                      // Registered Responders Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Registered Responders',
                            style: GoogleFonts.spaceGrotesk(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'TIER ESCALATION',
                            style: GoogleFonts.jetBrainsMono(
                              color: colors.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Contact Cards
                      if (_contacts.isEmpty)
                        _buildEmptyState(colors)
                      else
                        ..._contacts.map((contact) => _buildContactCard(contact, colors)),

                      const SizedBox(height: 14),

                      // Local 911 / Roadside Card
                      _buildRoadsideCard(colors),
                      const SizedBox(height: 14),

                      // Registered Helmet Profile
                      _buildHelmetProfileCard(colors),
                      const SizedBox(height: 20),

                      // Sticky Action Footer Buttons
                      _buildSyncFooter(colors),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }

  Widget _buildCapacityHeader(AppColors colors) {
    final count = _contacts.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.cell_tower_rounded,
                      color: Color(0xFF00E5FF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rescue Transmitter Tiers',
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.innerContainerBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count OF 5 SECURED',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF00E5FF),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: List.generate(5, (index) {
                        final isFilled = index < count;
                        return Container(
                          margin: const EdgeInsets.only(left: 2),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isFilled
                                ? const Color(0xFF00E5FF)
                                : colors.textSecondary.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'PRIORITY CHAIN ARCHITECTURE',
            style: GoogleFonts.jetBrainsMono(
              color: const Color(0xFF00E5FF),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Emergency coordinates & real-time audio telemetry broadcast to registered tiers sequentially during verified impact events.',
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.innerContainerBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  BleService.instance.isConnected ? Icons.memory_rounded : Icons.memory_outlined,
                  color: BleService.instance.isConnected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    BleService.instance.isConnected
                        ? 'Transceiver On-Chip Buffer 40% Stored'
                        : 'Transceiver Disconnected • Helmet Offline',
                    style: GoogleFonts.jetBrainsMono(
                      color: BleService.instance.isConnected ? const Color(0xFF00E676) : const Color(0xFFFF7A59),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.innerContainerBackground,
              shape: BoxShape.circle,
              border: Border.all(color: colors.cardBorder),
            ),
            child: const Icon(
              Icons.person_add_disabled_outlined,
              color: Color(0xFF00E5FF),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Rescue Contacts Registered',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add emergency contacts with relative priorities to enable multi-tiered SOS broadcasting.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(ContactModel contact, AppColors colors) {
    final initials = contact.name.trim().isNotEmpty
        ? contact.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'ICE';

    final isTier1 = contact.priority == 1 || contact.isPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTier1 ? const Color(0xFFFF5E3A).withValues(alpha: 0.5) : colors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar circle with initials
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.innerContainerBackground,
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (contact.isPrimary)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF7A59),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star, color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Detail list
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.name,
                            style: GoogleFonts.spaceGrotesk(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.innerContainerBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            contact.relation.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              color: colors.textSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isTier1 ? const Color(0xFFE52E2E) : colors.innerContainerBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '• TIER ${contact.priority}',
                            style: GoogleFonts.jetBrainsMono(
                              color: isTier1 ? Colors.white : colors.textSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.phoneNumber,
                      style: GoogleFonts.jetBrainsMono(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Protocol Box inside card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.innerContainerBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  isTier1 ? Icons.record_voice_over_rounded : Icons.chat_outlined,
                  color: const Color(0xFF00E5FF),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTier1 ? 'SMS & Voice Synthesis' : 'SMS with Live Location Track',
                        style: GoogleFonts.jetBrainsMono(
                          color: colors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isTier1
                            ? 'Automated call playback of GPS telemetry & rider status'
                            : 'Google Maps payload with crash speed & helmet battery',
                        style: GoogleFonts.inter(
                          color: colors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Row (Test Signal, Edit, Delete)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Simulated Test Signal sent to ${contact.name}',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: colors.cardBackground,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.cell_tower_rounded, size: 14),
                label: Text(
                  'TEST SIGNAL',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF00E5FF)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: colors.textSecondary, size: 18),
                onPressed: () => _editContact(contact),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE52E2E), size: 18),
                onPressed: () => _deleteContact(contact),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoadsideCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE52E2E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.medical_services_rounded, color: Color(0xFFE52E2E), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Local 911 / Roadside',
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF00E676),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'UNACKNOWLEDGED IMPACT PROTOCOL',
            style: GoogleFonts.jetBrainsMono(
              color: colors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.innerContainerBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FORCE THRESHOLD OVERRIDE > 6.0G AUTO-DISPATCH',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFFFF7A59),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'If crash verification countdown (30s) expires without manual rider override, encrypted medical profile and telemetry dispatch directly to closest PSAP emergency dispatch.',
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelmetProfileCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REGISTERED HELMET PROFILE',
                  style: GoogleFonts.jetBrainsMono(
                    color: colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Airoh GP550 Transceiver',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'BT 5.3 + Sub-GHz Ready',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF00E5FF),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncFooter(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _syncToHelmet,
          icon: const Icon(Icons.sync_rounded),
          label: Text(
            'SYNC TO HELMET',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: const Color(0xFF070B14),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _addContact,
          icon: const Icon(Icons.person_add_outlined),
          label: Text(
            '+ Add Emergency Contact',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.cardBackground,
            foregroundColor: colors.textPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.cardBorder),
            ),
          ),
        ),
      ],
    );
  }
}
