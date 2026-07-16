/// نموذج العميل - مصمم للعمل مع Realtime Database (مش Firestore)
/// التواريخ بتتخزن كـ milliseconds (رقم عادي) بدل Timestamp object،
/// عشان تبقى أبسط وأسهل في القراءة والتخزين بدون أي تعقيد إضافي
class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  /// رقم تسلسلي فريد وثابت للعميل - بيتحدد مرة واحدة وقت الإضافة ومبيتغيرش
  /// بعد كده، ومش بيتكرر أبدًا حتى لو اتحذف عميل تاني قبله (نفس منطق الديسكتوب)
  final int serialNumber;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.serialNumber = 0,
    required this.createdAt,
  });

  factory CustomerModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return CustomerModel(
      id: id,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      serialNumber: (map['serialNumber'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'serialNumber': serialNumber,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  CustomerModel copyWith({
    String? name,
    String? phone,
    String? address,
    int? serialNumber,
  }) {
    return CustomerModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      serialNumber: serialNumber ?? this.serialNumber,
      createdAt: createdAt,
    );
  }
}
