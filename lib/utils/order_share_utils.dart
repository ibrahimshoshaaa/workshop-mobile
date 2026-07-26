import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order_model.dart';

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
