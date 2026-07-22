/// ثوابت التطبيق العامة - الفئات، الحالات، أنواع الأصناف

class AppConstants {
  AppConstants._();

  // أنواع أصناف الأثاث
  static const List<String> itemTypes = [
    'أنتريه',
    'صالون',
    'ركنة',
    'ستائر',
    'سرير',
    'كنب',
    'أخرى',
  ];
  // وحدات قياس الخامات
  static const List<String> materialUnits = [
    'متر',
    'كيلو',
    'قطعة',
    'لفة',
    'لتر',
  ];

  // حالات الطلب
  static const List<String> orderStatuses = [
    'جاري التجهيز',
    'قيد التنفيذ',
    'جاهز للتسليم',
    'تم التسليم',
  ];

  // فئات المصروفات
  // "workshop_debt" مش بتتختار يدوي من شاشة المصروفات - بتتسجل أوتوماتيك
  // بس من شاشة "ديون الورشة" وقت سداد أي دفعة لمورد/صنايعي
  static const Map<String, String> expenseCategories = {
    'materials': 'خامات',
    'rent': 'إيجار وتشغيل',
    'wages': 'أجور الصنايعية',
    'workshop_debt': 'سداد مديونية ورشة',
    'other': 'أخرى',
  };

  // مصدر خروج/دخول الأموال في الخزينة (نقدي/إنستاباي) - نفس القائمة
  // المستخدمة لدفعات العملاء ومصدر خروج المصروفات
  static const Map<String, String> paymentMethods = {
    'cash': 'نقدي',
    'instapay': 'إنستاباي',
  };

  // نوع مرتب العامل
  static const Map<String, String> salaryTypes = {
    'monthly': 'شهري',
    'weekly': 'أسبوعي',
    'daily': 'يومي',
  };

  static const List<String> weekdayNames = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  // فئات فرعية للخامات
  static const List<String> materialSubTypes = [
    'خشب',
    'قماش',
    'إسفنج',
    'دهانات',
    'إكسسوارات',
  ];

  // أنواع الصنايعية
  static const List<String> workerRoles = [
    'نجار',
    'منجد',
    'إستورجي',
    'أخرى',
  ];

  // نوع الدفعة
  static const String paymentDeposit = 'deposit';
  static const String paymentInstallment = 'installment';
  /// دفعة سالبة بترجع فلوس اتردّت للعميل - بتتسجل تلقائيًا لما يتسدد جزء
  /// من مديونية ورشة ناتجة عن دفع أكتر من الاتفاق النهائي على طلب
  static const String paymentRefund = 'refund';
}
