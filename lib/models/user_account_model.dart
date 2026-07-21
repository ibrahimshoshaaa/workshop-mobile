/// نموذج حساب مستخدم إضافي (عامل) - يُخزَّن في Realtime Database تحت app_users
/// ويتزامن أونلاين بين كل الأجهزة، عكس الحساب الرئيسي (admin) اللي بقى حساب
/// Firebase Authentication حقيقي متعمول يدويًا من Firebase Console، مش سجل
/// هنا في app_users خالص (عشان كده أي يوزرنيم مش لاقيينه في app_users بيتحسب
/// أدمن تلقائيًا - راجع auth_state.dart).
///
/// نفس عقدة app_users بتاعة تطبيق الديسكتوب بالظبط، بما فيها حقل
/// permissions، عشان الصلاحية اللي تتحدد من أي تطبيق تتطبق في التاني.
class UserAccountModel {
  final String id;
  final String username;
  final String password;
  final DateTime createdAt;
  final Map<String, bool> permissions;

  /// كل الأقسام اللي ممكن تتحدد صلاحية دخول ليها. الرئيسية مستثناة عمدًا
  /// (متاحة للكل دايمًا)، والإعدادات كمان مستثناة (للأدمن بس)
  static const List<MapEntry<String, String>> permissionScreens = [
    MapEntry('customers', 'العملاء'),
    MapEntry('orders', 'الطلبات'),
    MapEntry('debts', 'المديونيات'),
    MapEntry('workers', 'العمال'),
    MapEntry('expenses', 'المصروفات'),
    MapEntry('reports', 'التقارير'),
  ];

  UserAccountModel({
    required this.id,
    required this.username,
    required this.password,
    required this.createdAt,
    this.permissions = const {},
  });

  /// أي قسم مش موجود صراحةً في permissions بيتحسب "مسموح" افتراضيًا -
  /// عشان الحسابات القديمة (اتعملت قبل ميزة الصلاحيات، أو من الديسكتوب
  /// من غير ما يحدد صلاحيات) تفضل شغالة بكامل صلاحياتها زي ما كانت
  bool canAccess(String screenKey) => permissions[screenKey] ?? true;

  factory UserAccountModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final permsRaw = map['permissions'];
    final perms = <String, bool>{};
    if (permsRaw is Map) {
      permsRaw.forEach((k, v) => perms[k.toString()] = v == true);
    }
    return UserAccountModel(
      id: id,
      username: map['username']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      permissions: perms,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'permissions': permissions,
    };
  }
}
