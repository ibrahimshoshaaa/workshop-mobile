import 'package:url_launcher/url_launcher.dart';

/// نفس منطق نسخة الديسكتوب بالظبط (core/whatsapp.dart) - بيجهز رقم هاتف
/// مصري (بأي صيغة: 01012345678 أو +201012345678 أو 00201012345678) للصيغة
/// الدولية من غير + أو أصفار زيادة، لأن روابط واتساب (wa.me) بتحتاجه
/// بالصيغة دي بالظبط. لو الرقم فاضي أو مش منطقي (أقل من 8 أرقام) بيرجع null.
String? normalizeEgyptianPhoneForWhatsApp(String phone) {
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('0020')) digits = digits.substring(2); // 0020xxxxxxxxxx -> 20xxxxxxxxxx
  if (digits.startsWith('20') && digits.length >= 12) return digits;
  if (digits.startsWith('0')) digits = digits.substring(1); // 01012345678 -> 1012345678
  if (digits.length < 8) return null;
  return '20$digits';
}

/// بيفتح واتساب (تطبيق الموبايل لو متثبت، وإلا واتساب ويب على المتصفح)
/// برسالة جاهزة. لو معدّى [phone] وعرفنا نظبطه، بيفتح المحادثة مع الرقم ده
/// مباشرة، وإلا بيفتح واتساب من غير محادثة محددة عشان المستخدم يختار هو
/// المحادثة اللي عايز يبعتلها.
Future<bool> shareTextOnWhatsApp(String text, {String? phone}) async {
  final normalized = phone != null ? normalizeEgyptianPhoneForWhatsApp(phone) : null;
  final encodedText = Uri.encodeComponent(text);
  final url = normalized != null ? 'https://wa.me/$normalized?text=$encodedText' : 'https://wa.me/?text=$encodedText';
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
