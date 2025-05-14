import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'dgu4lwrwn';
  static const String _uploadPreset = 'profile-photos';


  static String get cloudName => _cloudName;

  static Future<Map<String, dynamic>?> uploadImage(File imageFile) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = json.decode(res.body);
        print(data);
        return {
          'url': data['secure_url'],
          'publicId': data['public_id'],
        };
      } else {
        print('Cloudinary upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }
}
