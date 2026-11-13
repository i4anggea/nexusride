import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// El cliente de Supabase disponible en toda la app
final supabaseClientProvider = Provider(
  (ref) => Supabase.instance.client,
);

// Sesión actual — null si no hay usuario
final authSessionProvider = StreamProvider<Session?>((ref) {
  return ref
      .watch(supabaseClientProvider)
      .auth
      .onAuthStateChange
      .map((event) => event.session);
});

// Usuario actual como acceso directo
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
});
