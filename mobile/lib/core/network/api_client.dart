import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Thin wrapper around Dio configured for the EMS backend. All repositories go
/// through this so the base URL, auth header, timeouts and error mapping are
/// applied uniformly.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore tokenStore,
    required void Function() onUnauthorized,
  }) : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 12),
          headers: {'Content-Type': 'application/json'},
          // We map non-2xx ourselves so 401/403 reach the interceptor + caller.
          validateStatus: (s) => s != null && s < 500,
        )) {
    dio.interceptors.add(AuthInterceptor(tokenStore, onUnauthorized));
  }

  final Dio dio;

  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await dio.get(path, queryParameters: query);
      return _unwrap(res);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<dynamic> postJson(String path, {Object? body}) async {
    try {
      final res = await dio.post(path, data: body);
      return _unwrap(res);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<dynamic> putJson(String path, {Object? body}) async {
    try {
      final res = await dio.put(path, data: body);
      return _unwrap(res);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      final res = await dio.delete(path);
      _unwrap(res);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Fetches a file (e.g. CSV export) as raw bytes, applying the auth header.
  Future<List<int>> getBytes(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      if ((res.statusCode ?? 500) >= 400) {
        throw ApiException('Download failed', statusCode: res.statusCode);
      }
      return res.data ?? const [];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  dynamic _unwrap(Response res) {
    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) return res.data;
    final data = res.data;
    final msg = (data is Map && data['error'] is String)
        ? data['error'] as String
        : 'Request failed (HTTP $status)';
    throw ApiException(msg, statusCode: status);
  }
}
