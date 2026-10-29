import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onBack,
    required this.onLogin,
    required this.onRegister,
  });

  final VoidCallback? onBack;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscure = true;
  bool rememberMe = false;
  bool isLoading = false;
  String? errorMessage;

  // Secret dev tap counter — tap logo 7 times to open server dialog
  int _devTapCount = 0;
  DateTime? _devTapLastTime;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    emailFocus.addListener(() => setState(() {}));
    passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    // If both fields are empty (e.g. preview mode or widget test), invoke onLogin directly
    if (email.isEmpty && password.isEmpty) {
      widget.onLogin();
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await ApiService.instance.login(email, password);
      if (mounted) {
        widget.onLogin();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        final isTimeout = msg.toLowerCase().contains('timeout') ||
            msg.toLowerCase().contains('future not completed');
        final isConnectionError = isTimeout ||
            msg.toLowerCase().contains('socket') ||
            msg.toLowerCase().contains('cannot connect') ||
            msg.toLowerCase().contains('connection');

        setState(() {
          if (isConnectionError) {
            errorMessage =
                'Connection timed out. Ensure your phone and laptop are on the same Wi-Fi network.';
          } else {
            errorMessage = msg;
          }
          isLoading = false;
        });
      }
    }
  }

  void _onLogoSecretTap() {
    final now = DateTime.now();
    if (_devTapLastTime == null || now.difference(_devTapLastTime!) > const Duration(seconds: 3)) {
      _devTapCount = 0;
    }
    _devTapLastTime = now;
    _devTapCount++;
    if (_devTapCount >= 7) {
      _devTapCount = 0;
      _showServerDialog();
    }
  }

  void _showServerDialog() {
    final serverController = TextEditingController(text: ApiService.instance.baseUrl);
    bool testing = false;
    String? testResult;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.cream,
          title: Text(
            'Server Connection',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.plum),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logistics API Base URL:',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: serverController,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.plum),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Laptop Hotspot / 192.168.137.1', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      serverController.text = 'http://192.168.137.1/api/v1';
                    },
                  ),
                  ActionChip(
                    label: const Text('Wi-Fi / 172.20.10.4', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      serverController.text = 'http://172.20.10.4/api/v1';
                    },
                  ),
                  ActionChip(
                    label: const Text('Home / 192.168.86.42', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      serverController.text = 'http://192.168.86.42:8000/api/v1';
                    },
                  ),
                  ActionChip(
                    label: const Text('USB / 127.0.0.1:8000', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      serverController.text = 'http://127.0.0.1:8000/api/v1';
                    },
                  ),
                ],
              ),
              if (testResult != null) ...[
                const SizedBox(height: 10),
                Text(
                  testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: testResult!.contains('Successful') ? AppColors.delivered : AppColors.errorBoxText,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      setDialogState(() {
                        testing = true;
                        testResult = 'Testing connection...';
                      });
                      final ok = await ApiService.instance.testConnection(serverController.text.trim());
                      setDialogState(() {
                        testing = false;
                        testResult = ok ? '✓ Connection Successful!' : '✗ Server unreachable';
                      });
                    },
              child: const Text('Test Ping'),
            ),
            TextButton(
              onPressed: () {
                ApiService.instance.baseUrl = serverController.text.trim();
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void recoverPassword() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password recovery'),
          content: const Text(
            'Password recovery requires a connected authentication service.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top of form: small "← Back" text link and discreet server settings icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.onBack != null)
                  InkWell(
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
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),

            // Heading: tap 7× quickly (dev secret) to open server settings
            GestureDetector(
              onTap: _onLogoSecretTap,
              child: Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppColors.plum,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Small gold ✦ between two thin lines (#DEC8BC)
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
            const SizedBox(height: 6),

            // Muted subtitle (14 px, #857579)
            Text(
              'Sign in to continue with LMR GO',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),

            if (errorMessage != null) ...[
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
                        errorMessage!,
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

            // Email address label: 13 px, semi-bold, plum
            Text(
              'Email address',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.plum,
              ),
            ),
            const SizedBox(height: 7),

            // Email text field: height 50, 9 px radius, 1px border #E8D8D0, fill #FFFAF7, plum text, hint color #B2A4A1, prefix mail_outline #AA9898
            _InputFieldContainer(
              isFocused: emailFocus.hasFocus,
              child: SizedBox(
                height: 50,
                child: TextField(
                  controller: emailController,
                  focusNode: emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.inter(
                    color: AppColors.plum,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: Icon(
                      Icons.mail_outline,
                      color: AppColors.inputIcon,
                      size: 20,
                    ),
                    semanticCounterText: 'Email address',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password label: 13 px, semi-bold, plum
            Text(
              'Password',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.plum,
              ),
            ),
            const SizedBox(height: 7),

            // Password text field: height 50, 9 px radius, 1px border #E8D8D0, fill #FFFAF7, plum text, hint #B2A4A1, lock_outline, eye icon
            _InputFieldContainer(
              isFocused: passwordFocus.hasFocus,
              child: SizedBox(
                height: 50,
                child: TextField(
                  controller: passwordController,
                  focusNode: passwordFocus,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.password],
                  enableSuggestions: false,
                  autocorrect: false,
                  onSubmitted: (_) => _handleLogin(),
                  style: GoogleFonts.inter(
                    color: AppColors.plum,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.inputIcon,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      tooltip: obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.inputIcon,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Row under fields: "Remember me" checkbox (activeColor rose, muted text) and underlined plum "Forgot password?"
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: rememberMe,
                        activeColor: AppColors.rose,
                        side: const BorderSide(
                          color: AppColors.inputBorder,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) =>
                            setState(() => rememberMe = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Remember me',
                      style: GoogleFonts.inter(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: recoverPassword,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.inter(
                      color: AppColors.plum,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Sign in button: full width, height 50, 9 px radius, 1px rose border, cream background, plum bold text, no elevation (pressed state: white)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: isLoading ? null : _handleLogin,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return AppColors.white;
                    }
                    return AppColors.cream;
                  }),
                  foregroundColor: WidgetStateProperty.all(AppColors.plum),
                  side: WidgetStateProperty.all(
                    const BorderSide(color: AppColors.rose, width: 1),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  elevation: WidgetStateProperty.all(0),
                  textStyle: WidgetStateProperty.all(
                    GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.plum,
                        ),
                      )
                    : const Text('Sign in'),
              ),
            ),
            const SizedBox(height: 16),

            // Divider: "or continue with" (muted, 12 px, thin lines both sides)
            const Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppColors.dividerLine,
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or continue with',
                    style: TextStyle(
                      color: AppColors.muted,
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
            const SizedBox(height: 16),

            // Continue with Google OutlinedButton: full-width white with Google logo and #E8D8D0 border
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Google Sign-in available in production.'),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  side: const BorderSide(
                    color: AppColors.inputBorder,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GoogleGLogo(),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Continue with Google',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Footer: "Don't have an account? Create account" (13 px, muted, link in bold underlined plum)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.inter(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
                InkWell(
                  onTap: widget.onRegister,
                  child: Text(
                    'Create account',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.plum,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' · ',
                  style: GoogleFonts.inter(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
                InkWell(
                  onTap: widget.onRegister,
                  child: Text(
                    'Register',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.plum,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preview footer note
            Text(
              'Preview login · no account is authenticated.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Container that adds a soft rose glow around input fields when focused.
class _InputFieldContainer extends StatelessWidget {
  const _InputFieldContainer({
    required this.isFocused,
    required this.child,
  });

  final bool isFocused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.rose.withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Vector Google 'G' icon with authentic 4-color palette.
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2;

    const red = Color(0xFFEA4335);
    const blue = Color(0xFF4285F4);
    const green = Color(0xFF34A853);
    const yellow = Color(0xFFFBBC05);

    final bluePaint = Paint()..color = blue;
    final redPaint = Paint()..color = red;
    final greenPaint = Paint()..color = green;
    final yellowPaint = Paint()..color = yellow;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    canvas.drawArc(rect, -0.6, 1.2, true, bluePaint);
    canvas.drawArc(rect, 0.6, 1.3, true, greenPaint);
    canvas.drawArc(rect, 1.9, 1.3, true, yellowPaint);
    canvas.drawArc(rect, 3.2, 1.5, true, redPaint);

    final innerPaint = Paint()..color = AppColors.white;
    canvas.drawCircle(Offset(cx, cy), radius * 0.55, innerPaint);

    final barRect = Rect.fromLTWH(
      cx,
      cy - radius * 0.22,
      radius,
      radius * 0.44,
    );
    canvas.drawRect(barRect, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lumora Error Box widget for warnings/errors.
class LumoraErrorBox extends StatelessWidget {
  const LumoraErrorBox({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorBoxBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorBoxBorder, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.errorBoxText,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppColors.errorBoxText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lumora Success Box widget for confirmations.
class LumoraSuccessBox extends StatelessWidget {
  const LumoraSuccessBox({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successBoxBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.successBoxBorder, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.successBoxText,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppColors.successBoxText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
