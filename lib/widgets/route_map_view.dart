import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/delivery_request.dart';
import '../models/delivery_status.dart';
import '../theme/app_colors.dart';

class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.parcels,
    required this.onSelectStop,
  });

  final List<DeliveryRequest> parcels;
  final ValueChanged<DeliveryRequest> onSelectStop;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.parcels.isNotEmpty) {
      // Default select the first active/out-for-delivery stop or first stop
      final activeIdx = widget.parcels.indexWhere(
        (p) => p.stage == DeliveryStage.outForDelivery || p.stage == DeliveryStage.arrived,
      );
      _selectedIndex = activeIdx != -1 ? activeIdx : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.parcels.isEmpty) {
      return Center(
        child: Text(
          'No stops on the route map yet.',
          style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
        ),
      );
    }

    final safeIndex = _selectedIndex < widget.parcels.length ? _selectedIndex : 0;
    final selectedParcel = widget.parcels[safeIndex];

    return Column(
      children: [
        // Map Canvas Container
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E232A), // High contrast dark slate for outdoor visibility
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Custom Route Path Painter
                  CustomPaint(
                    size: Size.infinite,
                    painter: _RoutePainter(
                      stopCount: widget.parcels.length,
                      selectedIndex: safeIndex,
                    ),
                  ),

                  // Hub Badge (Starting point)
                  Positioned(
                    left: 20,
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.plum,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warehouse_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'Lumora Hub',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Stop Pins plotted on canvas
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;

                      return Stack(
                        children: List.generate(widget.parcels.length, (index) {
                          final p = widget.parcels[index];
                          final pos = _calculateStopOffset(index, widget.parcels.length, width, height);
                          final isSelected = index == safeIndex;
                          final status = DeliveryStatus.fromStage(p.stage);

                          return Positioned(
                            left: pos.dx - 22,
                            top: pos.dy - 22,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedIndex = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: isSelected ? 48 : 40,
                                height: isSelected ? 48 : 40,
                                decoration: BoxDecoration(
                                  color: status.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    width: isSelected ? 3.5 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: status.color.withValues(alpha: 0.6),
                                      blurRadius: isSelected ? 14 : 6,
                                      spreadRadius: isSelected ? 2 : 0,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${p.stopOrder}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: isSelected ? 16 : 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),

                  // Map Legend overlay
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.parcels.length} STOPS ROUTED',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Selected Stop Details Card
        Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: AppColors.plum.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.plum,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stop #${selectedParcel.stopOrder}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      selectedParcel.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.plum,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DeliveryStatus.fromStage(selectedParcel.stage).backgroundColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        DeliveryStatus.fromStage(selectedParcel.stage).label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: DeliveryStatus.fromStage(selectedParcel.stage).color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                selectedParcel.receiverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                selectedParcel.receiverAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: selectedParcel.isCod ? AppColors.blush1 : AppColors.deliveredSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      selectedParcel.formattedCod,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: selectedParcel.isCod ? AppColors.orange : AppColors.delivered,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => widget.onSelectStop(selectedParcel),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.plum,
                      foregroundColor: AppColors.cream,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Stop Details →',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Offset _calculateStopOffset(int index, int total, double width, double height) {
    if (total == 0) return Offset(width / 2, height / 2);

    // Dynamic S-curve layout spanning across the map canvas
    final safeW = width - 80;
    final safeH = height - 100;
    final progress = (index + 1) / (total + 1);

    final dy = 60 + safeH * progress;
    // Alternate left/center/right along an S-curve route
    final dx = 40 + (safeW / 2) + ((safeW * 0.38) * (index.isEven ? 1 : -1));

    return Offset(dx.clamp(40, width - 40), dy.clamp(50, height - 50));
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.stopCount,
    required this.selectedIndex,
  });

  final int stopCount;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw subtle grid map lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (stopCount == 0) return;

    // Draw route path
    final routePaint = Paint()
      ..color = const Color(0xFF4A90E2).withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Hub coordinate
    const hubOffset = Offset(60, 45);
    path.moveTo(hubOffset.dx, hubOffset.dy);

    for (var i = 0; i < stopCount; i++) {
      final stopOffset = _RouteMapViewState._calculateStopOffset(i, stopCount, size.width, size.height);
      path.lineTo(stopOffset.dx, stopOffset.dy);
    }

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.stopCount != stopCount || oldDelegate.selectedIndex != selectedIndex;
  }
}
