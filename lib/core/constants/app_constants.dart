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
  static const Map<String, String> expenseCategories = {
    'materials': 'خامات',
    'rent': 'إيجار وتشغيل',
    'wages': 'أجور الصنايعية',
    'other': 'أخرى',
  };

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
}
