import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nexusride/core/app/app.dart';
import 'package:nexusride/core/constants/app_constants.dart';
import 'package:nexusride/features/location/domain/models/pending_location.dart';
import 'package:nexusride/hive_registrar.g.dart';
import 'package:nexusride/firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:io';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  // Preservar splash mientras inicializamos
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    AppConstants.validate(isAndroid: Platform.isAndroid);
  } on StateError catch (error) {
    FlutterNativeSplash.remove();
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Configuración incompleta\n\n${error.message}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabasePublishableKey,
  );

  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<PendingLocation>('pending_locations');

  // Quitar splash — la app ya está lista
  FlutterNativeSplash.remove();

  runApp(const ProviderScope(child: NexusRideApp()));
}
