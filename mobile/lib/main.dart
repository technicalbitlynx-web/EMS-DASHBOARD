import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/prefs_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await PrefsStore.create();

  runApp(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
      ],
      child: const EmsApp(),
    ),
  );
}
