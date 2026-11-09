import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A beautiful, modern, animated Flutter splash screen for LUMORA GO Rider.
/// Features a compact 2D vector delivery rider on a themed scooter with
/// rotating wheels, suspension bobbing, road speed lines, and the brand:
/// "LUMORA GO EXPRESS - Move Beautifully, Deliver Calmly."
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinish,
    this.animationDuration = const Duration(milliseconds: 2400),
    this.stayDuration = const Duration(milliseconds: 600),
  });

  final VoidCallback onFinish;
  final Duration animationDuration;
  final Duration stayDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main entrance and transition controller
  late final AnimationController _entranceController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _brandFadeAnimation;
  late final Animation<double> _taglineFadeAnimation;
  late final Animation<double> _loaderFadeAnimation;

  // Continuous wheel rotation and suspension engine bobbing controller
  late final AnimationController _motionController;
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();

    // 1. Entrance controller: scooter glides smoothly into view from the left
    _entranceController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _slideAnimation = Tween<double>(begin: -1.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // LUMORA GO EXPRESS text fades in
    _brandFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.75, curve: Curves.easeOut),
      ),
    );

    // Tagline fades in
    _taglineFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.60, 0.88, curve: Curves.easeOut),
      ),
    );

    // Loading indicator fade-in
    _loaderFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.70, 0.95, curve: Curves.easeIn),
      ),
    );

    // 2. Motion controller: realistic wheel spinning and engine road bobbing
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _entranceController.forward();

    _entranceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _transitionTimer = Timer(widget.stayDuration, () {
          if (mounted) {
            widget.onFinish();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _motionController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Warm cream background requested by user (#FFF9F2)
    const warmCreamBg = Color(0xFFFFF9F2);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: warmCreamBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Minimalist decorative background aura
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blush1.withValues(alpha: 0.55),
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blush2.withValues(alpha: 0.35),
                ),
              ),
            ),

            // Center content: Scaled, compact Motorcycle Rider + Branding
            Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Compact Motorcycle Rider with Entrance + Bobbing + Rotating Wheels
                      AnimatedBuilder(
                        animation: Listenable.merge([_entranceController, _motionController]),
                        builder: (context, child) {
                          final entranceOffset = _slideAnimation.value * size.width;
                          final bob = math.sin(_motionController.value * 2 * math.pi) * 1.5;
                          final wheelRotation = _motionController.value * 2 * math.pi;

                          return Transform.translate(
                            offset: Offset(entranceOffset, bob),
                            child: SizedBox(
                              // Smaller, compact dimensions for a refined, balanced look
                              width: 180,
                              height: 120,
                              child: CustomPaint(
                                painter: _MotorcycleRiderPainter(
                                  wheelRotation: wheelRotation,
                                  bob: bob,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Animated road speed lines beneath the motorcycle
                      AnimatedBuilder(
                        animation: _motionController,
                        builder: (context, child) {
                          return SizedBox(
                            width: 140,
                            height: 10,
                            child: CustomPaint(
                              painter: _RoadDashPainter(
                                offset: _motionController.value,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 22),

                      // BRANDING SECTION: LUMORA GO & EXPRESS
                      FadeTransition(
                        opacity: _brandFadeAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LUMORA GO',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                color: AppColors.plum,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: 1.5,
                                  color: AppColors.orange.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'EXPRESS',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3.5,
                                    color: AppColors.orange,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Container(
                                  width: 18,
                                  height: 1.5,
                                  color: AppColors.orange.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // TAGLINE: "Move Beautifully, Deliver Calmly."
                      FadeTransition(
                        opacity: _taglineFadeAnimation,
                        child: Text(
                          '“Move Beautifully, Deliver Calmly.”',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            letterSpacing: 0.25,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // SUBTLE LOADING ANIMATION (3 pulsing dots)
                      FadeTransition(
                        opacity: _loaderFadeAnimation,
                        child: AnimatedBuilder(
                          animation: _motionController,
                          builder: (context, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                final delay = index * 0.25;
                                final val = (_motionController.value + delay) % 1.0;
                                final scale = 0.65 + (0.5 * math.sin(val * math.pi));
                                final opacity = 0.35 + (0.65 * math.sin(val * math.pi));

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                                  width: 6 * scale,
                                  height: 6 * scale,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.orange.withValues(alpha: opacity),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ],
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

/// 2D Vector Painter for Delivery Scooter Rider matching the reference design.
/// Features:
/// - Open-face orange helmet with cream highlight stripe, chin strap, and profile face
/// - Scooter rider in orange delivery sweater with cross-body strap and dark riding trousers
/// - True scooter geometry: low step-through floorboard, curved apron with cream trim,
///   bulbous rear side fairing, horizontal seat cushion, front mudguard, headlight & mirror
/// - Large corrugated craft delivery parcel box on tubular rear cargo rack
/// - Animated rotating 5-spoke wheels with tires, hubs, and suspension
/// - Speed breeze streaks & ground shadow
class _MotorcycleRiderPainter extends CustomPainter {
  _MotorcycleRiderPainter({
    required this.wheelRotation,
    required this.bob,
  });

  final double wheelRotation;
  final double bob;

  @override
  void paint(Canvas canvas, Size size) {
    // Vector scales automatically and sharply to whatever size is provided
    final scale = size.width / 240.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Reference coordinate space: 240 x 160
    const rearWheelCenter = Offset(64, 122);
    const frontWheelCenter = Offset(184, 122);
    const wheelRadius = 19.0;

    // 1. Soft ground contact shadow beneath scooter & wheels
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(124, 143), width: 185, height: 9),
      shadowPaint,
    );

    // 2. Subtle motion wind streaks behind parcel box and rider
    final windPaint = Paint()
      ..color = AppColors.orange.withValues(alpha: 0.28)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(10, 48), const Offset(34, 48), windPaint);
    canvas.drawLine(const Offset(4, 62), const Offset(28, 62), windPaint);
    canvas.drawLine(const Offset(14, 76), const Offset(36, 76), windPaint);

    // 3. Draw Wheels with Animated Continuous 5-Spoke Rotation
    _drawWheel(canvas, rearWheelCenter, wheelRadius, wheelRotation);
    _drawWheel(canvas, frontWheelCenter, wheelRadius, wheelRotation);

    // 4. Rear Engine & Transmission Drive Casing (Dark Charcoal/Plum)
    final engineCasingPaint = Paint()..color = const Color(0xFF2C2430);
    final enginePath = Path()
      ..moveTo(64, 114)
      ..lineTo(112, 118)
      ..lineTo(110, 131)
      ..lineTo(60, 129)
      ..close();
    canvas.drawPath(enginePath, engineCasingPaint);

    // Kickstand / lower mechanical detail
    final kickstandPaint = Paint()
      ..color = const Color(0xFF1B161E)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(94, 128), const Offset(104, 134), kickstandPaint);

    // 5. Scooter Step-Through Floorboard (Horizontal Deck)
    final floorboardPaint = Paint()..color = const Color(0xFF332637);
    final floorboardRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(110, 116, 42, 8),
      const Radius.circular(3),
    );
    canvas.drawRRect(floorboardRRect, floorboardPaint);

    // 6. Front Fork & Suspension Arm
    final forkPaint = Paint()
      ..color = const Color(0xFFC7B8B1)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(170, 88), frontWheelCenter, forkPaint);

    // 7. Front Fender (Mudguard wrapping over front tire)
    final fenderPaint = Paint()..color = AppColors.orange;
    final fenderPath = Path()
      ..moveTo(164, 122)
      ..cubicTo(162, 98, 184, 94, 202, 106)
      ..lineTo(206, 116)
      ..lineTo(198, 114)
      ..cubicTo(184, 102, 172, 104, 169, 122)
      ..close();
    canvas.drawPath(fenderPath, fenderPaint);

    // Fender cream highlight line
    final fenderTrimPaint = Paint()
      ..color = const Color(0xFFFFF9F2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final fenderTrimPath = Path()
      ..moveTo(167, 118)
      ..cubicTo(168, 100, 186, 98, 202, 108);
    canvas.drawPath(fenderTrimPath, fenderTrimPaint);

    // 8. Front Apron & Leg Shield (Curving gracefully upwards)
    final apronPaint = Paint()..color = AppColors.orange;
    final apronPath = Path()
      ..moveTo(150, 118) // bottom at floorboard
      ..lineTo(142, 90) // inner shield along rider's leg
      ..lineTo(160, 58) // up to steering stem
      ..lineTo(168, 62) // handlebar pod base
      ..cubicTo(174, 76, 178, 92, 172, 108) // front shield curve
      ..lineTo(158, 118) // base
      ..close();
    canvas.drawPath(apronPath, apronPaint);

    // Elegant Cream Accent Curve on the Front Apron
    final apronTrimPaint = Paint()
      ..color = const Color(0xFFFFF9F2)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final apronTrimPath = Path()
      ..moveTo(144, 92)
      ..cubicTo(156, 72, 162, 64, 166, 62);
    canvas.drawPath(apronTrimPath, apronTrimPaint);

    // Chrome/Cream Turn Signal / Front Trim Badge
    final apronBadgePaint = Paint()..color = const Color(0xFFFFFAEB);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(168, 80), width: 4.5, height: 11),
      apronBadgePaint,
    );

    // 9. Handlebar Pod, Headlight & Mirror
    // Handlebar Stem & Cowl
    final headCowlPaint = Paint()..color = AppColors.orange;
    final headCowlRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(150, 48, 15, 12),
      const Radius.circular(5),
    );
    canvas.drawRRect(headCowlRect, headCowlPaint);

    // Headlight Lens (Front facing, bright warm white)
    final headlightPaint = Paint()..color = const Color(0xFFFFFAED);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(163, 49, 4, 10),
        const Radius.circular(2.5),
      ),
      headlightPaint,
    );

    // Rearview Mirror (Stalk & Oval Mirror)
    final mirrorStalkPaint = Paint()
      ..color = const Color(0xFF2C2430)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(152, 48), const Offset(154, 37), mirrorStalkPaint);

    final mirrorPaint = Paint()..color = const Color(0xFF332033);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(154, 35), width: 5.5, height: 9),
      mirrorPaint,
    );

    // Black Handlebar Grip
    final gripPaint = Paint()
      ..color = const Color(0xFF1E141E)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(146, 54), const Offset(152, 54), gripPaint);

    // 10. Rear Body Fairing (Bulbous Vespa / Scooter Cowl over Rear Wheel)
    final rearBodyPaint = Paint()..color = AppColors.orange;
    final rearBodyPath = Path()
      ..moveTo(68, 86) // top under seat
      ..lineTo(112, 88) // forward under seat
      ..lineTo(112, 116) // down to floorboard
      ..lineTo(94, 116) // under cowl
      ..cubicTo(60, 118, 44, 112, 42, 104) // rear lower wrap
      ..cubicTo(40, 96, 46, 90, 68, 86) // curved back to seat
      ..close();
    canvas.drawPath(rearBodyPath, rearBodyPaint);

    // Rear Cowl Cream Accent Swoosh (Matching the reference photo)
    final rearTrimPaint = Paint()
      ..color = const Color(0xFFFFF9F2)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final rearTrimPath = Path()
      ..moveTo(52, 100)
      ..cubicTo(74, 95, 96, 96, 108, 108);
    canvas.drawPath(rearTrimPath, rearTrimPaint);

    // Red Tail Light / Brake Reflector
    final tailLightPaint = Paint()..color = const Color(0xFFE53935);
    final tailPath = Path()
      ..moveTo(42, 94)
      ..lineTo(37, 96)
      ..lineTo(38, 103)
      ..lineTo(43, 101)
      ..close();
    canvas.drawPath(tailPath, tailLightPaint);

    // Mudflap / License Plate bracket
    final flapPaint = Paint()
      ..color = const Color(0xFF1C1520)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(40, 105), const Offset(36, 114), flapPaint);

    // 11. Scooter Seat Cushion (Horizontal, Comfortable)
    final seatPaint = Paint()..color = const Color(0xFF221724);
    final seatRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(68, 81, 48, 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(seatRRect, seatPaint);

    // 12. Rear Metal Cargo Carrier Rack
    final rackPaint = Paint()
      ..color = const Color(0xFF2B222E)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Base horizontal bar under the delivery box
    canvas.drawLine(const Offset(44, 84), const Offset(76, 84), rackPaint);
    // Support braces down to rear cowl
    canvas.drawLine(const Offset(46, 84), const Offset(46, 92), rackPaint);
    canvas.drawLine(const Offset(72, 84), const Offset(72, 88), rackPaint);

    // 13. Large Cardboard Delivery Parcel Box (Craft Carton with Lid & Tape)
    // Box Main Body
    const boxRect = Rect.fromLTWH(44, 43, 46, 41);
    final boxBodyPaint = Paint()..color = const Color(0xFFDF9E5B);
    canvas.drawRect(boxRect, boxBodyPaint);

    // Box Shadow for 3D depth
    final boxShadowPaint = Paint()..color = const Color(0xFFC78441);
    canvas.drawRect(const Rect.fromLTWH(44, 76, 46, 8), boxShadowPaint);

    // Box Top Flap / Lid (Slightly wider lip)
    final boxLidPaint = Paint()..color = const Color(0xFFE6A868);
    final boxLidRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(42, 40, 50, 9),
      const Radius.circular(2),
    );
    canvas.drawRRect(boxLidRect, boxLidPaint);

    final boxLidLipPaint = Paint()..color = const Color(0xFFBF7A35);
    canvas.drawRect(const Rect.fromLTWH(42, 48, 50, 1.5), boxLidLipPaint);

    // Box Sealing Tape Bands (Vertical center packing tape)
    final tapePaint = Paint()..color = const Color(0xFFB06C2F);
    canvas.drawRect(const Rect.fromLTWH(61, 40, 5.5, 44), tapePaint);

    // Subtle Brand Parcel Stamp on the Box
    final stampPaint = Paint()..color = const Color(0xFFFFF9F2).withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(48, 55, 9, 7),
        const Radius.circular(1.5),
      ),
      stampPaint,
    );

    // 14. Delivery Rider (Upright Scooter Posture)
    // Dark Riding Trousers
    final pantsPaint = Paint()..color = const Color(0xFF2C2532);

    // Thigh (sitting on seat, knees bent forward)
    final thighPath = Path()
      ..moveTo(92, 82) // hip
      ..lineTo(124, 88) // knee top
      ..lineTo(120, 98) // knee bottom
      ..lineTo(94, 91) // under thigh
      ..close();
    canvas.drawPath(thighPath, pantsPaint);

    // Lower Leg (pointing down to the floorboard)
    final lowerLegPath = Path()
      ..moveTo(120, 89)
      ..lineTo(128, 92)
      ..lineTo(124, 116)
      ..lineTo(117, 116)
      ..close();
    canvas.drawPath(lowerLegPath, pantsPaint);

    // Sneaker resting flat on the scooter footboard
    final shoePaint = Paint()..color = const Color(0xFF1F1722);
    final shoePath = Path()
      ..moveTo(116, 116)
      ..lineTo(133, 116)
      ..lineTo(136, 120)
      ..lineTo(116, 120)
      ..close();
    canvas.drawPath(shoePath, shoePaint);

    // White Sneaker Sole & Swoosh Accent
    final shoeSolePaint = Paint()
      ..color = const Color(0xFFFFF9F2)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(118, 120), const Offset(135, 120), shoeSolePaint);

    // Rider's Torso in Orange Delivery Sweater / Jacket
    final sweaterPaint = Paint()..color = AppColors.orange;
    final torsoPath = Path()
      ..moveTo(86, 82) // lower back
      ..lineTo(108, 48) // shoulders leaning slightly forward
      ..lineTo(124, 58) // chest
      ..lineTo(110, 83) // waist
      ..close();
    canvas.drawPath(torsoPath, sweaterPaint);

    // Dark Cross-Body Messenger Bag Strap
    final strapPaint = Paint()
      ..color = const Color(0xFF2D1E2D)
      ..strokeWidth = 4.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(104, 50), const Offset(90, 80), strapPaint);

    // Rider's Arm reaching forward to the handlebar grip
    final armPaint = Paint()
      ..color = AppColors.orange
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(110, 52), const Offset(144, 54), armPaint);

    // Rider's Hand gripping the handlebar
    final handPaint = Paint()..color = const Color(0xFFF5B998); // warm skin tone
    canvas.drawCircle(const Offset(146, 54), 4.2, handPaint);

    // 15. Rider's Neck, Profile Face & Open-Face Helmet
    // Neck
    final neckPaint = Paint()..color = const Color(0xFFF5B998);
    canvas.drawRect(const Rect.fromLTWH(108, 40, 6, 8), neckPaint);

    // Face Profile (Jaw, Chin, Nose, Smile)
    final facePaint = Paint()..color = const Color(0xFFF5B998);
    final facePath = Path()
      ..moveTo(112, 32)
      ..lineTo(119, 32)
      ..lineTo(122, 35) // nose tip
      ..lineTo(118, 38) // upper lip
      ..lineTo(120, 41) // chin
      ..lineTo(112, 42) // jawline
      ..close();
    canvas.drawPath(facePath, facePaint);

    // Eye / Smile detail
    final eyePaint = Paint()
      ..color = const Color(0xFF2D1E2D)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      const Rect.fromLTWH(115, 33, 3, 2),
      0,
      math.pi,
      false,
      eyePaint,
    );

    // Ear
    final earPaint = Paint()..color = const Color(0xFFEEAA85);
    canvas.drawCircle(const Offset(112, 36), 2.2, earPaint);

    // Helmet Dome (Rounded scooter helmet in Lumora Orange)
    const helmetCenter = Offset(111, 26);
    const helmetRadius = 14.5;

    final helmetPaint = Paint()..color = AppColors.orange;
    canvas.drawCircle(helmetCenter, helmetRadius, helmetPaint);

    // Helmet Cream Highlight / Racing Stripe
    final helmetStripePaint = Paint()
      ..color = const Color(0xFFFFF9F2)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: helmetCenter, radius: helmetRadius - 2),
      -math.pi * 0.9,
      math.pi * 0.75,
      false,
      helmetStripePaint,
    );

    // Black Chin Strap
    final chinStrapPaint = Paint()
      ..color = const Color(0xFF1E141E)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(110, 34), const Offset(111, 43), chinStrapPaint);
    canvas.drawLine(const Offset(111, 43), const Offset(116, 42), chinStrapPaint);

    canvas.restore();
  }

  /// Draws a detailed scooter wheel with tire, rim, hub, and 5 rotating spokes
  void _drawWheel(Canvas canvas, Offset center, double radius, double rotation) {
    // Outer Tire (Dark Charcoal)
    final tirePaint = Paint()
      ..color = const Color(0xFF252028)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5;
    canvas.drawCircle(center, radius, tirePaint);

    // Inner Rim (Cream #FFF9F2 / Light Silver)
    final rimPaint = Paint()
      ..color = const Color(0xFFFFF9F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius - 4.0, rimPaint);

    // Rotating 5 Spokes
    final spokePaint = Paint()
      ..color = const Color(0xFF8E838B)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final angle = rotation + (i * (2 * math.pi / 5));
      final x2 = center.dx + (radius - 5.0) * math.cos(angle);
      final y2 = center.dy + (radius - 5.0) * math.sin(angle);
      canvas.drawLine(center, Offset(x2, y2), spokePaint);
    }

    // Wheel Hub (Orange Center Accent)
    final hubPaint = Paint()..color = AppColors.orange;
    canvas.drawCircle(center, 4.2, hubPaint);

    final hubPinPaint = Paint()..color = AppColors.plum;
    canvas.drawCircle(center, 1.8, hubPinPaint);
  }

  @override
  bool shouldRepaint(covariant _MotorcycleRiderPainter oldDelegate) {
    return oldDelegate.wheelRotation != wheelRotation || oldDelegate.bob != bob;
  }
}

/// Draws moving dashed road lines beneath the motorcycle to enhance active delivery feel
class _RoadDashPainter extends CustomPainter {
  _RoadDashPainter({required this.offset});

  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.85)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const dashWidth = 12.0;
    const gap = 14.0;
    const totalStep = dashWidth + gap;

    final startX = -(offset * totalStep);

    for (double x = startX; x < size.width + totalStep; x += totalStep) {
      if (x + dashWidth > 0 && x < size.width) {
        final x1 = math.max(0.0, x);
        final x2 = math.min(size.width, x + dashWidth);
        canvas.drawLine(Offset(x1, 5), Offset(x2, 5), dashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoadDashPainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}
