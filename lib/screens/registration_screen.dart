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
  final ageController = TextEditingController();
  final streetController = TextEditingController();
  final plateController = TextEditingController();

  DateTime? _selectedBirthDate;

  bool isSubmitting = false;
  String? registrationError;

  // Hubs (All 30 Laguna Municipalities/Cities + Main Hub)
  static const List<Map<String, dynamic>> _fallbackHubs = [
    {'id': 1, 'name': 'Alaminos Hub', 'branch': 'Alaminos', 'city': 'Alaminos'},
    {'id': 2, 'name': 'Bay Hub', 'branch': 'Bay', 'city': 'Bay'},
    {'id': 3, 'name': 'Binan Hub', 'branch': 'Binan', 'city': 'Binan'},
    {'id': 4, 'name': 'Cabuyao Hub', 'branch': 'Cabuyao', 'city': 'Cabuyao'},
    {'id': 5, 'name': 'Calamba Hub', 'branch': 'Calamba', 'city': 'Calamba'},
    {'id': 6, 'name': 'Calauan Hub', 'branch': 'Calauan', 'city': 'Calauan'},
    {'id': 7, 'name': 'Cavinti Hub', 'branch': 'Cavinti', 'city': 'Cavinti'},
    {'id': 8, 'name': 'Famy Hub', 'branch': 'Famy', 'city': 'Famy'},
    {'id': 9, 'name': 'Kalayaan Hub', 'branch': 'Kalayaan', 'city': 'Kalayaan'},
    {'id': 10, 'name': 'Liliw Hub', 'branch': 'Liliw', 'city': 'Liliw'},
    {'id': 11, 'name': 'Los Banos Hub', 'branch': 'Los Banos', 'city': 'Los Banos'},
    {'id': 12, 'name': 'Luisiana Hub', 'branch': 'Luisiana', 'city': 'Luisiana'},
    {'id': 13, 'name': 'Lumban Hub', 'branch': 'Lumban', 'city': 'Lumban'},
    {'id': 14, 'name': 'Mabitac Hub', 'branch': 'Mabitac', 'city': 'Mabitac'},
    {'id': 15, 'name': 'Magdalena Hub', 'branch': 'Magdalena', 'city': 'Magdalena'},
    {'id': 16, 'name': 'Majayjay Hub', 'branch': 'Majayjay', 'city': 'Majayjay'},
    {'id': 17, 'name': 'Nagcarlan Hub', 'branch': 'Nagcarlan', 'city': 'Nagcarlan'},
    {'id': 18, 'name': 'Paete Hub', 'branch': 'Paete', 'city': 'Paete'},
    {'id': 19, 'name': 'Pagsanjan Hub', 'branch': 'Pagsanjan', 'city': 'Pagsanjan'},
    {'id': 20, 'name': 'Pakil Hub', 'branch': 'Pakil', 'city': 'Pakil'},
    {'id': 21, 'name': 'Pangil Hub', 'branch': 'Pangil', 'city': 'Pangil'},
    {'id': 22, 'name': 'Pila Hub', 'branch': 'Pila', 'city': 'Pila'},
    {'id': 23, 'name': 'Rizal Hub', 'branch': 'Rizal', 'city': 'Rizal'},
    {'id': 24, 'name': 'San Pablo Hub', 'branch': 'San Pablo', 'city': 'San Pablo'},
    {'id': 25, 'name': 'San Pedro Hub', 'branch': 'San Pedro', 'city': 'San Pedro'},
    {'id': 26, 'name': 'Santa Cruz Hub', 'branch': 'Santa Cruz', 'city': 'Santa Cruz'},
    {'id': 27, 'name': 'Santa Maria Hub', 'branch': 'Santa Maria', 'city': 'Santa Maria'},
    {'id': 28, 'name': 'Santa Rosa Hub', 'branch': 'Santa Rosa', 'city': 'Santa Rosa'},
    {'id': 29, 'name': 'Siniloan Hub', 'branch': 'Siniloan', 'city': 'Siniloan'},
    {'id': 30, 'name': 'Victoria Hub', 'branch': 'Victoria', 'city': 'Victoria'},
  ];
  List<Map<String, dynamic>> _hubs = List.from(_fallbackHubs);
  int? _selectedHubId;

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
    streetController.addListener(_autoSelectHubFromAddress);
    birthdayController.addListener(_onBirthdayChanged);
    _fetchHubs();
    _loadProvinces();
  }

  String _normalizePlace(String raw) {
    var s = raw.toLowerCase().trim();
    s = s
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'\b(city of|municipality of|city|municipality|province of|laguna|brgy\.?|barangay)\b'), ' ')
        .replaceAll('sta.', 'santa')
        .replaceAll('sta ', 'santa ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  void _autoSelectHubFromAddress() {
    final cityText = _normalizePlace(_selectedCity?.name ?? '');
    final brgyText = _normalizePlace(_selectedBarangay?.name ?? '');
    final streetText = _normalizePlace(streetController.text);
    final combined = '$cityText $brgyText $streetText'.trim();

    if (combined.isEmpty) return;

    int? matchedId;

    // 1. Direct match on selected Municipality / City
    if (cityText.isNotEmpty) {
      final compactCity = cityText.replaceAll(' ', '');
      for (final hub in _hubs) {
        final branch = _normalizePlace((hub['branch'] ?? hub['city'] ?? hub['name'] ?? '').toString().replaceAll(RegExp(r'\bhub\b', caseSensitive: false), ''));
        final compactBranch = branch.replaceAll(' ', '');
        if (branch.isNotEmpty &&
            (cityText == branch ||
                compactCity == compactBranch ||
                cityText.contains(branch) ||
                branch.contains(cityText))) {
          matchedId = hub['id'] as int?;
          break;
        }
      }
    }

    // 2. Fallback: match hub/municipality name inside barangay or street address text (e.g. "Brgy. Aplaya, Pila, Laguna")
    if (matchedId == null) {
      for (final hub in _hubs) {
        final branch = _normalizePlace((hub['branch'] ?? hub['city'] ?? hub['name'] ?? '').toString().replaceAll(RegExp(r'\bhub\b', caseSensitive: false), ''));
        if (branch.isNotEmpty && RegExp('\\b${RegExp.escape(branch)}\\b').hasMatch(combined)) {
          matchedId = hub['id'] as int?;
          break;
        }
      }
    }

    if (matchedId != null && matchedId != _selectedHubId && mounted) {
      setState(() {
        _selectedHubId = matchedId;
      });
    }
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _loadingProvinces = true;
      _provinceError = null;
    });
    try {
      final list = await PsgcService.instance.getProvinces();
      if (mounted) {
        final laguna = list.cast<PsgcLocation?>().firstWhere(
              (p) => p != null && p.name.toLowerCase().contains('laguna'),
              orElse: () => const PsgcLocation(
                code: '043400000',
                name: 'Laguna',
                type: 'province',
              ),
            );
        setState(() {
          _provinces = laguna != null ? [laguna] : list;
          _loadingProvinces = false;
        });
        if (laguna != null && _selectedProvince == null) {
          await _onProvinceSelected(laguna);
        }
      }
    } catch (e) {
      if (mounted) {
        const laguna = PsgcLocation(
          code: '043400000',
          name: 'Laguna',
          type: 'province',
        );
        setState(() {
          _provinces = [laguna];
          _loadingProvinces = false;
        });
        if (_selectedProvince == null) {
          await _onProvinceSelected(laguna);
        }
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
    _autoSelectHubFromAddress();

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
    _autoSelectHubFromAddress();
  }

  Future<void> _fetchHubs() async {
    try {
      final hubs = await ApiService.instance.getHubs()
          .timeout(const Duration(seconds: 8));
      if (hubs.isNotEmpty && mounted) {
        setState(() {
          _hubs = hubs;
        });
        _autoSelectHubFromAddress();
      }
    } catch (_) {
      // Retains _fallbackHubs so all hubs are always available
    }
  }

  @override
  @override
  void dispose() {
    streetController.removeListener(_autoSelectHubFromAddress);
    birthdayController.removeListener(_onBirthdayChanged);
    lastNameController.dispose();
    firstNameController.dispose();
    middleInitialController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    birthdayController.dispose();
    ageController.dispose();
    streetController.dispose();
    plateController.dispose();
    super.dispose();
  }

  void _onBirthdayChanged() {
    final text = birthdayController.text.trim();
    if (text.isEmpty) {
      if (ageController.text.isNotEmpty) {
        setState(() {
          _selectedBirthDate = null;
          ageController.clear();
        });
      }
      return;
    }

    final parsed = _parseDate(text);
    if (parsed != null) {
      _selectedBirthDate = parsed;
      final age = _calculateAge(parsed);
      final ageStr = (age >= 0 && age <= 120) ? '$age' : '';
      if (ageController.text != ageStr) {
        setState(() {
          ageController.text = ageStr;
        });
      }
    } else {
      if (ageController.text.isNotEmpty) {
        setState(() {
          ageController.clear();
        });
      }
    }
  }

  DateTime? _parseDate(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return null;

    final iso = DateTime.tryParse(clean);
    if (iso != null && iso.year >= 1900 && iso.year <= DateTime.now().year) {
      return iso;
    }

    final parts = clean.split(RegExp(r'[\/\-\.]'));
    if (parts.length == 3) {
      final p1 = int.tryParse(parts[0]);
      final p2 = int.tryParse(parts[1]);
      final p3 = int.tryParse(parts[2]);
      if (p1 != null && p2 != null && p3 != null) {
        // MM/DD/YYYY
        if (p3 >= 1900 && p3 <= DateTime.now().year) {
          if (p1 > 12 && p1 <= 31 && p2 >= 1 && p2 <= 12) {
            try {
              return DateTime(p3, p2, p1);
            } catch (_) {}
          } else if (p1 >= 1 && p1 <= 12 && p2 >= 1 && p2 <= 31) {
            try {
              return DateTime(p3, p1, p2);
            } catch (_) {}
          }
        }
        // YYYY/MM/DD
        if (p1 >= 1900 && p1 <= DateTime.now().year) {
          if (p2 >= 1 && p2 <= 12 && p3 >= 1 && p3 <= 31) {
            try {
              return DateTime(p1, p2, p3);
            } catch (_) {}
          }
        }
      }
    }
    return null;
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickBirthday() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final defaultInitial = DateTime(now.year - 21, now.month, now.day);
    final initialDate = _selectedBirthDate ?? defaultInitial;
    final firstDate = DateTime(1940, 1, 1);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate)
          ? lastDate
          : (initialDate.isBefore(firstDate) ? firstDate : initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'SELECT YOUR DATE OF BIRTH',
      cancelText: 'CANCEL',
      confirmText: 'SELECT',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.plum,
              onPrimary: AppColors.cream,
              onSurface: AppColors.plum,
              surface: Colors.white,
              secondary: AppColors.orange,
            ),
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _selectedBirthDate = picked;
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      birthdayController.text = formatted;
      final age = _calculateAge(picked);
      setState(() {
        ageController.text = age >= 0 ? '$age' : '';
      });
    }
  }

  Widget field(
    String label, {
    String? hint,
    bool required = false,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? Function(String?)? validator,
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
            readOnly: readOnly,
            onTap: onTap,
            style: GoogleFonts.inter(
              color: AppColors.plum,
              fontSize: 14,
              fontWeight: readOnly && controller == ageController
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffixIcon,
              prefixIcon: prefixIcon,
              filled: readOnly,
              fillColor: readOnly ? const Color(0xFFF9F6F5) : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: validator ??
                (required
                    ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
                    : null),
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
    String email, {
    String? initialOtp,
    bool initialMailSent = true,
  }) async {
    final otpController = TextEditingController();
    bool isVerifying = false;
    bool isResending = false;
    String? otpError;
    String? serverOtp = initialOtp;
    bool mailSent = initialMailSent;
    int cooldown = 60;
    Timer? timer;

    if (!mailSent && serverOtp != null && serverOtp.length == 6) {
      otpController.text = serverOtp;
    }

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
                                    'birthday': birthdayController.text.trim(),
                                    'birth_date': birthdayController.text.trim(),
                                    'date_of_birth': birthdayController.text.trim(),
                                    'age': ageController.text.trim(),
                                    'sex': sex,
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
                                    final res = await ApiService.instance.sendOtp(
                                      email,
                                      name: fullName,
                                    );
                                    setModalState(() {
                                      isResending = false;
                                      cooldown = 60;
                                      serverOtp = res['otp_code']?.toString();
                                      mailSent = res['mail_sent'] != false;
                                      if (!mailSent && serverOtp != null && serverOtp!.length == 6) {
                                        otpController.text = serverOtp!;
                                      }
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: field(
                    'Birthday',
                    hint: 'YYYY-MM-DD',
                    required: true,
                    controller: birthdayController,
                    readOnly: true,
                    onTap: _pickBirthday,
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.orange,
                        size: 20,
                      ),
                      onPressed: _pickBirthday,
                      tooltip: 'Select date of birth',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Birthday is required';
                      }
                      final parsed = _parseDate(val);
                      if (parsed == null) {
                        return 'Invalid date';
                      }
                      final age = _calculateAge(parsed);
                      if (age < 18) {
                        return 'Must be at least 18';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: field(
                    'Age (autogen)',
                    hint: '—',
                    controller: ageController,
                    readOnly: true,
                    suffixIcon: const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          'yrs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Select birthday';
                      }
                      final a = int.tryParse(val.trim());
                      if (a == null || a < 18) {
                        return 'Must be 18+';
                      }
                      return null;
                    },
                  ),
                ),
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
              label: 'Municipality / City (Laguna) *',
              hint: 'Search & select municipality or city',
              selectedLocation: _selectedCity,
              items: _cities,
              isEnabled: true,
              disabledReason: 'Loading Laguna municipalities...',
              isLoading: _loadingCities || _loadingProvinces,
              errorMessage: _cityError ?? _provinceError,
              onRetry: () => _selectedProvince != null ? _onProvinceSelected(_selectedProvince!) : _loadProvinces(),
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
            // Hub selection (auto-matched from selected Municipality / Barangay / Address)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Assign to Hub *',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_selectedHubId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            'Auto-matched to address',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<int>(
                    key: ValueKey<int?>(_selectedHubId),
                    initialValue: _hubs.any((h) => h['id'] == _selectedHubId) ? _selectedHubId : null,
                    isExpanded: true,
                    hint: Text(
                      'Automatically assigned from your address',
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
                    validator: (val) => val == null ? 'Please select your address or choose a hub' : null,
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
                          _selectedProvince ??= const PsgcLocation(
                            code: '043400000',
                            name: 'Laguna',
                            type: 'province',
                          );
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
                            final otpRes = await ApiService.instance.sendOtp(
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
                              initialOtp: otpRes['otp_code']?.toString(),
                              initialMailSent: otpRes['mail_sent'] != false,
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
