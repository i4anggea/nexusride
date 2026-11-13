import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Usar rutas de paquete en lugar de relativas — evita confusión de niveles
import 'package:nexusride/shared/router/app_router.dart';
import 'package:nexusride/shared/theme/app_theme.dart';
import 'package:nexusride/features/device/presentation/providers/ble_bridge_provider.dart';
import 'package:nexusride/core/services/notification_service.dart';

class NexusRideApp extends ConsumerStatefulWidget {
  const NexusRideApp({super.key});

  @override
  ConsumerState<NexusRideApp> createState() => _NexusRideAppState();
}

class _NexusRideAppState extends ConsumerState<NexusRideApp> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(notificationServiceProvider).init());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bleBridgeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'NexusRide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
