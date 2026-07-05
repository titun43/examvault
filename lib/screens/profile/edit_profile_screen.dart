// =============================================================================
// ExamVault - Edit Profile Screen
// Lets the user edit: profile photo, name, DOB, gender, qualification, city,
// and target exam. DOB/gender/qualification/city/targetExam are stored in the
// user's Firestore `preferences` map (DOB as a Timestamp). Photo URL is stored
// at the top-level `photoUrl` field. Email/phone are shown read-only.
// =============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _qualificationCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _targetExamCtrl;
  late final TextEditingController _dobCtrl;

  String? _photoUrl;
  DateTime? _dateOfBirth;
  String? _gender;

  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    final user = _currentUser;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _phoneCtrl = TextEditingController(text: user?.phoneNumber ?? '');
    _qualificationCtrl =
        TextEditingController(text: user?.qualification ?? '');
    _cityCtrl = TextEditingController(text: user?.city ?? '');
    _targetExamCtrl = TextEditingController(text: user?.targetExam ?? '');
    _dateOfBirth = user?.dateOfBirth;
    _gender = user?.gender;
    _photoUrl = user?.photoUrl;
    _dobCtrl = TextEditingController(text: _formatDate(_dateOfBirth));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _qualificationCtrl.dispose();
    _cityCtrl.dispose();
    _targetExamCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  UserModel? get _currentUser =>
      Provider.of<AuthProvider>(context, listen: false).user;

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 20);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your date of birth',
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dobCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_currentUser == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      // Upload to user_avatars/{userId}/photo.jpg — this path is allowed by
      // the EXISTING storage rules (user_avatars/{userId}/{fileName} where
      // write: if isOwner(userId)). The user_photos path would require a
      // storage rules redeploy, so we use the already-allowed path.
      // Reuse the same filename each time so the user doesn't accumulate
      // orphaned files in Storage.
      final ref = FirebaseService.storage
          .ref()
          .child('user_avatars')
          .child(_currentUser!.id)
          .child('photo.jpg');
      if (kIsWeb) {
        final bytes = await xfile.readAsBytes();
        await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(xfile.path));
      }
      final url = await ref.getDownloadURL();
      if (mounted) {
        setState(() {
          _photoUrl = url;
          _isUploadingPhoto = false;
        });
      }
    } catch (e) {
      // Storage rules may block user uploads. Per spec: keep the existing
      // photo and don't block the save — just show a non-blocking SnackBar.
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not upload photo. Your existing photo will be kept.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    final preferences = <String, dynamic>{};
    // Always write the preference keys (even if empty) so the user can clear
    // a previously-set value by deleting the field text.
    preferences['gender'] = _gender;
    preferences['qualification'] = _qualificationCtrl.text.trim();
    preferences['city'] = _cityCtrl.text.trim();
    preferences['targetExam'] = _targetExamCtrl.text.trim();
    if (_dateOfBirth != null) {
      preferences['dateOfBirth'] = _dateOfBirth;
    }

    try {
      await AuthService.updateProfileExtended(
        userId: user.id,
        name: _nameCtrl.text.trim(),
        photoUrl: _photoUrl,
        preferences: preferences,
      );
      // Refresh the AuthProvider so the new values show up immediately.
      if (!mounted) return;
      await Provider.of<AuthProvider>(context, listen: false).loadUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailReadOnly = (_emailCtrl.text.trim().isNotEmpty);
    final phoneReadOnly = (_phoneCtrl.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile photo
              Center(
                child: GestureDetector(
                  onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: AppTheme.primaryColor
                                .withOpacity(0.15),
                            child: _isUploadingPhoto
                                ? const CircularProgressIndicator()
                                : (_photoUrl != null &&
                                        _photoUrl!.isNotEmpty)
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: _photoUrl!,
                                          fit: BoxFit.cover,
                                          width: 112,
                                          height: 112,
                                          placeholder: (_, __) =>
                                              const CircularProgressIndicator(),
                                          errorWidget: (_, __, ___) =>
                                              const Icon(Icons.person,
                                                  size: 56,
                                                  color: AppTheme.primaryColor),
                                        ),
                                      )
                                    : const Icon(Icons.person,
                                        size: 56,
                                        color: AppTheme.primaryColor),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _isUploadingPhoto
                                ? null
                                : _pickAndUploadPhoto,
                            child: Text(
                              'Change Photo',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Show Remove button only when a photo is set.
                          // Tap → clear local _photoUrl; on save the null
                          // value is written back to Firestore so the avatar
                          // reverts to the default person icon.
                          if (_photoUrl != null &&
                              _photoUrl!.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isUploadingPhoto
                                  ? null
                                  : () {
                                      setState(() => _photoUrl = null);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Photo removed. Tap Save to confirm.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                              child: Text(
                                'Remove',
                                style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (read-only if already set)
              TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: emailReadOnly
                      ? const Icon(Icons.lock_outline, size: 18)
                      : null,
                  helperText: emailReadOnly
                      ? 'Email cannot be changed'
                      : null,
                ),
                readOnly: emailReadOnly,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Phone (read-only)
              TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: phoneReadOnly
                      ? const Icon(Icons.lock_outline, size: 18)
                      : null,
                  helperText: phoneReadOnly
                      ? 'Phone cannot be changed'
                      : null,
                ),
                readOnly: phoneReadOnly,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Date of Birth (date picker)
              TextFormField(
                controller: _dobCtrl,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                readOnly: true,
                onTap: _pickDateOfBirth,
                validator: (_) => null,
              ),
              const SizedBox(height: 16),

              // Gender dropdown
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
                items: _genderOptions
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v),
                hint: const Text('Select gender'),
              ),
              const SizedBox(height: 16),

              // Qualification
              TextFormField(
                controller: _qualificationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Qualification',
                  hintText: 'e.g. B.Tech, BA, 12th Pass',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // City/Town
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'City / Town',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Target Exam
              TextFormField(
                controller: _targetExamCtrl,
                decoration: const InputDecoration(
                  labelText: 'Target Exam',
                  hintText: 'e.g. SSC CGL, Railway NTPC',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // Save button (also in AppBar — this one is more prominent)
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              ),
              const SizedBox(height: 8),
              Text(
                'Your profile photo is stored securely on Firebase Storage. '
                'Other details are saved to your account preferences.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
