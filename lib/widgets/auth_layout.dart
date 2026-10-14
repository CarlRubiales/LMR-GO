import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Responsive Lumora layout for authentication screens.
/// Features cream background with soft blush radial glows,
/// responsive phone stacked vs tablet/desktop two-column layout,
/// logistics header art, and a soft-shadowed form card.
class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.loginBackground,
      body: Stack(
        children: [
          // Top-left soft blush radial glow
          Positioned(
            top: -100,
            left: -100,
            width: 360,
            height: 360,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blush2.withValues(alpha: 0.50),
                      AppColors.blush1.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Bottom-right soft blush radial glow
          Positioned(
            bottom: -120,
            right: -120,
            width: 380,
            height: 380,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blush1.withValues(alpha: 0.55),
                      AppColors.blush2.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Scrollable centered content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 40 : 20,
                    vertical: isWide ? 32 : 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 860 : 400,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: isWide
                              ? _buildWideLayout()
                              : _buildPhoneLayout(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.formBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.12),
            blurRadius: 50,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LogisticsHeader(isWide: false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.formBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.12),
            blurRadius: 65,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _LogisticsHeader(isWide: true),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 32,
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logistics illustration header with logo, Playfair Display headline, and tagline.
class _LogisticsHeader extends StatelessWidget {
  const _LogisticsHeader({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: isWide ? 520 : 160,
      ),
      decoration: BoxDecoration(
        color: AppColors.blush1,
        borderRadius: isWide
            ? const BorderRadius.horizontal(left: Radius.circular(20))
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          // Background stylized logistics art
          Positioned.fill(
            child: CustomPaint(
              painter: _LogisticsIllustrationPainter(),
            ),
          ),
          // Light plum gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.plum.withValues(alpha: 0.06),
                    AppColors.plum.withValues(alpha: isWide ? 0.20 : 0.14),
                  ],
                ),
              ),
            ),
          ),
          // Content overlay
          Padding(
            padding: EdgeInsets.all(isWide ? 36 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo top-left
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.plum,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.two_wheeler,
                        color: AppColors.cream,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LMR GO',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 16,
                              color: AppColors.plum,
                            ),
                          ),
                          Text(
                            'LUMORA GO · EXPRESS LOGISTICS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isWide ? 60 : 20),
                if (isWide) ...[
                  Text(
                    'Ride Smarter.\nDeliver Better.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.plum,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Precision courier operations and express fulfillment.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.plumLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warehouse_outlined,
                          size: 16,
                          color: AppColors.orange,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Central Warehouse Hub · Active Fleet',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    'Express Fleet Logistics',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.plum,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fast, dependable logistics on your schedule.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.plumLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering stylized warehouse shelves, courier routes, and parcel geometry.
class _LogisticsIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.blush1;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.blush2.withValues(alpha: 0.6),
          AppColors.blush1.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.7, size.height * 0.4),
        radius: size.width * 0.6,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.4),
      size.width * 0.6,
      glowPaint,
    );

    final linePaint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.65);
    path.cubicTo(
      size.width * 0.35,
      size.height * 0.5,
      size.width * 0.65,
      size.height * 0.8,
      size.width,
      size.height * 0.6,
    );
    canvas.drawPath(path, linePaint);

    final parcelFill = Paint()
      ..color = AppColors.blush2.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final parcelStroke = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final r1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.65, size.height * 0.35, 48, 48),
      const Radius.circular(8),
    );
    canvas.drawRRect(r1, parcelFill);
    canvas.drawRRect(r1, parcelStroke);

    final r2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.78, size.height * 0.42, 38, 38),
      const Radius.circular(6),
    );
    canvas.drawRRect(r2, parcelFill);
    canvas.drawRRect(r2, parcelStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
