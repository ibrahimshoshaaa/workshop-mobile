import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _privacyModeKey = 'privacy_mode_enabled';

/// وضع الخصوصية - لما يكون مفعّل، كل المبالغ المالية في التطبيق بتتبلور
/// (زي فلتر ضبابي) عشان تقدر تفتح الموبايل قدام حد من غير ما يشوفها.
/// الحالة متخزّنة محليًا (SharedPreferences) فبتفضل زي ما سيبتها حتى لو
/// قفلت التطبيق وفتحته تاني
class PrivacyModeNotifier extends StateNotifier<bool> {
  PrivacyModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_privacyModeKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyModeKey, state);
  }
}

final privacyModeProvider = StateNotifierProvider<PrivacyModeNotifier, bool>(
  (ref) => PrivacyModeNotifier(),
);
