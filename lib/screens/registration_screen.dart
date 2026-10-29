import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/mock_backend.dart';
import '../services/psgc_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_layout.dart';
import '../widgets/searchable_address_picker.dart';

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

  // Hubs
  static const List<Map<String, dynamic>> _fallbackHubs = [
    {'id': 1, 'name': 'Sta Cruz Hub', 'branch': 'Santa Cruz', 'city': 'Santa Cruz'},
    {'id': 2, 'name': 'Pila Hub', 'branch': 'Pila', 'city': 'Pila'},
    {'id': 3, 'name': 'Main Hub', 'branch': 'Main', 'city': 'Main'},
  ];
  List<Map<String, dynamic>> _hubs = List.from(_fallbackHubs);
  int? _selectedHubId;
  bool _hubsLoading = false;

  String vehicle = 'Motorcycle';
  String sex = 'Select sex';

  // Address PSGC locations & state
  List<PsgcLocation> _provinces = [];
  List<PsgcLocation> _cities = [];
  List<PsgcLocation> _barangays = [];

  PsgcLocation? _selectedProvince;
  PsgcLocation? _selectedCity;
  PsgcLocation? _selectedBarangay;

  bool _loadingProvinces = false;
  bool _loadingCities = false;
  bool _loadingBarangays = false;

  String? _provinceError;
  String? _cityError;
  String? _barangayError;

  String? licensePhotoBase64;
  String? licensePhotoName;
  String? orCrPhotoBase64;
  String? orCrPhotoName;

  @override
  void initState() {
    super.initState();
    _fetchHubs();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _loadingProvinces = true;
      _provinceError = null;
    });
    try {
      final list = await PsgcService.instance.getProvinces();
      if (mounted) {
        setState(() {
          _provinces = list;
          _loadingProvinces = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _provinceError = 'Could not load provinces. Tap to retry.';
          _loadingProvinces = false;
        });
      }
    }
  }

  Future<void> _onProvinceSelected(PsgcLocation province) async {
    if (_selectedProvince == province) return;
    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _selectedBarangay = null;
      _cities = [];
      _barangays = [];
      _cityError = null;
      _barangayError = null;
      _loadingCities = true;
      if (registrationError != null) registrationError = null;
    });

    try {
      final list = await PsgcService.instance.getCitiesMunicipalities(province);
      if (mounted) {
        setState(() {
          _cities = list;
          _loadingCities = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cityError = e.toString().replaceFirst('Exception: ', '');
          _loadingCities = false;
        });
      }
    }
  }

  Future<void> _onCitySelected(PsgcLocation city) async {
    if (_selectedCity == city) return;
    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      _barangays = [];
      _barangayError = null;
      _loadingBarangays = true;
      if (registrationError != null) registrationError = null;
    });

    try {
      final list = await PsgcService.instance.getBarangays(city);
      if (mounted) {
        setState(() {
          _barangays = list;
          _loadingBarangays = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _barangayError = e.toString().replaceFirst('Exception: ', '');
          _loadingBarangays = false;
        });
      }
    }
  }

  void _onBarangaySelected(PsgcLocation brgy) {
    setState(() {
      _selectedBarangay = brgy;
      if (registrationError != null) registrationError = null;
    });
  }

  Future<void> _fetchHubs() async {
    try {
      final hubs = await ApiService.instance.getHubs()
          .timeout(const Duration(seconds: 8));
      if (hubs.isNotEmpty && mounted) {
        setState(() {
          _hubs = hubs;
        });
      }
    } catch (_) {
      // Retains _fallbackHubs so all hubs are always available
    }
  }

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

  Future<void> _promptOtpAndRegister(
    BuildContext context,
    String fullName,
    String email,
  ) async {
    final otpController = TextEditingController();
    bool isVerifying = false;
    bool isResending = false;
    String? otpError;
    int cooldown = 60;
    Timer? timer;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (cooldown > 0) {
                setModalState(() => cooldown--);
              } else {
                t.cancel();
              }
            });

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header icon and title
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.blush1,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            color: AppColors.orange,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verify Your Gmail',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.plum,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Enter the 6-digit OTP code',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.muted),
                          onPressed: () => Navigator.of(bottomSheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Explanatory banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.blush1,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.plum,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(text: 'We sent a 6-digit code to '),
                            TextSpan(
                              text: email,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: '. Please check your inbox or spam folder.'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // OTP input field
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                        color: AppColors.plum,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '------',
                        hintStyle: GoogleFonts.sourceCodePro(
                          fontSize: 28,
                          letterSpacing: 10,
                          color: AppColors.muted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.orange, width: 2),
                        ),
                      ),
                    ),

                    if (otpError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        otpError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.errorBoxText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Verify and Submit button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isVerifying
                            ? null
                            : () async {
                                final code = otpController.text.trim();
                                if (code.length < 6) {
                                  setModalState(() {
                                    otpError = 'Please enter the complete 6-digit code';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isVerifying = true;
                                  otpError = null;
                                });

                                try {
                                  // Verify OTP with Laravel backend
                                  await ApiService.instance.verifyOtp(email, code);

                                  // Submit full registration
                                  await MockBackend().submitRegistration({
                                    'name': fullName,
                                    'fullName': fullName,
                                    'email': email,
                                    'phone': phoneController.text.trim(),
                                    'password': passwordController.text.trim(),
                                    'province': _selectedProvince?.name ?? '',
                                    'municipality': _selectedCity?.name ?? '',
                                    'barangay': _selectedBarangay?.name ?? '',
                                    'street': streetController.text.trim(),
                                    'vehicle': vehicle,
                                    'license_number': plateController.text.trim(),
                                    'license_photo': licensePhotoBase64 ?? '',
                                    'or_cr_photo': orCrPhotoBase64 ?? '',
                                    'otp': code,
                                    if (_selectedHubId != null) 'hub_id': _selectedHubId,
                                  });

                                  timer?.cancel();
                                  if (context.mounted) {
                                    Navigator.of(bottomSheetContext).pop();
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email verified & application submitted! Awaiting hub approval. You will receive an email once approved.',
                                        ),
                                        backgroundColor: AppColors.plum,
                                        duration: Duration(seconds: 5),
                                      ),
                                    );
                                    widget.onSubmitted();
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    isVerifying = false;
                                    otpError = e.toString().replaceFirst('Exception: ', '');
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.plum,
                          foregroundColor: AppColors.cream,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        child: isVerifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.cream,
                                ),
                              )
                            : const Text('Verify & Submit Registration'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Resend button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code? ",
                          style: GoogleFonts.inter(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: cooldown > 0 || isResending
                              ? null
                              : () async {
                                  setModalState(() {
                                    isResending = true;
                                    otpError = null;
                                  });
                                  try {
                                    await ApiService.instance.sendOtp(
                                      email,
                                      name: fullName,
                                    );
                                    setModalState(() {
                                      isResending = false;
                                      cooldown = 60;
                                    });
                                  } catch (e) {
                                    setModalState(() {
                                      isResending = false;
                                      otpError = e.toString().replaceFirst('Exception: ', '');
                                    });
                                  }
                                },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            cooldown > 0 ? 'Resend in ${cooldown}s' : 'Resend Code',
                            style: GoogleFonts.inter(
                              color: cooldown > 0 ? AppColors.muted : AppColors.orange,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    timer?.cancel();
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
            SearchableAddressPicker(
              label: 'Province / Administrative Area *',
              hint: 'Search & select province',
              selectedLocation: _selectedProvince,
              items: _provinces,
              isLoading: _loadingProvinces,
              errorMessage: _provinceError,
              onRetry: _loadProvinces,
              onSelected: _onProvinceSelected,
            ),
            SearchableAddressPicker(
              label: 'Municipality / City *',
              hint: _selectedProvince == null
                  ? 'Select province first'
                  : 'Search & select municipality or city',
              selectedLocation: _selectedCity,
              items: _cities,
              isEnabled: _selectedProvince != null,
              disabledReason: 'Please select a Province / Administrative Area first.',
              isLoading: _loadingCities,
              errorMessage: _cityError,
              onRetry: () => _selectedProvince != null ? _onProvinceSelected(_selectedProvince!) : null,
              onSelected: _onCitySelected,
            ),
            SearchableAddressPicker(
              label: 'Barangay *',
              hint: _selectedCity == null
                  ? 'Select municipality / city first'
                  : 'Search & select barangay',
              selectedLocation: _selectedBarangay,
              items: _barangays,
              isEnabled: _selectedCity != null,
              disabledReason: 'Please select a Municipality / City first.',
              isLoading: _loadingBarangays,
              errorMessage: _barangayError,
              onRetry: () => _selectedCity != null ? _onCitySelected(_selectedCity!) : null,
              onSelected: _onBarangaySelected,
            ),
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
            // Hub selection
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign to Hub *',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.plum,
                    ),
                  ),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<int>(
                    value: _selectedHubId,
                    isExpanded: true,
                    hint: Text(
                      'Select hub',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
                    ),
                    items: _hubs.map((hub) => DropdownMenuItem<int>(
                      value: hub['id'] as int,
                      child: Text(
                        hub['name'] as String,
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.plum),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedHubId = val),
                    validator: (val) => val == null ? 'Please select a hub' : null,
                  ),
                ],
              ),
            ),
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
                          if (_selectedProvince == null) {
                            setState(() {
                              registrationError = 'Please search and select your Province / Administrative Area.';
                            });
                            return;
                          }
                          if (_selectedCity == null) {
                            setState(() {
                              registrationError = 'Please search and select your Municipality / City.';
                            });
                            return;
                          }
                          if (_selectedBarangay == null) {
                            setState(() {
                              registrationError = 'Please search and select your Barangay.';
                            });
                            return;
                          }

                          setState(() {
                            isSubmitting = true;
                            registrationError = null;
                          });

                          final fullName = '${firstNameController.text.trim()} ${lastNameController.text.trim()}'.trim();
                          final email = emailController.text.trim();

                          try {
                            // 1. Request 6-digit OTP code sent to Gmail
                            await ApiService.instance.sendOtp(
                              email,
                              name: fullName,
                            );

                            if (!mounted) return;
                            setState(() {
                              isSubmitting = false;
                            });

                            // 2. Open OTP verification sheet to enter code
                            await _promptOtpAndRegister(
                              context,
                              fullName,
                              email,
                            );
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
              'After submitting, please wait for hub approval. The result will be sent to your Gmail.',
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
