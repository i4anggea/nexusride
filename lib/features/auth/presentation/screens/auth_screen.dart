import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth_text_field.dart';
import 'package:nexusride/features/auth/presentation/providers/auth_notifier.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Escuchar errores
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error.toString();
        String mensaje = 'Ocurrió un error. Intenta de nuevo.';

        if (error.contains('Invalid login credentials')) {
          mensaje = 'Correo o contraseña incorrectos';
        } else if (error.contains('Email not confirmed')) {
          mensaje = 'Confirma tu correo antes de entrar';
        } else if (error.contains('over_email_send_rate_limit')) {
          mensaje = 'Espera unos segundos antes de intentar de nuevo';
        } else if (error.contains('network')) {
          mensaje = 'Sin conexión a internet';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (previous?.isLoading == true &&
          next.hasValue &&
          _tabController.index == 1) {
        final hasSession = Supabase.instance.client.auth.currentSession != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasSession
                  ? 'Tu cuenta se creó correctamente.'
                  : 'Cuenta creada. Revisa tu correo para confirmarla y después inicia sesión.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'NexusRide',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Seguridad inteligente para cada ruta',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Tabs
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Iniciar sesión'),
                  Tab(text: 'Crear cuenta'),
                ],
              ),
              const SizedBox(height: 24),

              // Formulario dinámico según tab
              AnimatedBuilder(
                animation: _tabController,
                builder: (_, _) {
                  final isLogin = _tabController.index == 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isLogin) ...[
                        AuthTextField(
                          label: 'Nombre completo',
                          controller: _nameCtrl,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                      ],
                      AuthTextField(
                        label: 'Correo electrónico',
                        controller: _emailCtrl,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      AuthTextField(
                        label: 'Contraseña',
                        controller: _passwordCtrl,
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      if (isLogin) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _onForgotPassword,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 14),

                      // Botón principal
                      FilledButton(
                        onPressed: authState.isLoading ? null : _onSubmit,
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(isLogin ? 'Entrar' : 'Crear cuenta'),
                      ),

                      if (isLogin) ...[
                        const SizedBox(height: 16),
                        _divider(),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _onGoogleSignIn,
                          icon: const Icon(Icons.g_mobiledata, size: 20),
                          label: const Text('Continuar con Google'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('o', style: Theme.of(context).textTheme.bodySmall),
      ),
      const Expanded(child: Divider()),
    ],
  );

  void _onSubmit() {
    final isLogin = _tabController.index == 0;
    if (isLogin) {
      ref
          .read(authNotifierProvider.notifier)
          .signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    } else {
      ref
          .read(authNotifierProvider.notifier)
          .signUp(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text.trim(),
          );
    }
  }

  void _onForgotPassword() {
    ref
        .read(authNotifierProvider.notifier)
        .resetPassword(_emailCtrl.text.trim());
  }

  void _onGoogleSignIn() {
    ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }
}
