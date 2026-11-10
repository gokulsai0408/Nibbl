import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';
import 'data/local/hive_store.dart';
import 'presentation/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Portrait only.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await HiveStore.init();
  final config = await AppConfig.load();
  unawaited(NotificationService.instance.init());
  if (config.hasSocial) {
    try {
      await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseKey);
    } catch (_) {
      // Social screens show an error; the rest of the app keeps working.
    }
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const ForkcastApp(),
    ),
  );
}
