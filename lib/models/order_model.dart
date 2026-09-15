/// نموذج الطلب - مصمم للعمل مع Realtime Database
class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String itemType;
  final String details;
  final List<String> images;
  final String status;
  final double totalAmount;
  final double totalPaid;
  final double discountAmount;
  final String discountReason;
  final DateTime deliveryDate;
  final DateTime createdAt;
  final bool isArchived;
  final DateTime? archivedAt;
  final int? archiveYear;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.itemType,
    required this.details,
    required this.images,
    required this.status,
    required this.totalAmount,
    required this.totalPaid,
    this.discountAmount = 0,
    this.discountReason = '',
    required this.deliveryDate,
    required this.createdAt,
    this.isArchived = false,
    this.archivedAt,
    this.archiveYear,
  });

  double get remainingAmount => totalAmount - discountAmount - totalPaid;
  bool get isFullyPaid => remainingAmount <= 0;

  factory OrderModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final imagesRaw = map['images'];
    final images = <String>[];
    if (imagesRaw is Map) {
      images.addAll(imagesRaw.values.map((v) => v.toString()));
    } else if (imagesRaw is List) {
      images.addAll(imagesRaw.map((v) => v.toString()));
    }
    final archivedAtMs = (map['archivedAt'] as num?)?.toInt();
    return OrderModel(
      id: id,
      customerId: map['customerId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      itemType: map['itemType']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      images: images,
      status: map['status']?.toString() ?? 'جاري التجهيز',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0,
      discountReason: map['discountReason']?.toString() ?? '',
      deliveryDate: DateTime.fromMillisecondsSinceEpoch(
        (map['deliveryDate'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isArchived: map['isArchived'] == true,
      archivedAt: archivedAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(archivedAtMs),
      archiveYear: (map['archiveYear'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'itemType': itemType,
      'details': details,
      'images': images,
      'status': status,
      'totalAmount': totalAmount,
      'totalPaid': totalPaid,
      'discountAmount': discountAmount,
      'discountReason': discountReason,
      'deliveryDate': deliveryDate.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isArchived': isArchived,
      'archivedAt': archivedAt?.millisecondsSinceEpoch,
      'archiveYear': archiveYear,
    };
  }

  OrderModel copyWith({
    String? id,
    String? itemType,
    String? details,
    List<String>? images,
    String? status,
    double? totalAmount,
    double? totalPaid,
    double? discountAmount,
    String? discountReason,
    DateTime? deliveryDate,
    bool? isArchived,
    DateTime? archivedAt,
    int? archiveYear,
    bool clearArchive = false,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId,
      customerName: customerName,
      itemType: itemType ?? this.itemType,
      details: details ?? this.details,
      images: images ?? this.images,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      totalPaid: totalPaid ?? this.totalPaid,
      discountAmount: discountAmount ?? this.discountAmount,
      discountReason: discountReason ?? this.discountReason,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      createdAt: createdAt,
      isArchived: clearArchive ? false : (isArchived ?? this.isArchived),
      archivedAt: clearArchive ? null : (archivedAt ?? this.archivedAt),
      archiveYear: clearArchive ? null : (archiveYear ?? this.archiveYear),
    );
  }
}
