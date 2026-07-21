import 'package:flutter/material.dart';
import '../../core/auth_state.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthState.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // ملحوظة: مفيش تنقّل يدوي هنا عن قصد. الراوتر (app_router.dart) بيسمع
      // لـ AuthState.isLoggedIn (refreshListenable) وبيحوّل لـ/dashboard
      // تلقائيًا لحظة ما login() تخلّص isLoggedIn.value = true. لو نديه
      // context.go('/dashboard') يدوي هنا كمان، بيحصل سباق: لو الراوتر سبق
      // وحوّل الصفحة (وشال LoginScreen من الشجرة) قبل ما السطر ده ينفّذ،
      // بنكون بنستخدم context بتاع widget اتشال بالفعل - وده اللي بيسبب
      // إغلاق التطبيق فجأة أول مرة بعد التثبيت (أول تشغيل فيه ضغط زيادة على
      // الـ event loop بسبب تهيئة Firebase/Hive/الإشعارات كلها لأول مرة،
      // فبيبقى احتمال إن الراوتر يسبق وينفّذ التحويل قبل السطر اليدوي أعلى بكتير).
      setState(() => _isLoading = false);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'اليوزر أو الباسورد غلط';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF141414);
    const cardColor = Color(0xFF1F1F1F);
    const fieldColor = Color(0xFF262626);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.35), width: 1.5),
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Tahoun Royal Home',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text('سجّل الدخول لإدارة الورشة', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 32),
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(color: Color(0xFFFF8A80))),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'اليوزر',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.amber),
                            filled: true,
                            fillColor: fieldColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب اليوزر' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'الباسورد',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.amber),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey.shade400,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: fieldColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'اكتب الباسورد' : null,
                          onFieldSubmitted: (_) => _signIn(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('تسجيل الدخول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
