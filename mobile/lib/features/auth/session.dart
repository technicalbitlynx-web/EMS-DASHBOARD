import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/user.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

@immutable
class SessionState {
  const SessionState({required this.status, this.user});

  final SessionStatus status;
  final User? user;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  SessionState copyWith({SessionStatus? status, User? user}) =>
      SessionState(status: status ?? this.status, user: user ?? this.user);

  static const unknown = SessionState(status: SessionStatus.unknown);
  static const loggedOut = SessionState(status: SessionStatus.unauthenticated);
}

/// Owns the authentication lifecycle: bootstrap from stored token, login,
/// logout, and forced logout on token expiry (triggered by the API interceptor).
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(_bootstrap);
    return SessionState.unknown;
  }

  Future<void> _bootstrap() async {
    final tokenStore = ref.read(tokenStoreProvider);
    final token = await tokenStore.readToken();
    if (token == null || token.isEmpty) {
      state = SessionState.loggedOut;
      return;
    }
    // Optimistically restore the cached user, then verify against the server.
    final cached = await tokenStore.readUser();
    if (cached != null) {
      state = SessionState(
        status: SessionStatus.authenticated,
        user: User.fromJson(cached),
      );
    }
    try {
      final user = await ref.read(authRepositoryProvider).me();
      await tokenStore.writeUser(user.toJson());
      state = SessionState(status: SessionStatus.authenticated, user: user);
    } catch (_) {
      // /me failed (expired/invalid) — interceptor clears on 401; ensure logout.
      await tokenStore.clear();
      state = SessionState.loggedOut;
    }
  }

  Future<void> login(String identifier, String password) async {
    final result =
        await ref.read(authRepositoryProvider).login(identifier, password);
    final tokenStore = ref.read(tokenStoreProvider);
    await tokenStore.writeToken(result.token);
    await tokenStore.writeUser(result.user.toJson());
    state = SessionState(
      status: SessionStatus.authenticated,
      user: result.user,
    );
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = SessionState.loggedOut;
  }

  /// Called by the auth interceptor when a 401 invalidates an existing session.
  void onTokenExpired() {
    state = SessionState.loggedOut;
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
