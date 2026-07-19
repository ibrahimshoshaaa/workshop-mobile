/// نموذج "سحب إنستاباي كاش" - عملية سحب رصيد إنستاباي عن طريق ماكينة
/// صراف آلي (ATM) وتحويله لسيولة نقدية (كاش) في الخزينة. العملية دي
/// مش مصروف حقيقي ومش إيراد جديد - هي بس نقل نفس الفلوس من مصدر
/// (إنستاباي) لمصدر تاني (كاش)، فبتتخزن في عقدة منفصلة عشان متأثرش
/// على "إجمالي المصروفات" أو "إجمالي الإيرادات" في التقارير.
class CashTransferModel {
  final String id;
  final double amount;
  final String note;
  final DateTime date;

  CashTransferModel({
    required this.id,
    required this.amount,
    this.note = '',
    required this.date,
  });

  factory CashTransferModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return CashTransferModel(
      id: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      note: map['note']?.toString() ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        (map['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'note': note,
      'date': date.millisecondsSinceEpoch,
    };
  }
}
