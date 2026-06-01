import 'package:dio/dio.dart';

/// A typed error surfaced from the API layer with a user-friendly message.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;

  /// Maps a Dio error onto an [ApiException], extracting the backend's
  /// `{ "error": "..." }` body shape used throughout the EMS API.
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map && data['error'] is String) {
      serverMsg = data['error'] as String;
    } else if (data is String && data.isNotEmpty && data.length < 300) {
      serverMsg = data;
    }

    if (serverMsg != null) return ApiException(serverMsg, statusCode: status);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Connection timed out. Check your network.');
      case DioExceptionType.connectionError:
        return const ApiException(
          'Cannot reach the server. Check the network or server URL.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException('Server certificate could not be verified.');
      default:
        return ApiException(
          status != null ? 'Request failed (HTTP $status)' : 'Request failed',
          statusCode: status,
        );
    }
  }
}
