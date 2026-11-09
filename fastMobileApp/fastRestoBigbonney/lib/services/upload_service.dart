import 'dart:io';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/api_exceptions.dart';

/// Uploads dish photos & videos. The file goes straight to storage with a
/// one-time URL from `POST /api/uploads/sign` — the API runs on Vercel,
/// which refuses request bodies over ~4.5 MB. When the server has no
/// storage configured (local dev) it falls back to `POST /api/uploads`.
class UploadService {
  final _api = ApiClient();

  static const _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    '3gp': 'video/3gpp',
    'm4v': 'video/x-m4v',
  };

  /// Resolves a backend-relative media path (e.g. `/uploads/x.jpg`)
  /// into an absolute URL on the API origin. Absolute and data URIs
  /// pass through untouched.
  static String absoluteUrl(String url) {
    if (url.isEmpty ||
        url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('data:')) {
      return url;
    }
    final base = ApiConfig.baseUrl;
    final origin = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : base;
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  static String contentTypeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _contentTypes[ext] ?? 'image/jpeg';
  }

  Future<String> uploadFile(String filePath) async {
    final file = File(filePath);
    final contentType = contentTypeFor(filePath);
    final size = await file.length();

    Map<String, dynamic>? signed;
    try {
      signed = await _api.post('${ApiConfig.uploads}/sign', body: {
        'contentType': contentType,
        'size': size,
      }) as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode != 501) rethrow;
    }

    if (signed != null) {
      final resp = await http
          .put(
            Uri.parse(signed['uploadUrl'] as String),
            headers: {'Content-Type': contentType, 'x-upsert': 'false'},
            body: await file.readAsBytes(),
          )
          .timeout(const Duration(minutes: 3));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw ApiException(
          'Envoi du fichier impossible (${resp.statusCode})',
          resp.statusCode,
        );
      }
      return signed['publicUrl'] as String;
    }

    final filename = filePath.split(RegExp(r'[\/]')).last;
    final data = await _api.postMultipart(
      ApiConfig.uploads,
      field: 'file',
      filePath: filePath,
      filename: filename,
      contentType: contentType,
    );
    return absoluteUrl((data as Map<String, dynamic>)['url'] as String);
  }
}
