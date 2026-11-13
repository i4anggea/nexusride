import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nexusride/features/auth/presentation/providers/auth_provider.dart';
import 'package:nexusride/features/auth/presentation/screens/auth_screen.dart';
import 'package:nexusride/features/location/presentation/screens/home_screen.dart';
import 'package:nexusride/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:nexusride/features/device/presentation/screens/device_screen.dart';
import 'package:nexusride/features/emergency/presentation/screens/emergency_screen.dart';
import 'package:nexusride/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:nexusride/features/profile/presentation/screens/profile_screen.dart';

class AppRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: AppRouter.navigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLogged = session != null;
      final isOnAuth = state.matchedLocation == '/login';

      if (!isLogged && !isOnAuth) return '/login';
      if (isLogged && isOnAuth) return '/home';
      return null;
    },
    routes: [
      // Auth — fuera del shell
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const AuthScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/emergency',
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const EmergencyScreen()),
      ),

      // Shell — pantallas con barra de navegación persistente
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                _fadePage(key: state.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: '/contacts',
            pageBuilder: (context, state) =>
                _fadePage(key: state.pageKey, child: const ContactsScreen()),
          ),
          GoRoute(
            path: '/device',
            pageBuilder: (context, state) =>
                _fadePage(key: state.pageKey, child: const DeviceScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                _fadePage(key: state.pageKey, child: const ProfileScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Ruta no encontrada: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    ),
  );
  ref.listen(authSessionProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

// ── Shell con NavigationBar persistente ───────────────────
class _MainShell extends StatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _selectedIndex = 0;

  static const _routes = ['/home', '/contacts', '/device', '/profile'];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          context.go('/home');
        }
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            context.go(_routes[index]);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              label: 'Contactos',
            ),
            NavigationDestination(
              icon: Icon(Icons.bluetooth_outlined),
              label: 'Modulo',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transición fade ────────────────────────────────────────
CustomTransitionPage<void> _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        ),
    transitionDuration: const Duration(milliseconds: 220),
  );
}
