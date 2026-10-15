import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../services/mock_backend.dart';
import '../widgets/auth_layout.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.onBack,
    required this.onLogin,
    required this.onSubmitted,
  });

  final VoidCallback onBack;
  final VoidCallback onLogin;
  final VoidCallback onSubmitted;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final key = GlobalKey<FormState>();

  final lastNameController = TextEditingController();
  final firstNameController = TextEditingController();
  final middleInitialController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final birthdayController = TextEditingController();
  final streetController = TextEditingController();
  final plateController = TextEditingController();

  bool isSubmitting = false;
  String? registrationError;

  String vehicle = 'Motorcycle';
  String sex = 'Select sex';
  String province = 'Metro Manila';
  String municipality = 'San Juan';
  String barangay = 'Addition Hills';

  String? licensePhotoBase64;
  String? licensePhotoName;
  String? orCrPhotoBase64;
  String? orCrPhotoName;

  @override
  void dispose() {
    lastNameController.dispose();
    firstNameController.dispose();
    middleInitialController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    birthdayController.dispose();
    streetController.dispose();
    plateController.dispose();
    super.dispose();
  }

  Widget field(
    String label, {
    String? hint,
    bool required = false,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label${required ? ' *' : ''}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.plum,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(color: AppColors.plum, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: required
                ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
                : null,
          ),
        ],
      ),
    );
  }

  Widget select(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.plum,
            ),
          ),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            style: GoogleFonts.inter(color: AppColors.plum, fontSize: 14),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: values
                .map<DropdownMenuItem<String>>(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.plum,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDocument({required bool isLicense}) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLicense ? 'Upload Driver’s License' : 'Upload Vehicle OR / CR',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.plum,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.orange),
                title: Text(
                  'Take Photo with Camera',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.plum),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.orange),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.plum),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      setState(() {
        if (isLicense) {
          licensePhotoBase64 = base64String;
          licensePhotoName = file.name;
        } else {
          orCrPhotoBase64 = base64String;
          orCrPhotoName = file.name;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not attach document: $e'),
            backgroundColor: AppColors.plum,
          ),
        );
      }
    }
  }

  Widget upload(String title, {required bool isLicense}) {
    final fileName = isLicense ? licensePhotoName : orCrPhotoName;
    final bool hasFile = fileName != null;

    return Card(
      color: hasFile ? const Color(0xFFF0FDF4) : AppColors.cream,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasFile ? const Color(0xFF86EFAC) : AppColors.inputBorder,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          hasFile ? Icons.check_circle : Icons.file_upload_outlined,
          color: hasFile ? const Color(0xFF16A34A) : AppColors.orange,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: AppColors.plum,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          hasFile ? 'Selected: $fileName' : 'Camera or Gallery (JPG, PNG) · Max 10 MB',
          style: GoogleFonts.inter(
            color: hasFile ? const Color(0xFF16A34A) : AppColors.muted,
            fontSize: 10,
            fontWeight: hasFile ? FontWeight.w600 : FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: hasFile
            ? IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                onPressed: () {
                  setState(() {
                    if (isLicense) {
                      licensePhotoBase64 = null;
                      licensePhotoName = null;
                    } else {
                      orCrPhotoBase64 = null;
                      orCrPhotoName = null;
                    }
                  });
                },
                tooltip: 'Remove',
              )
            : const Icon(
                Icons.add_circle_outline,
                color: AppColors.orange,
              ),
        onTap: () => _pickDocument(isLicense: isLicense),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Form(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top of form: small "← Back" text link
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '← ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.plum,
                        ),
                      ),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.plum,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Heading: Centered "Become a Rider courier" in Playfair Display
            Text(
              'Become a Rider courier',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: AppColors.plum,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Small gold ✦ between two thin lines
            const Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppColors.dividerLine,
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '✦',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AppColors.dividerLine,
                    thickness: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Muted subtitle
            Text(
              'Register your rider profile and start earning on your schedule.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Step progress
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              child: LinearProgressIndicator(
                value: 0.5,
                minHeight: 6,
                color: AppColors.orange,
                backgroundColor: AppColors.blush2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'STEP 1 OF 2  ·  RIDER DETAILS',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 22),

            field('Last name', hint: 'e.g. Rivera', required: true, controller: lastNameController),
            field('First name', hint: 'e.g. Alex', required: true, controller: firstNameController),
            Row(
              children: [
                Expanded(child: field('Middle initial', hint: 'A', controller: middleInitialController)),
                const SizedBox(width: 10),
                Expanded(
                  child: select('Sex *', sex, [
                    'Select sex',
                    'Male',
                    'Female',
                    'Prefer not to say',
                  ], (value) => setState(() => sex = value!)),
                ),
              ],
            ),
            field('E-mail', hint: 'you@example.com', required: true, controller: emailController, keyboardType: TextInputType.emailAddress),
            field('Contact no.', hint: '09XX XXX XXXX', required: true, controller: phoneController, keyboardType: TextInputType.phone),
            field('Password', hint: 'At least 6 characters', required: true, controller: passwordController, obscureText: true),
            Row(
              children: [
                Expanded(
                  child: field(
                    'Birthday',
                    hint: 'MM / DD / YYYY',
                    required: true,
                    controller: birthdayController,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: field('Age (autogen)', hint: '—')),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Address details',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.plum,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blush1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Province, municipality, and barangay are selected from the official list.',
                      style: GoogleFonts.inter(
                        color: AppColors.ink,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            select('Province *', province, [
              'Metro Manila',
              'Cavite',
              'Laguna',
              'Rizal',
            ], (value) => setState(() => province = value!)),
            select('Municipality *', municipality, [
              'San Juan',
              'Mandaluyong',
              'Quezon City',
              'Pasig',
            ], (value) => setState(() => municipality = value!)),
            select('Barangay *', barangay, [
              'Addition Hills',
              'Greenhills',
              'Wack-Wack',
              'Kapitolyo',
            ], (value) => setState(() => barangay = value!)),
            field(
              'Street, house no., etc.',
              hint: 'Enter complete address',
              required: true,
              controller: streetController,
            ),
            const SizedBox(height: 10),
            Text(
              'Vehicle & documents',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.plum,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            select('Choose vehicle *', vehicle, [
              'Motorcycle',
              'Tricycle',
            ], (value) => setState(() => vehicle = value!)),
            field(
              'Enter plate number',
              hint: 'ABC 1234',
              required: true,
              controller: plateController,
            ),
            upload('Upload OR / CR', isLicense: false),
            upload('Upload ID / driver’s license', isLicense: true),
            const SizedBox(height: 20),

            if (registrationError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.errorBoxBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.errorBoxBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppColors.errorBoxText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        registrationError!,
                        style: GoogleFonts.inter(
                          color: AppColors.errorBoxText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Submit registration button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (key.currentState?.validate() ?? false) {
                          setState(() {
                            isSubmitting = true;
                            registrationError = null;
                          });

                          final fullName = '${firstNameController.text.trim()} ${lastNameController.text.trim()}'.trim();

                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            await MockBackend().submitRegistration({
                              'name': fullName,
                              'fullName': fullName,
                              'email': emailController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'password': passwordController.text.trim(),
                              'province': province,
                              'municipality': municipality,
                              'barangay': barangay,
                              'vehicle': vehicle,
                              'license_number': plateController.text.trim(),
                              'license_photo': ?licensePhotoBase64,
                              'or_cr_photo': ?orCrPhotoBase64,
                            });

                            if (!mounted) return;

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Registration submitted! Awaiting administrator approval.',
                                ),
                                backgroundColor: AppColors.plum,
                                duration: Duration(seconds: 4),
                              ),
                            );

                            widget.onSubmitted();
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                isSubmitting = false;
                                registrationError = e.toString().replaceFirst('Exception: ', '');
                              });
                            }
                          }
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.arrow_forward, size: 18),
                label: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.cream,
                        ),
                      )
                    : const Text('Submit registration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.plum,
                  foregroundColor: AppColors.cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  elevation: 0,
                  textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'After submitting, please wait for administrative approval. The result will be sent to your email.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: widget.onLogin,
                child: Text(
                  'Already registered? Log in',
                  style: GoogleFonts.inter(
                    color: AppColors.plum,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
