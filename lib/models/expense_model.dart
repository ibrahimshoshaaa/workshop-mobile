import 'dart:convert';

/// تقسيم مصروف واحد على أكتر من طلب في نفس الوقت
class ExpenseOrderAllocation {
  final String orderId;
  final String customerId;
  final String customerName;
  final double amount;

  ExpenseOrderAllocation({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.amount,
  });

  factory ExpenseOrderAllocation.fromMap(Map<dynamic, dynamic> map) {
    return ExpenseOrderAllocation(
      orderId: map['orderId']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'customerId': customerId,
        'customerName': customerName,
        'amount': amount,
      };
}

/// نموذج المصروف - Realtime Database
class ExpenseModel {
  final String id;
  final double amount;
  final String category; // materials | rent | wages | workshop_debt | other
  final String description;
  final String? workerName;
  /// لو المصروف ده مرتبط بطلب/عميل معيّن (زي مصروف بيتسجل من جوه تفاصيل
  /// الطلب) - بيفضل null للمصروفات العامة (إيجار، أجور... إلخ)
  final String? orderId;
  final String? customerId;
  final String? customerName;
  /// مصدر خروج المبلغ من الخزينة: cash / instapay
  final String paymentMethod;
  /// لو المصروف ده سداد لمديونية ورشة (مورد/صنايعي) - بيربطه بسجل
  /// المديونية، وبيفضل null لباقي المصروفات العادية
  final String? workshopDebtId;
  /// تقسيم المصروف على أكتر من طلب
  final List<ExpenseOrderAllocation> orderAllocations;
  final DateTime date;

  ExpenseModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    this.workerName,
    this.orderId,
    this.customerId,
    this.customerName,
    this.paymentMethod = 'cash',
    this.workshopDebtId,
    this.orderAllocations = const [],
    required this.date,
  });

  factory ExpenseModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final allocationsRaw = map['orderAllocationsJson'];
    final allocations = <ExpenseOrderAllocation>[];
    if (allocationsRaw is String && allocationsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(allocationsRaw) as List;
        allocations.addAll(decoded.map((e) => ExpenseOrderAllocation.fromMap(e as Map)));
      } catch (_) {}
    }
    return ExpenseModel(
      id: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: map['category']?.toString() ?? 'other',
      description: map['description']?.toString() ?? '',
      workerName: map['workerName']?.toString(),
      orderId: map['orderId']?.toString(),
      customerId: map['customerId']?.toString(),
      customerName: map['customerName']?.toString(),
      paymentMethod: map['paymentMethod']?.toString() ?? 'cash',
      workshopDebtId: map['workshopDebtId']?.toString(),
      orderAllocations: allocations,
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
      if (orderId != null) 'orderId': orderId,
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      'paymentMethod': paymentMethod,
      if (workshopDebtId != null) 'workshopDebtId': workshopDebtId,
      'orderAllocationsJson': jsonEncode(orderAllocations.map((a) => a.toMap()).toList()),
      'date': date.millisecondsSinceEpoch,
    };
  }

  ExpenseModel copyWith({
    double? amount,
    String? category,
    String? description,
    String? workerName,
    String? orderId,
    String? customerId,
    String? customerName,
    String? paymentMethod,
    String? workshopDebtId,
    List<ExpenseOrderAllocation>? orderAllocations,
    DateTime? date,
  }) {
    return ExpenseModel(
      id: id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      workerName: workerName ?? this.workerName,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      workshopDebtId: workshopDebtId ?? this.workshopDebtId,
      orderAllocations: orderAllocations ?? this.orderAllocations,
      date: date ?? this.date,
    );
  }
}
