import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models.dart';

/// F10 — table reservations. Customer creates a request; the restaurant
/// confirms or declines it.
class ReservationService {
  final ApiClient _api = ApiClient();

  Future<Reservation> createReservation({
    required String restaurantId,
    required int partySize,
    required DateTime dateTime,
    String? note,
  }) async {
    final data = await _api.post(
      ApiConfig.restaurantReservations(restaurantId),
      body: {
        'partySize': partySize,
        'dateTime': dateTime.toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return Reservation.fromApiJson(data as Map<String, dynamic>);
  }

  Future<List<Reservation>> myReservations() async {
    final data = await _api.get(ApiConfig.myReservations);
    return (data as List<dynamic>)
        .map((e) => Reservation.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reservation>> restaurantReservations(
    String restaurantId,
  ) async {
    // Backend resolves the restaurant from the caller's own account —
    // owner or non-guest staff. The id arg is kept for call-site clarity.
    final data = await _api.get(ApiConfig.restaurantReservationsManage);
    return (data as List<dynamic>)
        .map((e) => Reservation.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Reservation> setStatus(
    String reservationId,
    String status, {
    String? tableNumber,
  }) async {
    final data = await _api.patch(
      ApiConfig.reservationStatus(reservationId),
      body: {
        'status': status,
        if (tableNumber != null && tableNumber.isNotEmpty)
          'tableNumber': tableNumber,
      },
    );
    return Reservation.fromApiJson(data as Map<String, dynamic>);
  }

  Future<Reservation> cancel(String reservationId) async {
    final data = await _api.patch(ApiConfig.cancelReservation(reservationId));
    return Reservation.fromApiJson(data as Map<String, dynamic>);
  }
}
