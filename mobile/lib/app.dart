import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/session.dart';
import 'features/notifications/notification_service.dart';

class EmsApp extends ConsumerStatefulWidget {
  const EmsApp({super.key});

  @override
  ConsumerState<EmsApp> createState() => _EmsAppState();
}

class _EmsAppState extends ConsumerState<EmsApp> {
  @override
  void initState() {
    super.initState();
    // Initialise push (no-op unless ENABLE_PUSH) and react to auth changes.
    ref.read(notificationServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    // Register/unregister the FCM token as the session flips.
    ref.listen(sessionProvider, (prev, next) {
      final svc = ref.read(notificationServiceProvider);
      final was = prev?.isAuthenticated ?? false;
      if (next.isAuthenticated && !was) {
        svc.registerAfterLogin();
      } else if (!next.isAuthenticated && was) {
        svc.unregister();
      }
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'EMS Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
