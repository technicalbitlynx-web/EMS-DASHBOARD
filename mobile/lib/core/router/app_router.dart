import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/session.dart';
import '../../features/shell/home_shell.dart';
import '../../features/shell/splash_screen.dart';

/// Bridges a Riverpod provider to a Listenable for go_router's refresh.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (session.status == SessionStatus.unknown) {
        return loc == '/' ? null : '/';
      }
      final loggedIn = session.isAuthenticated;
      final onLogin = loc == '/login';
      final onSplash = loc == '/';

      if (!loggedIn) return onLogin ? null : '/login';
      if (onLogin || onSplash) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/home',
        builder: (_, state) => HomeShell(
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: '/alerts/:id',
        builder: (_, state) => HomeShell(
          initialTab: 'alerts',
          focusAlertId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
    ],
  );
});
