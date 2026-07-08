/// نموذج العميل - مصمم للعمل مع Realtime Database (مش Firestore)
/// التواريخ بتتخزن كـ milliseconds (رقم عادي) بدل Timestamp object،
/// عشان تبقى أبسط وأسهل في القراءة والتخزين بدون أي تعقيد إضافي
class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.createdAt,
  });

  factory CustomerModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return CustomerModel(
      id: id,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
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
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  CustomerModel copyWith({
    String? name,
    String? phone,
    String? address,
  }) {
    return CustomerModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt,
    );
  }
}
