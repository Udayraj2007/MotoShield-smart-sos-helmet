import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';

class AddContactDialog extends StatefulWidget {
  final ContactModel? contactToEdit;
  final List<ContactModel> existingContacts;

  const AddContactDialog({
    super.key,
    this.contactToEdit,
    required this.existingContacts,
  });

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _relationController;
  late int _selectedPriority;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.contactToEdit?.name ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.contactToEdit?.phoneNumber ?? '',
    );
    _relationController = TextEditingController(
      text: widget.contactToEdit?.relation ?? '',
    );
    _selectedPriority = widget.contactToEdit?.priority ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contactToEdit != null;

    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF2C2C2E), width: 1.5),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'EDIT CONTACT' : 'ADD EMERGENCY CONTACT',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 24),

                // Name Input
                Text(
                  'FULL NAME',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF8E8E93),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: _buildInputDecoration('Enter contact name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Phone Input
                Text(
                  'PHONE NUMBER (INDIAN MOBILE)',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF8E8E93),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  style: GoogleFonts.inter(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration('e.g. 9845012345'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (!ContactService.isValidIndianPhoneNumber(value)) {
                      return 'Enter a valid 10-digit Indian mobile number';
                    }

                    // Duplicate check
                    final normalized = ContactService.normalizePhoneNumber(
                      value,
                    );
                    final isDuplicate = widget.existingContacts.any(
                      (c) =>
                          c.id != widget.contactToEdit?.id &&
                          ContactService.normalizePhoneNumber(c.phoneNumber) ==
                              normalized,
                    );

                    if (isDuplicate) {
                      return 'This phone number is already registered';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Relation Input
                Text(
                  'RELATIONSHIP',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF8E8E93),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _relationController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: _buildInputDecoration(
                    'e.g. Spouse, Father, Friend',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Relationship is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Priority Selection (Tesla style horizontal selectors)
                Text(
                  'PRIORITY TIER',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF8E8E93),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    final priorityVal = index + 1;
                    final isSelected = _selectedPriority == priorityVal;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPriority = priorityVal;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFE82127)
                              : const Color(0xFF0D0D0D),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFE82127)
                                : const Color(0xFF2C2C2E),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFE82127,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            priorityVal.toString(),
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2C2C2E)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF8E8E93),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        style:
                            ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE82127),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ).copyWith(
                              overlayColor: WidgetStateProperty.all(
                                Colors.white12,
                              ),
                            ),
                        child: Text(
                          isEditing ? 'SAVE' : 'ADD',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF0D0D0D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorStyle: GoogleFonts.inter(
        color: const Color(0xFFE82127),
        fontSize: 11,
      ),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE82127)),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final rawPhone = _phoneController.text.trim();
      final relation = _relationController.text.trim();

      final normalizedPhone = ContactService.normalizePhoneNumber(rawPhone);

      final contact = ContactModel(
        id:
            widget.contactToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        phoneNumber: normalizedPhone,
        relation: relation,
        priority: _selectedPriority,
      );

      Navigator.pop(context, contact);
    }
  }
}
