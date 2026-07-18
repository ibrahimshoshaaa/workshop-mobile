// lib/services/cloudinary_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/cloudinary_config.dart';

/// خدمة رفع الصور لـ Cloudinary (بديل مجاني عن Firebase Storage المدفوع) -
/// نفس الخدمة المستخدمة في تطبيق الديسكتوب بالظبط.
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  Uri get _uploadUrl => Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload');

  /// يرفع صورة واحدة (كـ bytes) ويرجع رابط الصورة النهائي بعد الرفع
  Future<String> uploadImageBytes(List<int> bytes, {String? folder}) async {
    final request = http.MultipartRequest('POST', _uploadUrl)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: '${DateTime.now().millisecondsSinceEpoch}.jpg'));

    if (folder != null) {
      request.fields['folder'] = folder;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('فشل رفع الصورة (كود ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url']?.toString();
    if (url == null) {
      throw Exception('لم يتم استلام رابط الصورة من Cloudinary');
    }
    return url;
  }

  /// يرفع أكتر من صورة مرة واحدة، ويرجع قائمة الروابط بنفس الترتيب
  Future<List<String>> uploadMultiple(List<List<int>> imagesBytes, {String? folder}) async {
    final urls = <String>[];
    for (final bytes in imagesBytes) {
      urls.add(await uploadImageBytes(bytes, folder: folder));
    }
    return urls;
  }
}
