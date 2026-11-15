class DeliveryRequest {
  const DeliveryRequest({
    required this.id,
    required this.store,
    required this.pickup,
    required this.dropoff,
    required this.fee,
    required this.distance,
    required this.eta,
    this.stage = DeliveryStage.accepted,
    this.recipientName,
    this.recipientPhone,
    this.trackingNumber,
    this.barcode,
    this.area,
    this.landmark,
    this.codAmount = 0.0,
    this.isCod = false,
    this.isCodRemitted = false,
    this.stopOrder = 1,
    this.failureReason,
    this.failureNotes,
    this.podPhotoPath,
    this.podVideoPath,
    this.podSignature,
    this.podOtp,
    this.assignedAt,
    this.scannedAt,
    this.deliveredAt,
    this.isReturnRefund = false,
    this.returnReason,
    this.returnDetails,
    this.sellerNote,
    this.returnStatus,
    this.returnItems,
    this.returnEvidence,
    this.metadata,
  });

  final String id;
  final String store;
  final String pickup;
  final String dropoff;
  final String fee;
  final String distance;
  final String eta;
  final DeliveryStage stage;
  final String? recipientName;
  final String? recipientPhone;
  final String? trackingNumber;
  final String? barcode;
  final String? area;
  final String? landmark;
  final double codAmount;
  final bool isCod;
  final bool isCodRemitted;
  final int stopOrder;
  final String? failureReason;
  final String? failureNotes;
  final String? podPhotoPath;
  final String? podVideoPath;
  final String? podSignature;
  final String? podOtp;
  final DateTime? assignedAt;
  final DateTime? scannedAt;
  final DateTime? deliveredAt;
  final bool isReturnRefund;
  final String? returnReason;
  final String? returnDetails;
  final String? sellerNote;
  final String? returnStatus;
  final List<dynamic>? returnItems;
  final List<dynamic>? returnEvidence;
  final Map<String, dynamic>? metadata;

  // Parcel delivery aliases and helpers
  String get parcelId => id;
  String get receiverName => recipientName ?? 'Receiver';
  String get receiverPhone => recipientPhone ?? '';
  String get receiverAddress => dropoff;
  String get deliveryArea =>
      area ?? (dropoff.contains(',') ? dropoff.split(',')[0].trim() : 'Metro Area');
  String get formattedCod =>
      isCod && codAmount > 0 ? '₱${codAmount.toStringAsFixed(2)}' : 'PREPAID';

  bool get isAssigned => stage == DeliveryStage.accepted;
  bool get isPickedUp => stage == DeliveryStage.pickedUp;
  bool get isOutForDelivery =>
      stage == DeliveryStage.outForDelivery || stage == DeliveryStage.arrived;
  bool get isDelivered =>
      stage == DeliveryStage.delivered || stage == DeliveryStage.completed;
  bool get isFailed =>
      stage == DeliveryStage.failed || stage == DeliveryStage.rescheduled;
  bool get isReturnedToHub => stage == DeliveryStage.returnedToHub;
  bool get isReturningToHub => stage == DeliveryStage.returningToHub;
  bool get isItemInHand => stage == DeliveryStage.returningToHub;
  bool get isReturnPendingPickup =>
      isReturnRefund &&
      !isReturnResolvedOrDeliveredInHub &&
      stage != DeliveryStage.returningToHub &&
      stage != DeliveryStage.returnedToHub;

  /// True if a Return / Refund case has already been resolved or delivered/returned in the hub
  bool get isReturnResolvedOrDeliveredInHub {
    if (stage == DeliveryStage.returnedToHub) return true;
    final statusLower = (returnStatus ?? '').trim().toLowerCase();
    if (statusLower == 'returned_to_hub' ||
        statusLower == 'received_at_hub' ||
        statusLower == 'hub_received' ||
        statusLower == 'returned' ||
        statusLower == 'approved' ||
        statusLower == 'rejected' ||
        statusLower == 'resolved' ||
        statusLower == 'completed' ||
        statusLower == 'cancelled' ||
        statusLower == 'refunded' ||
        statusLower == 'under_review') {
      return true;
    }
    final meta = metadata ?? const <String, dynamic>{};
    if (meta['is_return_resolved'] == true) return true;
    if (meta['return_resolved_at'] != null &&
        meta['return_resolved_at'].toString().trim().isNotEmpty) {
      return true;
    }
    if (meta['returned_to_hub_at'] != null &&
        meta['returned_to_hub_at'].toString().trim().isNotEmpty) {
      return true;
    }
    final stageMeta = (meta['return_stage'] ?? '').toString().trim().toLowerCase();
    if (stageMeta == 'returned_to_hub' ||
        stageMeta == 'received_at_hub' ||
        stageMeta == 'resolved' ||
        stageMeta == 'completed' ||
        stageMeta == 'cancelled') {
      return true;
    }
    final resMeta = (meta['return_resolution'] ?? '').toString().trim().toLowerCase();
    if (resMeta.contains('returned to hub') ||
        resMeta.contains('approve refund') ||
        resMeta.contains('rejected') ||
        resMeta.contains('cancelled') ||
        resMeta.contains('refunded') ||
        resMeta.contains('under review') ||
        resMeta.contains('received at hub')) {
      return true;
    }
    if (isReturnRefund &&
        (stage == DeliveryStage.delivered || stage == DeliveryStage.completed) &&
        statusLower != 'approved_for_pickup' &&
        statusLower != 'in_rider_hands' &&
        statusLower != 'in_transit_to_hub') {
      return true;
    }
    return false;
  }

  // Effective reason and details for display
  String get effectiveReturnReason {
    if (returnReason != null && returnReason!.trim().isNotEmpty) {
      return returnReason!.trim();
    }
    if (failureReason != null && failureReason!.trim().isNotEmpty) {
      return failureReason!.trim();
    }
    return 'Return / Refund Request';
  }

  String get effectiveReturnDetails {
    if (returnDetails != null && returnDetails!.trim().isNotEmpty) {
      return returnDetails!.trim();
    }
    if (failureNotes != null && failureNotes!.trim().isNotEmpty) {
      return failureNotes!.trim();
    }
    return 'Buyer requested return / refund for this order.';
  }

  List<String> get resolvedReturnEvidenceUrls {
    final list = <String>[];
    if (returnEvidence != null) {
      for (final item in returnEvidence!) {
        if (item is String && item.trim().isNotEmpty) {
          list.add(item.trim());
        } else if (item is Map) {
          final url = item['url']?.toString() ?? item['path']?.toString() ?? item['src']?.toString();
          if (url != null && url.trim().isNotEmpty) {
            list.add(url.trim());
          }
        }
      }
    }
    if (podPhotoPath != null && podPhotoPath!.trim().isNotEmpty && !list.contains(podPhotoPath!.trim())) {
      list.add(podPhotoPath!.trim());
    }
    if (podVideoPath != null && podVideoPath!.trim().isNotEmpty && !list.contains(podVideoPath!.trim())) {
      list.add(podVideoPath!.trim());
    }
    return list;
  }

  DeliveryRequest copyWith({
    String? id,
    String? store,
    String? pickup,
    String? dropoff,
    String? fee,
    String? distance,
    String? eta,
    DeliveryStage? stage,
    String? recipientName,
    String? recipientPhone,
    String? trackingNumber,
    String? barcode,
    String? area,
    String? landmark,
    double? codAmount,
    bool? isCod,
    bool? isCodRemitted,
    int? stopOrder,
    String? failureReason,
    String? failureNotes,
    String? podPhotoPath,
    String? podVideoPath,
    String? podSignature,
    String? podOtp,
    DateTime? assignedAt,
    DateTime? scannedAt,
    DateTime? deliveredAt,
    bool? isReturnRefund,
    String? returnReason,
    String? returnDetails,
    String? sellerNote,
    String? returnStatus,
    List<dynamic>? returnItems,
    List<dynamic>? returnEvidence,
    Map<String, dynamic>? metadata,
  }) {
    return DeliveryRequest(
      id: id ?? this.id,
      store: store ?? this.store,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      fee: fee ?? this.fee,
      distance: distance ?? this.distance,
      eta: eta ?? this.eta,
      stage: stage ?? this.stage,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      barcode: barcode ?? this.barcode,
      area: area ?? this.area,
      landmark: landmark ?? this.landmark,
      codAmount: codAmount ?? this.codAmount,
      isCod: isCod ?? this.isCod,
      isCodRemitted: isCodRemitted ?? this.isCodRemitted,
      stopOrder: stopOrder ?? this.stopOrder,
      failureReason: failureReason ?? this.failureReason,
      failureNotes: failureNotes ?? this.failureNotes,
      podPhotoPath: podPhotoPath ?? this.podPhotoPath,
      podVideoPath: podVideoPath ?? this.podVideoPath,
      podSignature: podSignature ?? this.podSignature,
      podOtp: podOtp ?? this.podOtp,
      assignedAt: assignedAt ?? this.assignedAt,
      scannedAt: scannedAt ?? this.scannedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      isReturnRefund: isReturnRefund ?? this.isReturnRefund,
      returnReason: returnReason ?? this.returnReason,
      returnDetails: returnDetails ?? this.returnDetails,
      sellerNote: sellerNote ?? this.sellerNote,
      returnStatus: returnStatus ?? this.returnStatus,
      returnItems: returnItems ?? this.returnItems,
      returnEvidence: returnEvidence ?? this.returnEvidence,
      metadata: metadata ?? this.metadata,
    );
  }

  factory DeliveryRequest.fromJson(Map<String, dynamic> json) {
    DeliveryStage stage = DeliveryStage.accepted;
    final stageStr = (json['stage'] ?? json['status'] ?? json['status_code'] ?? '').toString().toLowerCase();

    if (stageStr == 'pickedup' || stageStr == 'picked_up' || stageStr == 'picked_up_from_hub' || stageStr == 'rider_received' || stageStr == 'sorted' || stageStr == 'pickup_hub') {
      stage = DeliveryStage.pickedUp;
    } else if (stageStr == 'out_for_delivery' || stageStr == 'outfordelivery' || stageStr == 'in_transit') {
      stage = DeliveryStage.outForDelivery;
    } else if (stageStr == 'arrived' || stageStr == 'arrived_at_stop') {
      stage = DeliveryStage.arrived;
    } else if (stageStr == 'delivered') {
      stage = DeliveryStage.delivered;
    } else if (stageStr == 'completed') {
      stage = DeliveryStage.completed;
    } else if (stageStr == 'failed' || stageStr == 'delivery_failed' || stageStr == 'exception' || stageStr == 'return_refund' || stageStr == 'return/refund') {
      stage = DeliveryStage.failed;
    } else if (stageStr == 'rescheduled') {
      stage = DeliveryStage.rescheduled;
    } else if (stageStr == 'returning' || stageStr == 'returning_to_hub') {
      stage = DeliveryStage.returningToHub;
    } else if (stageStr == 'returned' || stageStr == 'returned_to_hub') {
      stage = DeliveryStage.returnedToHub;
    }

    final codVal = json['cod_amount'] != null
        ? double.tryParse(json['cod_amount'].toString()) ?? 0.0
        : 0.0;
    final isCodVal = json['is_cod'] == true || codVal > 0;

    final rawBarcode = json['barcode']?.toString();
    final barcodeVal = (rawBarcode != null && rawBarcode.trim().isNotEmpty)
        ? rawBarcode.trim()
        : (json['parcel_number']?.toString() ?? json['id']?.toString() ?? '');

    final rawMeta = json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : <String, dynamic>{};
    if (json['assigned_rider_name'] != null) {
      rawMeta['assigned_rider_name'] = json['assigned_rider_name'];
    }
    if (json['assigned_rider_id'] != null) {
      rawMeta['assigned_rider_id'] = json['assigned_rider_id'];
    }
    final bool isReturnVal = json['is_return_refund'] == true ||
        rawMeta['is_return_refund'] == true ||
        json['return_status'] != null ||
        rawMeta['return_status'] != null ||
        stageStr == 'returned' ||
        stageStr == 'returned_to_hub' ||
        stageStr == 'return_refund';

    final returnReasonVal = json['return_reason']?.toString() ??
        rawMeta['return_reason']?.toString() ??
        json['failure_reason']?.toString() ??
        rawMeta['failure_reason']?.toString();

    final returnDetailsVal = json['return_details']?.toString() ??
        rawMeta['return_details']?.toString() ??
        json['failure_notes']?.toString() ??
        rawMeta['failure_notes']?.toString();

    final sellerNoteVal = json['seller_note']?.toString() ??
        rawMeta['seller_note']?.toString();

    final returnStatusVal = json['return_status']?.toString() ??
        rawMeta['return_status']?.toString();
    final returnStatusLower = (returnStatusVal ?? '').trim().toLowerCase();
    final hasResolvedTimestamp = (rawMeta['return_resolved_at'] != null &&
            rawMeta['return_resolved_at'].toString().trim().isNotEmpty) ||
        (rawMeta['returned_to_hub_at'] != null &&
            rawMeta['returned_to_hub_at'].toString().trim().isNotEmpty) ||
        rawMeta['is_return_resolved'] == true;

    if (returnStatusLower == 'returned_to_hub' ||
        returnStatusLower == 'received_at_hub' ||
        returnStatusLower == 'hub_received' ||
        returnStatusLower == 'returned' ||
        returnStatusLower == 'approved' ||
        returnStatusLower == 'rejected' ||
        returnStatusLower == 'resolved' ||
        returnStatusLower == 'completed' ||
        returnStatusLower == 'cancelled' ||
        returnStatusLower == 'refunded' ||
        returnStatusLower == 'under_review' ||
        hasResolvedTimestamp) {
      stage = DeliveryStage.returnedToHub;
    } else if ((returnStatusLower == 'in_rider_hands' || returnStatusLower == 'in_transit_to_hub') &&
        stage != DeliveryStage.returnedToHub) {
      stage = DeliveryStage.returningToHub;
    }

    final returnItemsVal = json['return_items'] is List
        ? (json['return_items'] as List)
        : (rawMeta['return_items'] is List ? (rawMeta['return_items'] as List) : null);

    final returnEvidenceVal = json['return_evidence'] is List
        ? (json['return_evidence'] as List)
        : (rawMeta['return_evidence'] is List ? (rawMeta['return_evidence'] as List) : null);

    return DeliveryRequest(
      id: json['id']?.toString() ?? json['parcel_number']?.toString() ?? '',
      store: json['store']?.toString() ?? 'Central Hub',
      pickup: json['pickup']?.toString() ?? 'Hub Sorting Bin',
      dropoff: json['dropoff']?.toString() ?? json['address']?.toString() ?? '',
      fee: json['fee']?.toString() ?? '₱150.00',
      distance: json['distance']?.toString() ?? '3.5 km',
      eta: json['eta']?.toString() ?? '25 min',
      stage: stage,
      recipientName: json['recipient_name']?.toString() ?? json['recipientName']?.toString() ?? 'Receiver',
      recipientPhone: json['recipient_phone']?.toString() ?? json['recipientPhone']?.toString() ?? '',
      trackingNumber: json['tracking_number']?.toString() ?? json['tracking_code']?.toString(),
      barcode: barcodeVal,
      area: json['area']?.toString() ?? json['destination_area']?.toString(),
      landmark: json['landmark']?.toString() ?? json['notes']?.toString(),
      codAmount: codVal,
      isCod: isCodVal,
      isCodRemitted: json['is_cod_remitted'] == true ||
          json['cod_remitted'] == true ||
          json['cod_remit_status'] == 'awaiting_cashier' ||
          json['cod_remit_status'] == 'remitted',
      stopOrder: int.tryParse(json['stop_order']?.toString() ?? '1') ?? 1,
      failureReason: json['failure_reason']?.toString() ?? json['return_reason']?.toString(),
      failureNotes: json['failure_notes']?.toString() ?? json['return_notes']?.toString(),
      podPhotoPath: json['pod_photo_path']?.toString() ?? json['return_photo_url']?.toString(),
      podVideoPath: json['pod_video_path']?.toString() ?? json['return_video_url']?.toString(),
      podSignature: json['pod_signature']?.toString(),
      podOtp: json['pod_otp']?.toString(),
      isReturnRefund: isReturnVal,
      returnReason: returnReasonVal,
      returnDetails: returnDetailsVal,
      sellerNote: sellerNoteVal,
      returnStatus: returnStatusVal,
      returnItems: returnItemsVal,
      returnEvidence: returnEvidenceVal,
      metadata: rawMeta,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'store': store,
        'pickup': pickup,
        'dropoff': dropoff,
        'fee': fee,
        'distance': distance,
        'eta': eta,
        'stage': stage.name,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'tracking_number': trackingNumber,
        'barcode': barcode,
        'area': area,
        'landmark': landmark,
        'cod_amount': codAmount,
        'is_cod': isCod,
        'is_cod_remitted': isCodRemitted,
        'stop_order': stopOrder,
        'failure_reason': failureReason,
        'failure_notes': failureNotes,
        'pod_photo_path': podPhotoPath,
        'pod_video_path': podVideoPath,
        'pod_signature': podSignature,
        'pod_otp': podOtp,
        'is_return_refund': isReturnRefund,
        'return_reason': returnReason,
        'return_details': returnDetails,
        'seller_note': sellerNote,
        'return_status': returnStatus,
        'return_items': returnItems,
        'return_evidence': returnEvidence,
        'metadata': metadata,
      };
}

enum DeliveryStage {
  accepted,
  pickedUp,
  outForDelivery,
  arrived,
  delivered,
  failed,
  rescheduled,
  returningToHub,
  returnedToHub,
  completed,
}
