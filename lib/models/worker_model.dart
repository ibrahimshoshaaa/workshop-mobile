/// نموذج العامل (صنايعي/محاسب/مدير... أي وظيفة تتضاف وقت إضافة العامل
/// نفسه - مفيش قايمة وظايف ثابتة) - Realtime Database
class WorkerModel {
  final String id;
  final String name;
  final String jobTitle;
  /// نوع المرتب: monthly / weekly / daily
  final String salaryType;
  final double salaryAmount;
  /// يوم القبض الأسبوعي (1=الاثنين ... 7=الأحد، زي DateTime.weekday) -
  /// مستخدم بس لو salaryType == weekly، افتراضيًا الخميس (4)
  final int payWeekday;
  final String phone;
  final String notes;
  final DateTime createdAt;

  WorkerModel({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.salaryType,
    required this.salaryAmount,
    this.payWeekday = 4,
    this.phone = '',
    this.notes = '',
    required this.createdAt,
  });

  factory WorkerModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return WorkerModel(
      id: id,
      name: map['name']?.toString() ?? '',
      jobTitle: map['jobTitle']?.toString() ?? '',
      salaryType: map['salaryType']?.toString() ?? 'monthly',
      salaryAmount: (map['salaryAmount'] as num?)?.toDouble() ?? 0,
      payWeekday: (map['payWeekday'] as num?)?.toInt() ?? 4,
      phone: map['phone']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'jobTitle': jobTitle,
      'salaryType': salaryType,
      'salaryAmount': salaryAmount,
      'payWeekday': payWeekday,
      'phone': phone,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  WorkerModel copyWith({
    String? name,
    String? jobTitle,
    String? salaryType,
    double? salaryAmount,
    int? payWeekday,
    String? phone,
    String? notes,
  }) {
    return WorkerModel(
      id: id,
      name: name ?? this.name,
      jobTitle: jobTitle ?? this.jobTitle,
      salaryType: salaryType ?? this.salaryType,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      payWeekday: payWeekday ?? this.payWeekday,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

/// سجل تأكيد قبض العامل - كل مرة يتأكد فيها إن العامل قبض مرتبه بيتسجل
/// سطر هنا، وبيترتبط أوتوماتيك بمصروف من نوع "أجور"
class WorkerPaymentModel {
  final String id;
  final String workerId;
  final String workerName;
  final double amount;
  final DateTime paymentDate;
  /// بداية دورة الاستحقاق (منتصف الليل) - بنستخدمها نتأكد إن العامل
  /// اتقبض مرة واحدة بس في نفس الدورة (الأسبوع/اليوم/الشهر)
  final DateTime periodStart;
  final String? expenseId;

  WorkerPaymentModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.amount,
    required this.paymentDate,
    required this.periodStart,
    this.expenseId,
  });

  factory WorkerPaymentModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return WorkerPaymentModel(
      id: id,
      workerId: map['workerId']?.toString() ?? '',
      workerName: map['workerName']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paymentDate: DateTime.fromMillisecondsSinceEpoch(
        (map['paymentDate'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      periodStart: DateTime.fromMillisecondsSinceEpoch(
        (map['periodStart'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      expenseId: map['expenseId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'amount': amount,
      'paymentDate': paymentDate.millisecondsSinceEpoch,
      'periodStart': periodStart.millisecondsSinceEpoch,
      if (expenseId != null) 'expenseId': expenseId,
    };
  }
}
