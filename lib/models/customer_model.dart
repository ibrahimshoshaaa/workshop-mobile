/// نموذج العميل - مصمم للعمل مع Realtime Database
class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final int serialNumber;
  final DateTime createdAt;
  final bool isArchived;
  final DateTime? archivedAt;
  final int? archiveYear;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.serialNumber = 0,
    required this.createdAt,
    this.isArchived = false,
    this.archivedAt,
    this.archiveYear,
  });

  factory CustomerModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final archivedAtMs = (map['archivedAt'] as num?)?.toInt();
    return CustomerModel(
      id: id,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      serialNumber: (map['serialNumber'] as num?)?.toInt() ?? 0,
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
      'name': name,
      'phone': phone,
      'address': address,
      'serialNumber': serialNumber,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isArchived': isArchived,
      'archivedAt': archivedAt?.millisecondsSinceEpoch,
      'archiveYear': archiveYear,
    };
  }

  CustomerModel copyWith({
    String? name,
    String? phone,
    String? address,
    int? serialNumber,
    bool? isArchived,
    DateTime? archivedAt,
    int? archiveYear,
    bool clearArchive = false,
  }) {
    return CustomerModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      serialNumber: serialNumber ?? this.serialNumber,
      createdAt: createdAt,
      isArchived: clearArchive ? false : (isArchived ?? this.isArchived),
      archivedAt: clearArchive ? null : (archivedAt ?? this.archivedAt),
      archiveYear: clearArchive ? null : (archiveYear ?? this.archiveYear),
    );
  }
}
