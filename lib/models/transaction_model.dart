/// نموذج معاملة مالية (عربون أو دفعة/قسط) مرتبطة بطلب معيّن - Realtime Database
class TransactionModel {
  final String id;
  final String orderId;
  final String customerId;
  final double amountPaid;
  final DateTime paymentDate;
  final String paymentType; // 'deposit' | 'installment'

  TransactionModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentType,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'amountPaid': amountPaid,
      'paymentDate': paymentDate.millisecondsSinceEpoch,
      'paymentType': paymentType,
    };
  }
}
