import '../api/api_client.dart';

class PlaceSuggestion {
  final String label;
  final double lat;
  final double lng;
  final String city;

  const PlaceSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
    required this.city,
  });
}

/// FAST assistant (Gemini-backed) + location autocomplete — both served
/// by /api/assistant on the backend so app and website share them.
class AssistantService {
  AssistantService._();
  static final AssistantService instance = AssistantService._();

  final _api = ApiClient();
  final List<Map<String, String>> _history = [];

  bool pro = false;

  Future<String> chat(String message) async {
    final data = await _api.post(
      '/assistant/chat',
      body: {
        'message': message,
        'audience': pro ? 'pro' : 'client',
        'history': _history
            .map((m) => {'role': m['role'], 'text': m['text']})
            .toList(),
      },
    );
    final reply = (data as Map<String, dynamic>)['reply'] as String? ?? '';
    _history.add({'role': 'user', 'text': message});
    _history.add({'role': 'model', 'text': reply});
    if (_history.length > 12) _history.removeRange(0, _history.length - 12);
    return reply;
  }

  void clearHistory() => _history.clear();

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.trim().length < 3) return const [];
    final data = await _api.get(
      '/assistant/places?q=${Uri.encodeComponent(query)}',
    );
    final list =
        (data as Map<String, dynamic>)['suggestions'] as List<dynamic>? ??
        const [];
    return list
        .map(
          (e) => PlaceSuggestion(
            label: e['label'] as String? ?? '',
            lat: (e['lat'] as num?)?.toDouble() ?? 0,
            lng: (e['lng'] as num?)?.toDouble() ?? 0,
            city: e['city'] as String? ?? '',
          ),
        )
        .toList();
  }
}
