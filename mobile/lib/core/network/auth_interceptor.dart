import 'package:dio/dio.dart';

import '../storage/token_store.dart';

/// Injects the JWT Bearer token on every request and notifies a callback when
/// the server returns 401 on an authenticated request (token expired) so the
/// app can clear the session and route to login — mirroring public/app-api.js.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStore, this._onUnauthorized);

  final TokenStore _tokenStore;
  final void Function() _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStore.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final hadToken = (await _tokenStore.readToken())?.isNotEmpty ?? false;
      // Only force-logout when we *had* a token (expired); a 401 on the login
      // request itself just means bad credentials and should surface normally.
      final path = err.requestOptions.path;
      final isAuthAttempt =
          path.contains('/auth/login') || path.contains('/auth/setup');
      if (hadToken && !isAuthAttempt) {
        await _tokenStore.clear();
        _onUnauthorized();
      }
    }
    handler.next(err);
  }
}
