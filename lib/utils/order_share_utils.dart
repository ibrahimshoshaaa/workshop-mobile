import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order_model.dart';
import '../models/worker_model.dart';
import '../core/whatsapp.dart';

/// أدوات مشاركة الطلبات (نص + صور) - مستخدمة من صفحة تفاصيل الطلب (مشاركة
/// طلب واحد) ومن الداشبورد (مشاركة كل التسليمات القريبة مع بعض)

/// بيبني نص تفاصيل طلب واحد - الصنف والمواصفات وتاريخ التسليم والحالة،
/// من غير أي تفاصيل مالية (الإجمالي/المدفوع/المتبقي/الخصم) عشان دي بيانات
/// خاصة بالورشة ومش المفروض تتشارك مع حد برا
String buildOrderShareText(OrderModel order) {
  final buffer = StringBuffer()
    ..writeln('طلب: ${order.itemType}')
    ..writeln('العميل: ${order.customerName}');
  if (order.details.trim().isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('المواصفات:')
      ..writeln(order.details.trim());
  }
  buffer
    ..writeln()
    ..writeln('تاريخ التسليم: ${DateFormat('d/M/yyyy').format(order.deliveryDate)}')
    ..writeln('الحالة: ${order.status}');
  return buffer.toString();
}

/// بينزّل صور طلب واحد من Cloudinary لملفات مؤقتة على الجهاز عشان تتبعت مع
/// نص المشاركة في نفس الرسالة (بعكس الديسكتوب، تطبيقات المشاركة على
/// الموبايل بتقدر ترفق صور وملفات حقيقية مباشرة)
Future<List<XFile>> downloadOrderImagesAsFiles(OrderModel order) async {
  if (order.images.isEmpty) return [];
  final files = <XFile>[];
  try {
    final tempDir = await getTemporaryDirectory();
    for (var i = 0; i < order.images.length; i++) {
      try {
        final response = await http.get(Uri.parse(order.images[i]));
        if (response.statusCode == 200) {
          final ext = order.images[i].split('.').last.split('?').first;
          final file = File('${tempDir.path}/order_${order.id}_image_$i.$ext');
          await file.writeAsBytes(response.bodyBytes);
          files.add(XFile(file.path));
        }
      } catch (_) {
        // نتجاهل أي صورة فشل تنزيلها ونكمل الباقي
      }
    }
  } catch (_) {}
  return files;
}

/// مشاركة طلب واحد (نص + صوره لو موجودة)
Future<void> shareOrder(BuildContext context, OrderModel order) async {
  final text = buildOrderShareText(order);
  final imageFiles = await downloadOrderImagesAsFiles(order);
  if (imageFiles.isNotEmpty) {
    await Share.shareXFiles(imageFiles, text: text);
  } else {
    await Share.share(text);
  }
}

/// مشاركة مواصفات طلب لصنايعي معيّن مباشرة على واتساب (نفس ميزة نسخة
/// الديسكتوب) - بيفتح شات واتساب برقم الصنايعي مباشرة ومعاه نص المواصفات
/// (من غير أي مبالغ مالية، لأن دي بيانات خاصة بصاحب الطلب مش شغلانة
/// الصنايعي). لو الطلب فيه صور، بيفتح بعدها قائمة مشاركة النظام العادية
/// عشان المستخدم يختار نفس شات واتساب ويرفق الصور (بعكس الديسكتوب، هنا
/// نقدر نرفق الصور مباشرة من غير فولدر وسيط)
Future<void> shareOrderWithWorker(BuildContext context, OrderModel order, WorkerModel worker) async {
  final buffer = StringBuffer()
    ..writeln('طلب: ${order.itemType}')
    ..writeln('العميل: ${order.customerName}');
  if (order.details.trim().isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('المواصفات:')
      ..writeln(order.details.trim());
  }
  buffer
    ..writeln()
    ..writeln('تاريخ التسليم: ${DateFormat('d/M/yyyy').format(order.deliveryDate)}');

  final ok = await shareTextOnWhatsApp(buffer.toString(), phone: worker.phone);
  if (!ok) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مقدرش أفتح واتساب - تأكد إنه متثبت على الجهاز')));
    }
    return;
  }

  final imageFiles = await downloadOrderImagesAsFiles(order);
  if (imageFiles.isNotEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هتفتحلك قائمة مشاركة تانية - اختار نفس شات واتساب اللي فتح عشان ترفق صور الطلب')),
      );
    }
    await Share.shareXFiles(imageFiles);
  }
}

/// دايالوج اختيار الصنايعي اللي هتتبعتله مواصفات الطلب - نفس فكرة
/// showShareToWorkerDialog في نسخة الديسكتوب
Future<void> showShareOrderWithWorkerDialog(BuildContext context, OrderModel order, List<WorkerModel> workers) async {
  if (workers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف صنايعي أولًا من صفحة العمال')));
    return;
  }
  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('ابعت المواصفات لأي صنايعي؟'),
      content: SizedBox(
        width: 360,
        height: 380,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: workers.length,
          itemBuilder: (context, index) {
            final w = workers[index];
            return ListTile(
              leading: const Icon(Icons.engineering_rounded),
              title: Text(w.name),
              subtitle: Text(w.jobTitle.isNotEmpty ? '${w.jobTitle} - ${w.phone}' : w.phone),
              onTap: () {
                Navigator.pop(dialogContext);
                shareOrderWithWorker(context, order, w);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
      ],
    ),
  );
}

/// مشاركة كذا طلب مع بعض في رسالة واحدة (نص كل الطلبات + كل صورهم مجمّعين)
/// - مستخدمة في مشاركة "الطلبات الحالية" من الداشبورد
Future<void> shareOrders(BuildContext context, List<OrderModel> orders) async {
  if (orders.isEmpty) return;

  final buffer = StringBuffer('📦 التسليمات القادمة خلال أسبوع:\n');
  final allImageFiles = <XFile>[];

  for (final order in orders) {
    buffer
      ..writeln()
      ..writeln('———————————')
      ..write(buildOrderShareText(order));
    allImageFiles.addAll(await downloadOrderImagesAsFiles(order));
  }

  if (allImageFiles.isNotEmpty) {
    await Share.shareXFiles(allImageFiles, text: buffer.toString());
  } else {
    await Share.share(buffer.toString());
  }
}
