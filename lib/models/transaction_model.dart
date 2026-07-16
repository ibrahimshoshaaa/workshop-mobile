/// نموذج معاملة مالية (عربون أو دفعة/قسط) مرتبطة بطلب معيّن - Realtime Database
class TransactionModel {
  final String id;
  final String orderId;
  final String customerId;
  final double amountPaid;
  final DateTime paymentDate;
  final String paymentType; // 'deposit' | 'installment'
  /// طريقة استلام المبلغ: cash (نقدي) / instapay (إنستاباي)
  final String paymentMethod;
  /// حالة الدفعة: pending (معلقة) / completed (مكتملة)
  final String status;

  TransactionModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentType,
    this.paymentMethod = 'cash',
    this.status = 'completed',
  });

  factory TransactionModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return TransactionModel(
      id: id,
      orderId: map['orderId']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
      paymentDate: DateTime.fromMillisecondsSinceEpoch(
        (map['paymentDate'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      paymentType: map['paymentType']?.toString() ?? 'installment',
      paymentMethod: map['paymentMethod']?.toString() ?? 'cash',
      status: map['status']?.toString() ?? 'completed',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'amountPaid': amountPaid,
      'paymentDate': paymentDate.millisecondsSinceEpoch,
      'paymentType': paymentType,
      'paymentMethod': paymentMethod,
      'status': status,
    };
  }
}
