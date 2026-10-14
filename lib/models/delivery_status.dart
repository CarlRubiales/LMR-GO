import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'delivery_request.dart';

/// Centralized status definitions matching the Lumora Logistics ERP workflow.
enum DeliveryStatus {
  assignedToRider,
  pickedUpFromHub,
  outForDelivery,
  arrived,
  delivered,
  deliveryFailed,
  rescheduled,
  returningToHub,
  returnedToHub,
  completed;

  /// Standard wire code sent to the ERP and modern endpoints
  String get code {
    switch (this) {
      case DeliveryStatus.assignedToRider:
        return 'ASSIGNED_TO_RIDER';
      case DeliveryStatus.pickedUpFromHub:
        return 'PICKED_UP_FROM_HUB';
      case DeliveryStatus.outForDelivery:
        return 'OUT_FOR_DELIVERY';
      case DeliveryStatus.arrived:
        return 'ARRIVED';
      case DeliveryStatus.delivered:
        return 'DELIVERED';
      case DeliveryStatus.deliveryFailed:
        return 'DELIVERY_FAILED';
      case DeliveryStatus.rescheduled:
        return 'RESCHEDULED';
      case DeliveryStatus.returningToHub:
        return 'RETURNING_TO_HUB';
      case DeliveryStatus.returnedToHub:
        return 'RETURNED_TO_HUB';
      case DeliveryStatus.completed:
        return 'COMPLETED';
    }
  }

  /// Maps to legacy backend database status strings:
  /// (Pending / In Transit / Out For Delivery / Delivered)
  String get legacyBackendStatus {
    switch (this) {
      case DeliveryStatus.assignedToRider:
        return 'Pending';
      case DeliveryStatus.pickedUpFromHub:
      case DeliveryStatus.returningToHub:
        return 'In Transit';
      case DeliveryStatus.outForDelivery:
      case DeliveryStatus.arrived:
        return 'Out For Delivery';
      case DeliveryStatus.delivered:
      case DeliveryStatus.completed:
        return 'Delivered';
      case DeliveryStatus.deliveryFailed:
        return 'Failed';
      case DeliveryStatus.rescheduled:
        return 'Rescheduled';
      case DeliveryStatus.returnedToHub:
        return 'Returned';
    }
  }

  /// User-friendly label for UI badges and headers
  String get label {
    switch (this) {
      case DeliveryStatus.assignedToRider:
        return 'ASSIGNED';
      case DeliveryStatus.pickedUpFromHub:
        return 'PICKED UP';
      case DeliveryStatus.outForDelivery:
      case DeliveryStatus.arrived:
        return 'OUT FOR DELIVERY';
      case DeliveryStatus.delivered:
        return 'DELIVERED';
      case DeliveryStatus.deliveryFailed:
        return 'DELIVERY FAILED';
      case DeliveryStatus.rescheduled:
        return 'RESCHEDULED';
      case DeliveryStatus.returningToHub:
        return 'RETURNING TO HUB';
      case DeliveryStatus.returnedToHub:
        return 'RETURNED TO HUB';
      case DeliveryStatus.completed:
        return 'COMPLETED';
    }
  }

  /// Outdoor high-contrast color scheme
  Color get color {
    switch (this) {
      case DeliveryStatus.assignedToRider:
        return AppColors.pending;
      case DeliveryStatus.pickedUpFromHub:
        return AppColors.inTransit;
      case DeliveryStatus.outForDelivery:
      case DeliveryStatus.arrived:
        return AppColors.inTransit;
      case DeliveryStatus.delivered:
      case DeliveryStatus.completed:
        return AppColors.delivered;
      case DeliveryStatus.deliveryFailed:
        return AppColors.failed;
      case DeliveryStatus.rescheduled:
        return AppColors.failed;
      case DeliveryStatus.returningToHub:
      case DeliveryStatus.returnedToHub:
        return AppColors.plum;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case DeliveryStatus.assignedToRider:
        return AppColors.pendingSoft;
      case DeliveryStatus.pickedUpFromHub:
      case DeliveryStatus.outForDelivery:
      case DeliveryStatus.arrived:
        return AppColors.inTransitSoft;
      case DeliveryStatus.delivered:
      case DeliveryStatus.completed:
        return AppColors.deliveredSoft;
      case DeliveryStatus.deliveryFailed:
      case DeliveryStatus.rescheduled:
        return AppColors.failedSoft;
      case DeliveryStatus.returningToHub:
      case DeliveryStatus.returnedToHub:
        return AppColors.blush2;
    }
  }

  IconData get icon {
    switch (this) {
      case DeliveryStatus.assignedToRider:
        return Icons.inventory_2_outlined;
      case DeliveryStatus.pickedUpFromHub:
        return Icons.local_shipping_outlined;
      case DeliveryStatus.outForDelivery:
      case DeliveryStatus.arrived:
        return Icons.navigation_outlined;
      case DeliveryStatus.delivered:
      case DeliveryStatus.completed:
        return Icons.check_circle_outline;
      case DeliveryStatus.deliveryFailed:
        return Icons.cancel_outlined;
      case DeliveryStatus.rescheduled:
        return Icons.update_outlined;
      case DeliveryStatus.returningToHub:
      case DeliveryStatus.returnedToHub:
        return Icons.keyboard_return_outlined;
    }
  }

  /// Parses from standard wire code or legacy backend string
  static DeliveryStatus fromCode(String code) {
    final normalized = code.trim().toUpperCase().replaceAll(' ', '_');
    for (final s in DeliveryStatus.values) {
      if (s.code == normalized) return s;
    }

    switch (normalized) {
      case 'PENDING':
      case 'ASSIGNED':
      case 'PACKED':
        return DeliveryStatus.assignedToRider;
      case 'IN_TRANSIT':
      case 'INTRANSIT':
      case 'SORTED':
      case 'PICKED_UP':
      case 'PICKEDUP':
        return DeliveryStatus.pickedUpFromHub;
      case 'OUT_FOR_DELIVERY':
      case 'OUTFORDELIVERY':
        return DeliveryStatus.outForDelivery;
      case 'ARRIVED':
      case 'ARRIVED_AT_STOP':
        return DeliveryStatus.arrived;
      case 'DELIVERED':
        return DeliveryStatus.delivered;
      case 'FAILED':
      case 'DELIVERY_FAILED':
      case 'EXCEPTION':
        return DeliveryStatus.deliveryFailed;
      case 'RESCHEDULED':
        return DeliveryStatus.rescheduled;
      case 'RETURNING':
      case 'RETURNING_TO_HUB':
        return DeliveryStatus.returningToHub;
      case 'RETURNED':
      case 'RETURNED_TO_HUB':
      case 'HUB_RETURNED':
        return DeliveryStatus.returnedToHub;
      case 'COMPLETED':
        return DeliveryStatus.completed;
      default:
        return DeliveryStatus.assignedToRider;
    }
  }

  DeliveryStage toStage() {
    switch (this) {
      case DeliveryStatus.assignedToRider:
        return DeliveryStage.accepted;
      case DeliveryStatus.pickedUpFromHub:
        return DeliveryStage.pickedUp;
      case DeliveryStatus.outForDelivery:
        return DeliveryStage.outForDelivery;
      case DeliveryStatus.arrived:
        return DeliveryStage.arrived;
      case DeliveryStatus.delivered:
        return DeliveryStage.delivered;
      case DeliveryStatus.deliveryFailed:
        return DeliveryStage.failed;
      case DeliveryStatus.rescheduled:
        return DeliveryStage.rescheduled;
      case DeliveryStatus.returningToHub:
        return DeliveryStage.returningToHub;
      case DeliveryStatus.returnedToHub:
        return DeliveryStage.returnedToHub;
      case DeliveryStatus.completed:
        return DeliveryStage.completed;
    }
  }

  static DeliveryStatus fromStage(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.accepted:
        return DeliveryStatus.assignedToRider;
      case DeliveryStage.pickedUp:
        return DeliveryStatus.pickedUpFromHub;
      case DeliveryStage.outForDelivery:
        return DeliveryStatus.outForDelivery;
      case DeliveryStage.arrived:
        return DeliveryStatus.arrived;
      case DeliveryStage.delivered:
        return DeliveryStatus.delivered;
      case DeliveryStage.failed:
        return DeliveryStatus.deliveryFailed;
      case DeliveryStage.rescheduled:
        return DeliveryStatus.rescheduled;
      case DeliveryStage.returningToHub:
        return DeliveryStatus.returningToHub;
      case DeliveryStage.returnedToHub:
        return DeliveryStatus.returnedToHub;
      case DeliveryStage.completed:
        return DeliveryStatus.completed;
    }
  }
}

/// Standardized status update payload adhering strictly to ERP requirements:
/// parcelId, riderId, status, timestamp, latitude, longitude, failureReason, proofUrl, codAmount
class DeliveryStatusPayload {
  const DeliveryStatusPayload({
    required this.parcelId,
    required this.riderId,
    required this.status,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.failureReason,
    this.proofUrl,
    this.codAmount,
  });

  final String parcelId;
  final String riderId;
  final String status;
  final String timestamp;
  final double latitude;
  final double longitude;
  final String? failureReason;
  final String? proofUrl;
  final double? codAmount;

  Map<String, dynamic> toJson() => {
        'parcelId': parcelId,
        'riderId': riderId,
        'status': status,
        'timestamp': timestamp,
        'latitude': latitude,
        'longitude': longitude,
        if (failureReason != null) 'failureReason': failureReason,
        if (proofUrl != null) 'proofUrl': proofUrl,
        if (codAmount != null) 'codAmount': codAmount,
      };

  factory DeliveryStatusPayload.fromJson(Map<String, dynamic> json) {
    return DeliveryStatusPayload(
      parcelId: json['parcelId']?.toString() ?? '',
      riderId: json['riderId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0.0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0.0') ?? 0.0,
      failureReason: json['failureReason']?.toString(),
      proofUrl: json['proofUrl']?.toString(),
      codAmount: json['codAmount'] != null
          ? double.tryParse(json['codAmount'].toString())
          : null,
    );
  }
}

