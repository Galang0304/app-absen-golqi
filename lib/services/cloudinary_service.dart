import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Upload gambar ke Cloudinary lewat unsigned upload preset.
///
/// SETUP (satu kali): buka Cloudinary Console > Settings > Upload > Upload presets
/// > Add upload preset > Signing Mode: Unsigned > beri nama sesuai [uploadPreset].
class CloudinaryService {
  static const String cloudName = 'xuqxnb0o';
  static const String uploadPreset = 'golqi_absensi';

  /// Mengembalikan secure_url gambar yang berhasil di-upload.
  static Future<String> uploadImage(File file, {String folder = 'golqi-absensi/absensi'}) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Upload gagal: $body');
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }
}
