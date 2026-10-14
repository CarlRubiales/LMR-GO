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
    this.stopOrder = 1,
    this.failureReason,
    this.failureNotes,
    this.podPhotoPath,
    this.podSignature,
    this.podOtp,
    this.assignedAt,
    this.scannedAt,
    this.deliveredAt,
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
  final int stopOrder;
  final String? failureReason;
  final String? failureNotes;
  final String? podPhotoPath;
  final String? podSignature;
  final String? podOtp;
  final DateTime? assignedAt;
  final DateTime? scannedAt;
  final DateTime? deliveredAt;

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
    int? stopOrder,
    String? failureReason,
    String? failureNotes,
    String? podPhotoPath,
    String? podSignature,
    String? podOtp,
    DateTime? assignedAt,
    DateTime? scannedAt,
    DateTime? deliveredAt,
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
      stopOrder: stopOrder ?? this.stopOrder,
      failureReason: failureReason ?? this.failureReason,
      failureNotes: failureNotes ?? this.failureNotes,
      podPhotoPath: podPhotoPath ?? this.podPhotoPath,
      podSignature: podSignature ?? this.podSignature,
      podOtp: podOtp ?? this.podOtp,
      assignedAt: assignedAt ?? this.assignedAt,
      scannedAt: scannedAt ?? this.scannedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }

  factory DeliveryRequest.fromJson(Map<String, dynamic> json) {
    DeliveryStage stage = DeliveryStage.accepted;
    final stageStr = (json['stage'] ?? json['status'] ?? '').toString().toLowerCase();

    if (stageStr == 'pickedup' || stageStr == 'sorted' || stageStr == 'pickup_hub') {
      stage = DeliveryStage.pickedUp;
    } else if (stageStr == 'out_for_delivery' || stageStr == 'outfordelivery' || stageStr == 'in_transit') {
      stage = DeliveryStage.outForDelivery;
    } else if (stageStr == 'arrived' || stageStr == 'arrived_at_stop') {
      stage = DeliveryStage.arrived;
    } else if (stageStr == 'delivered') {
      stage = DeliveryStage.delivered;
    } else if (stageStr == 'completed') {
      stage = DeliveryStage.completed;
    } else if (stageStr == 'failed' || stageStr == 'delivery_failed') {
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

    return DeliveryRequest(
      id: json['id']?.toString() ?? '',
      store: json['store']?.toString() ?? 'Central Hub',
      pickup: json['pickup']?.toString() ?? 'Hub Sorting Bin',
      dropoff: json['dropoff']?.toString() ?? '',
      fee: json['fee']?.toString() ?? '₱150.00',
      distance: json['distance']?.toString() ?? '3.5 km',
      eta: json['eta']?.toString() ?? '25 min',
      stage: stage,
      recipientName: json['recipient_name']?.toString() ?? json['recipientName']?.toString(),
      recipientPhone: json['recipient_phone']?.toString() ?? json['recipientPhone']?.toString(),
      trackingNumber: json['tracking_number']?.toString(),
      barcode: json['barcode']?.toString() ?? json['id']?.toString(),
      area: json['area']?.toString(),
      landmark: json['landmark']?.toString(),
      codAmount: codVal,
      isCod: isCodVal,
      stopOrder: int.tryParse(json['stop_order']?.toString() ?? '1') ?? 1,
      failureReason: json['failure_reason']?.toString(),
      failureNotes: json['failure_notes']?.toString(),
      podPhotoPath: json['pod_photo_path']?.toString(),
      podSignature: json['pod_signature']?.toString(),
      podOtp: json['pod_otp']?.toString(),
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
        'stop_order': stopOrder,
        'failure_reason': failureReason,
        'failure_notes': failureNotes,
        'pod_photo_path': podPhotoPath,
        'pod_signature': podSignature,
        'pod_otp': podOtp,
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
