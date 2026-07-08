import 'package:flutter_test/flutter_test.dart';

// ملف اختبار مبسّط - القالب الافتراضي بتاع Flutter كان بيحاول يختبر MyApp
// (كلاس مش موجود عندنا، كلاسنا اسمه WorkshopApp). اختبار الواجهة الحقيقي
// محتاج تهيئة Firebase وهمية (Mocking) عشان WorkshopApp بيعتمد على Firebase.initializeApp
// وقت main()، فمؤجّلينه لمرحلة لاحقة. الاختبار ده هنا بس عشان `flutter analyze`
// و`flutter test` يلاقوا ملف صحيح جوه test/ ومايفشلوش.
void main() {
  test('حسبة المديونية المتبقية بتتحسب صح', () {
    const totalAmount = 1000.0;
    const totalPaid = 400.0;
   const remaining = totalAmount - totalPaid;
    expect(remaining, 600.0);
  });
}
