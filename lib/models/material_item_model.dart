/// نموذج خامة في المخزون - يتتبّع الكمية المتاحة وحد التنبيه الأدنى
class MaterialItemModel {
  final String id;
  final String name;
  final String unit; // متر، كيلو، قطعة...
  final double quantity;
  final double minThreshold;
  final DateTime updatedAt;

  MaterialItemModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.minThreshold,
    required this.updatedAt,
  });

  /// وصلت الكمية للحد الأدنى أو أقل - تُستخدم لتلوين العنصر وتشغيل التنبيه
  bool get isLow => quantity <= minThreshold;

  factory MaterialItemModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return MaterialItemModel(
      id: id,
      name: map['name']?.toString() ?? '',
      unit: map['unit']?.toString() ?? 'قطعة',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      minThreshold: (map['minThreshold'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'minThreshold': minThreshold,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}
