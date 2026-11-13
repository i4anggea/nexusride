import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

class NotificationService {
  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  Future<void>? _initialization;
  String? _token;

  Future<void> init() async {
    if (_initialization != null) return _initialization!;
    _initialization = _initialize();
    return _initialization!;
  }

  Future<void> _initialize() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _token = await _messaging.getToken();
      if (_token != null) await _saveToken(_token!);
      _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
        _token = token;
        unawaited(_saveToken(token));
      });
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) {
          final token = _token;
          if (token != null) unawaited(_saveToken(token));
        },
      );
    } catch (error) {
      debugPrint('No se pudieron inicializar las notificaciones: $error');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token}).eq('id', user.id);
    } catch (_) {}
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _authSubscription?.cancel();
  }
}
