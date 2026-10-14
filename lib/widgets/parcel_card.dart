import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/delivery_request.dart';
import '../theme/app_colors.dart';

class ParcelCard extends StatelessWidget {
  const ParcelCard({
    super.key,
    required this.parcel,
    this.onTap,
    this.onAction,
    this.actionLabel,
  });

  final DeliveryRequest parcel;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final String? actionLabel;

  (Color bg, Color text, String label, IconData icon) _statusConfig(DeliveryStage stage) {
    return switch (stage) {
      DeliveryStage.accepted => (
          AppColors.pendingSoft,
          AppColors.pending,
          'ASSIGNED · HUB',
          Icons.inventory_2_outlined,
        ),
      DeliveryStage.pickedUp => (
          AppColors.inTransitSoft,
          AppColors.inTransit,
          'PICKED UP',
          Icons.local_shipping_outlined,
        ),
      DeliveryStage.outForDelivery || DeliveryStage.arrived => (
          AppColors.inTransitSoft,
          AppColors.inTransit,
          'OUT FOR DELIVERY',
          Icons.navigation_outlined,
        ),
      DeliveryStage.delivered || DeliveryStage.completed => (
          AppColors.deliveredSoft,
          AppColors.delivered,
          'DELIVERED',
          Icons.check_circle_outline,
        ),
      DeliveryStage.failed => (
          AppColors.failedSoft,
          AppColors.failed,
          'FAILED',
          Icons.cancel_outlined,
        ),
      DeliveryStage.rescheduled => (
          AppColors.failedSoft,
          AppColors.failed,
          'RESCHEDULED',
          Icons.update_outlined,
        ),
      DeliveryStage.returningToHub || DeliveryStage.returnedToHub => (
          AppColors.blush2,
          AppColors.plum,
          'RETURNING TO HUB',
          Icons.keyboard_return_outlined,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusText, statusLabelText, statusIcon) = _statusConfig(parcel.stage);

    return Card(
      color: AppColors.cream,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Parcel ID + Status Pill
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.blush1,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            size: 15,
                            color: AppColors.plum,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            parcel.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: AppColors.plum,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusText),
                        const SizedBox(width: 3),
                        Text(
                          statusLabelText,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: statusText,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Receiver name and area
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parcel.receiverName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${parcel.deliveryArea} · ${parcel.receiverAddress}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 10),

              // Footer: COD badge and Details/Action
              Row(
                children: [
                  // COD or PREPAID badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: parcel.isCod && parcel.codAmount > 0
                          ? AppColors.blush1
                          : AppColors.deliveredSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: parcel.isCod && parcel.codAmount > 0
                            ? AppColors.line
                            : AppColors.deliveredSoft,
                      ),
                    ),
                    child: Text(
                      parcel.formattedCod,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: parcel.isCod && parcel.codAmount > 0
                            ? AppColors.orange
                            : AppColors.delivered,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Stop sequence or failure note
                  if (parcel.failureReason != null)
                    Flexible(
                      child: Text(
                        parcel.failureReason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.failed,
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'Stop #${parcel.stopOrder}',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

