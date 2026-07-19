/// نموذج مديونية الورشة - الديون اللي على الورشة لصالح الموردين أو
/// الصنايعية (عكس مديونيات العملاء اللي هي فلوس لينا عندهم) - Realtime Database
class WorkshopDebtModel {
  final String id;
  /// اسم المورد/الصنايعي المستحق له المديونية (أو اسم العميل لو المديونية
  /// دي ناتجة عن دفعه أكتر من الاتفاق النهائي على طلب - راجع orderId)
  final String creditorName;
  final double totalAmount;
  /// إجمالي اللي اتسدد لحد دلوقتي من المديونية دي
  final double paidAmount;
  final String notes;
  /// لو المديونية دي اتولّدت تلقائيًا من طلب معيّن (العميل دفع أكتر من
  /// السعر النهائي بعد تعديله) - بيربطها بالطلب عشان تتحدّث/تتشال
  /// تلقائيًا لو السعر اتعدّل تاني. فاضي للمديونيات العادية
  final String orderId;
  final DateTime createdAt;

  WorkshopDebtModel({
    required this.id,
    required this.creditorName,
    required this.totalAmount,
    this.paidAmount = 0,
    this.notes = '',
    this.orderId = '',
    required this.createdAt,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get isFullyPaid => remainingAmount <= 0;

  factory WorkshopDebtModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return WorkshopDebtModel(
      id: id,
      creditorName: map['creditorName']?.toString() ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
      notes: map['notes']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creditorName': creditorName,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'notes': notes,
      'orderId': orderId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  WorkshopDebtModel copyWith({
    String? creditorName,
    double? totalAmount,
    double? paidAmount,
    String? notes,
  }) {
    return WorkshopDebtModel(
      id: id,
      creditorName: creditorName ?? this.creditorName,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      notes: notes ?? this.notes,
      orderId: orderId,
      createdAt: createdAt,
    );
  }
}
