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
  final DateTime deliveryDate;
  final DateTime createdAt;

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
    required this.deliveryDate,
    required this.createdAt,
  });

  /// المديونية المتبقية = الاتفاق - المدفوع (محسوبة دائمًا وليست مخزّنة لتفادي عدم التطابق)
  double get remainingAmount => totalAmount - totalPaid;

  bool get isFullyPaid => remainingAmount <= 0;

  factory OrderModel.fromMap(String id, Map<dynamic, dynamic> map) {
    // الصور بتتخزن في RTDB كـ Map بمفاتيح تلقائية (push keys) مش List عادية،
    // عشان الحذف/الإضافة يبقى أسهل وأأمن من تضارب الفهارس بين جهازين
    final imagesRaw = map['images'];
    final images = <String>[];
    if (imagesRaw is Map) {
      images.addAll(imagesRaw.values.map((v) => v.toString()));
    } else if (imagesRaw is List) {
      images.addAll(imagesRaw.map((v) => v.toString()));
    }

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
      deliveryDate: DateTime.fromMillisecondsSinceEpoch(
        (map['deliveryDate'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
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
      'deliveryDate': deliveryDate.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
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
    DateTime? deliveryDate,
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
      deliveryDate: deliveryDate ?? this.deliveryDate,
      createdAt: createdAt,
    );
  }
}
