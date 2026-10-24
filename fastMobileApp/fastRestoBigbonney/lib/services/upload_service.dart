import '../api/api_client.dart';
import '../api/api_config.dart';

/// Uploads dish photos & videos to the backend (`POST /api/uploads`)
/// and resolves the returned `/uploads/…` path into an absolute URL.
class UploadService {
  final _api = ApiClient();

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

  Future<String> uploadFile(String filePath) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    final data = await _api.postMultipart(
      ApiConfig.uploads,
      field: 'file',
      filePath: filePath,
      filename: filename,
    );
    return absoluteUrl((data as Map<String, dynamic>)['url'] as String);
  }
}
