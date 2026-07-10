import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/privacy_provider.dart';

/// يغطّي أي عنصر (غالبًا مبلغ مالي) بتمويه (Blur) لو وضع الخصوصية مفعّل.
/// استخدمه بلف أي Text فيه رقم مالي: PrivacyBlur(child: Text('500 ج.م'))
class PrivacyBlur extends ConsumerWidget {
  final Widget child;
  const PrivacyBlur({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privacyModeProvider);
    if (!isPrivate) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: child,
    );
  }
}
