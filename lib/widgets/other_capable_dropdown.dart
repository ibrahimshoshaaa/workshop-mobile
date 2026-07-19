import 'package:flutter/material.dart';

/// الاسم/القيمة المتفق عليها لخيار "أخرى" في أي قائمة منسدلة بالتطبيق -
/// نفس القيمة بالظبط المستخدمة في تطبيق الديسكتوب
const String kOtherOptionValue = 'أخرى';

/// قائمة منسدلة عامة بيها خيار "أخرى" ثابت في الآخر - لو المستخدم
/// اختاره، بيظهر تلقائيًا حقل نصي تحت القائمة يقدر يكتب فيه القيمة اللي
/// عايزها، وده اللي بيتخزن فعليًا (مش كلمة "أخرى" نفسها). لو كانت القيمة
/// الحالية مش موجودة أصلاً في قائمة الخيارات الثابتة (لأنها اتكتبت يدوي
/// قبل كده من الديسكتوب مثلاً)، الودجت بيتعامل معاها تلقائيًا كأنها
/// "أخرى" ويحط قيمتها في الحقل النصي. نفس منطق تطبيق الديسكتوب بالظبط.
class OtherCapableDropdown extends StatefulWidget {
  final List<String> options;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const OtherCapableDropdown({
    super.key,
    required this.options,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<OtherCapableDropdown> createState() => _OtherCapableDropdownState();
}

class _OtherCapableDropdownState extends State<OtherCapableDropdown> {
  late bool _isOther = !widget.options.contains(widget.value);
  late final TextEditingController _customController =
      TextEditingController(text: _isOther ? widget.value : '');

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dropdownValue = _isOther ? kOtherOptionValue : widget.value;
    final items = [...widget.options, kOtherOptionValue];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: items.contains(dropdownValue) ? dropdownValue : items.first,
          decoration: InputDecoration(labelText: widget.label),
          items: items.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _isOther = v == kOtherOptionValue);
            if (v == kOtherOptionValue) {
              widget.onChanged(_customController.text.trim());
            } else {
              widget.onChanged(v);
            }
          },
        ),
        if (_isOther)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              controller: _customController,
              decoration: const InputDecoration(labelText: 'اكتب القيمة'),
              onChanged: (v) => widget.onChanged(v.trim()),
            ),
          ),
      ],
    );
  }
}
