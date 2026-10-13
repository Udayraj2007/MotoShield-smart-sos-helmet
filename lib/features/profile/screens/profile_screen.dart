import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();

  ProfileModel? _profile;

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;

  String _bloodGroup = '';

  final List<String> _bloodGroups = const [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _dobController = TextEditingController();

    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.createProfileIfNeeded();

      if (!mounted) return;

      setState(() {
        _profile = profile;

        _nameController.text = profile.fullName;
        _phoneController.text = profile.phone;
        _dobController.text = profile.dateOfBirth;
        _bloodGroup = profile.bloodGroup;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showSnackBar('Unable to load profile', isError: true);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _profileService.updateProfile(
        fullName: _nameController.text,
        phone: _phoneController.text,
        bloodGroup: _bloodGroup,
        dateOfBirth: _dobController.text,
      );

      final updatedProfile = await _profileService.getProfile();

      if (!mounted) return;

      setState(() {
        _profile = updatedProfile;
        _editing = false;
        _saving = false;
      });

      _showSnackBar('Profile updated successfully');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showSnackBar('Failed to update profile', isError: true);
    }
  }

  Future<void> _selectDate() async {
    final colors = AppColors.of(context);
    final now = DateTime.now();

    DateTime initialDate = DateTime(now.year - 20, now.month, now.day);

    if (_dobController.text.isNotEmpty) {
      try {
        final parts = _dobController.text.split('-');

        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (_) {}
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primaryAccent,
              surface: colors.cardBackground,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: colors.cardBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final formatted =
        '${selectedDate.year.toString().padLeft(4, '0')}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';

    setState(() {
      _dobController.text = formatted;
    });
  }

  Future<void> _logout() async {
    final colors = AppColors.of(context);
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.cardBorder),
          ),
          title: Text(
            'Logout',
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to logout from your profile?',
            style: GoogleFonts.inter(color: colors.textSecondary),
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
              child: Text(
                'LOGOUT',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFFF7A59),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await _profileService.logout();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteAccount() async {
    final colors = AppColors.of(context);
    final user = _profileService.currentUser;
    if (user == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.cardBorder),
          ),
          title: Text(
            'Delete Account',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete your account? This action cannot be undone and will erase all your data.',
            style: GoogleFonts.inter(color: colors.textSecondary),
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
              child: Text(
                'PROCEED',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final isPasswordUser =
        user.providerData.any((p) => p.providerId == 'password');
    final isGoogleUser =
        user.providerData.any((p) => p.providerId == 'google.com');

    if (isPasswordUser) {
      final password = await _showPasswordPromptDialog(colors);
      if (password == null || password.trim().isEmpty) return;

      setState(() {
        _saving = true;
      });

      try {
        await _profileService.reauthenticateWithPassword(password);
        await _profileService.deleteAccount();
        if (!mounted) return;
        _showSnackBar('Account deleted successfully');
        Navigator.of(context).popUntil((route) => route.isFirst);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _showSnackBar(
            'Incorrect password. Account deletion cancelled.',
            isError: true,
          );
        } else {
          _showSnackBar('Error: ${e.message}', isError: true);
        }
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Failed to delete account: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() {
            _saving = false;
          });
        }
      }
    } else if (isGoogleUser) {
      setState(() {
        _saving = true;
      });

      try {
        await _profileService.reauthenticateWithGoogle();
        await _profileService.deleteAccount();
        if (!mounted) return;
        _showSnackBar('Account deleted successfully');
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Google re-authentication failed: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() {
            _saving = false;
          });
        }
      }
    } else {
      setState(() {
        _saving = true;
      });

      try {
        await _profileService.deleteAccount();
        if (!mounted) return;
        _showSnackBar('Account deleted successfully');
        Navigator.of(context).popUntil((route) => route.isFirst);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        if (e.code == 'requires-recent-login') {
          _showSnackBar(
            'Please log out and log in again to delete your account.',
            isError: true,
          );
        } else {
          _showSnackBar('Error: ${e.message}', isError: true);
        }
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Failed to delete account: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() {
            _saving = false;
          });
        }
      }
    }
  }

  Future<String?> _showPasswordPromptDialog(AppColors colors) async {
    final controller = TextEditingController();
    bool obscure = true;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.cardBorder),
              ),
              title: Text(
                'Re-authenticate',
                style: GoogleFonts.spaceGrotesk(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your account password to verify your identity and delete your account.',
                    style: GoogleFonts.inter(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: colors.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                          color: colors.textSecondary,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscure = !obscure;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.primaryAccent),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.jetBrainsMono(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: Text(
                    'CONFIRM DELETE',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFFFF7A59)
            : colors.cardBackground,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: colors.scaffoldBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.spaceGrotesk(
            color: colors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_loading)
            IconButton(
              onPressed: _saving
                  ? null
                  : () {
                      setState(() {
                        _editing = !_editing;
                      });
                    },
              icon: Icon(
                _editing ? Icons.close_rounded : Icons.edit_rounded,
                color: _editing ? colors.primaryAccent : colors.textPrimary,
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: colors.primaryAccent),
            )
          : RefreshIndicator(
              color: colors.primaryAccent,
              backgroundColor: colors.cardBackground,
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildProfileHeader(colors),
                      const SizedBox(height: 20),
                      _buildPersonalInformation(colors),
                      const SizedBox(height: 16),
                      _buildSafetyInformation(colors),
                      const SizedBox(height: 20),

                      if (_editing) ...[
                        _buildSaveButton(colors),
                        const SizedBox(height: 16),
                      ],

                      _buildAccountSection(colors),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(AppColors colors) {
    final photoUrl = _profile?.photoUrl ?? '';
    final name = _profile?.fullName.isNotEmpty == true
        ? _profile!.fullName
        : 'Smart Rider';

    final email = _profile?.email ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primaryAccent, width: 2),
                ),
                child: ClipOval(
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return SizedBox(
                              width: 96,
                              height: 96,
                              child: ColoredBox(color: colors.innerContainerBackground),
                            );
                          },
                        )
                      : SizedBox(
                          width: 96,
                          height: 96,
                          child: ColoredBox(color: colors.innerContainerBackground),
                        ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.primaryAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: colors.isDark ? Colors.black : Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.primaryAccentBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.primaryAccent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'PILOT PROFILE ACTIVE',
                  style: GoogleFonts.jetBrainsMono(
                    color: colors.primaryAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInformation(AppColors colors) {
    return _buildSection(
      colors: colors,
      title: 'PERSONAL INFORMATION',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          _buildTextField(
            colors: colors,
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.badge_outlined,
            enabled: _editing,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your name';
              }

              if (value.trim().length < 2) {
                return 'Name is too short';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildReadOnlyField(
            colors: colors,
            label: 'Email',
            value: _profile?.email ?? '',
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            colors: colors,
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            enabled: _editing,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter phone number';
              }

              final digits = value.replaceAll(RegExp(r'\D'), '');

              if (digits.length < 10) {
                return 'Enter a valid phone number';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildDateField(colors),
        ],
      ),
    );
  }

  Widget _buildSafetyInformation(AppColors colors) {
    return _buildSection(
      colors: colors,
      title: 'SAFETY INFORMATION',
      icon: Icons.health_and_safety_outlined,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _bloodGroups.contains(_bloodGroup)
                ? _bloodGroup
                : null,
            dropdownColor: colors.cardBackground,
            style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              colors,
              'Blood Group',
              Icons.bloodtype_outlined,
            ),
            items: _bloodGroups.map((group) {
              return DropdownMenuItem(value: group, child: Text(group));
            }).toList(),
            onChanged: _editing
                ? (value) {
                    setState(() {
                      _bloodGroup = value ?? '';
                    });
                  }
                : null,
          ),
          const SizedBox(height: 14),
          _buildInfoTile(
            colors: colors,
            icon: Icons.shield_outlined,
            title: 'Safety Profile',
            subtitle: 'Used for emergency response broadcasting',
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(AppColors colors) {
    return TextFormField(
      controller: _dobController,
      readOnly: true,
      enabled: _editing,
      onTap: _editing ? _selectDate : null,
      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
      decoration: _inputDecoration(
        colors,
        'Date of Birth',
        Icons.calendar_today_outlined,
      ).copyWith(
        suffixIcon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required AppColors colors,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
      decoration: _inputDecoration(colors, label, icon),
    );
  }

  Widget _buildReadOnlyField({
    required AppColors colors,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 14),
      decoration: _inputDecoration(colors, label, icon).copyWith(
        suffixIcon: Icon(
          Icons.lock_outline_rounded,
          color: colors.textSecondary,
          size: 18,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(AppColors colors, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: colors.textSecondary,
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: colors.textSecondary, size: 19),
      filled: true,
      fillColor: colors.innerContainerBackground,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.cardBorder),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primaryAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF7A59)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF7A59)),
      ),
    );
  }

  Widget _buildSection({
    required AppColors colors,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primaryAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  color: colors.primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.innerContainerBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primaryAccent, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(AppColors colors) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryAccent,
          disabledBackgroundColor: colors.primaryAccent.withValues(alpha: 0.3),
          foregroundColor: colors.isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _saving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.isDark ? Colors.black : Colors.white,
                ),
              )
            : Text(
                'SAVE PROFILE',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildAccountSection(AppColors colors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5E3A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFFFF5E3A),
                size: 20,
              ),
            ),
            title: Text(
              'MotoShield Admin Web Portal',
              style: GoogleFonts.spaceGrotesk(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Accident analytics, live maps & road safety reports',
              style: GoogleFonts.inter(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AdminDashboardScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: colors.cardBorder),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A59).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFFF7A59),
                size: 20,
              ),
            ),
            title: Text(
              'Sign Out',
              style: GoogleFonts.spaceGrotesk(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Sign out from this device',
              style: GoogleFonts.inter(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
            onTap: _logout,
          ),
          Divider(height: 1, color: colors.cardBorder),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            title: Text(
              'Delete Account',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Permanently delete your account & data',
              style: GoogleFonts.inter(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
