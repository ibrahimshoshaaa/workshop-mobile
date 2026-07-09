/// نموذج حساب مستخدم إضافي (عامل) - يُخزَّن في Realtime Database تحت app_users
/// ويتزامن أونلاين بين كل الأجهزة، عكس الحساب الرئيسي (admin) اللي لسه ثابت
/// في app_credentials.dart كخط أمان دائم متقدرش تتحذف بيه من التطبيق
class UserAccountModel {
  final String id;
  final String username;
  final String password;
  final DateTime createdAt;

  UserAccountModel({
    required this.id,
    required this.username,
    required this.password,
    required this.createdAt,
  });

  factory UserAccountModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return UserAccountModel(
      id: id,
      username: map['username']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
