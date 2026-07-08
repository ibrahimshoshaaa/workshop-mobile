/// نموذج المصروف - Realtime Database
class ExpenseModel {
  final String id;
  final double amount;
  final String category; // materials | rent | wages | other
  final String description;
  final String? workerName;
  final DateTime date;

  ExpenseModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    this.workerName,
    required this.date,
  });

  factory ExpenseModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ExpenseModel(
      id: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: map['category']?.toString() ?? 'other',
      description: map['description']?.toString() ?? '',
      workerName: map['workerName']?.toString(),
      date: DateTime.fromMillisecondsSinceEpoch(
        (map['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      if (workerName != null) 'workerName': workerName,
      'date': date.millisecondsSinceEpoch,
    };
  }
}
