import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nexusride/features/auth/presentation/providers/auth_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    final name = meta?['full_name'] as String? ?? 'Usuario';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        children: [
          // ── Header ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    _initials(name),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Sección cuenta ────────────────────────────
          _SectionHeader(title: 'Cuenta'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Editar perfil',
            onTap: () =>
                _showEditProfile(context, ref, name, user?.email ?? ''),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            onTap: () => _showNotificationsSheet(context),
          ),

          const Divider(height: 1),

          // ── Sección app ───────────────────────────────
          _SectionHeader(title: 'Aplicación'),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Privacidad',
            onTap: () => _showPrivacySheet(context),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Ayuda',
            onTap: () => _showHelpSheet(context),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Versión de la app',
            trailing: Text(
              '1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onTap: () {},
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── Cerrar sesión ─────────────────────────────
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Editar perfil ──────────────────────────────────────
  void _showEditProfile(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String email,
  ) {
    final nameCtrl = TextEditingController(text: currentName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandle(),
            const SizedBox(height: 16),
            Text(
              'Editar perfil',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
                helperText: 'El correo no se puede cambiar',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(data: {'full_name': nameCtrl.text.trim()}),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Perfil actualizado')),
                  );
                }
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notificaciones ─────────────────────────────────────
  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NotificationsSheet(),
    );
  }

  // ── Privacidad ─────────────────────────────────────────
  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PrivacySheet(),
    );
  }

  // ── Ayuda ──────────────────────────────────────────────
  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HelpSheet(),
    );
  }

  // ── Confirmar cierre de sesión ─────────────────────────
  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst('Bad state: ', ''),
                    ),
                  ),
                );
              }
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) => name
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();
}

// ── Widgets auxiliares ─────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Sheet de Notificaciones ────────────────────────────────
class _NotificationsSheet extends StatefulWidget {
  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _pushEmergencia = true;
  bool _pushUbicacion = false;
  bool _sonido = true;
  bool _vibracion = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHandle(),
          const SizedBox(height: 16),
          Text(
            'Notificaciones',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Alertas de emergencia'),
            subtitle: const Text('Cuando se detecta un accidente'),
            value: _pushEmergencia,
            onChanged: (v) => setState(() => _pushEmergencia = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Compartir ubicación'),
            subtitle: const Text('Notificar cuando compartes tu ruta'),
            value: _pushUbicacion,
            onChanged: (v) => setState(() => _pushUbicacion = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Sonido'),
            value: _sonido,
            onChanged: (v) => setState(() => _sonido = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Vibración'),
            value: _vibracion,
            onChanged: (v) => setState(() => _vibracion = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ── Sheet de Privacidad ────────────────────────────────────
class _PrivacySheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHandle(),
          const SizedBox(height: 16),
          Text('Privacidad', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _PrivacyItem(
            title: 'Datos de ubicación',
            description:
                'Tu ubicación solo se comparte con tus contactos de emergencia cuando se detecta un accidente o cuando tú lo decides.',
          ),
          const SizedBox(height: 12),
          _PrivacyItem(
            title: 'Almacenamiento de rutas',
            description:
                'Guardamos tu historial de rutas por 30 días para mostrarte estadísticas. Puedes eliminarlos en cualquier momento.',
          ),
          const SizedBox(height: 12),
          _PrivacyItem(
            title: 'Datos personales',
            description:
                'Tu nombre y correo son usados únicamente para identificarte en la app. No los compartimos con terceros.',
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  final String title;
  final String description;
  const _PrivacyItem({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet de Ayuda ─────────────────────────────────────────
class _HelpSheet extends StatelessWidget {
  final _faqs = const [
    (
      '¿Cómo conecto el módulo al casco?',
      'Ve a la sección "Módulo" en la barra inferior, enciende el módulo presionando el botón 3 segundos hasta que el LED azul parpadee, y toca "Buscar módulo".',
    ),
    (
      '¿Cómo agrego contactos de emergencia?',
      'Ve a la sección "Contactos", toca el botón "Agregar contacto" e ingresa el nombre y teléfono. Puedes agregar hasta 5 contactos.',
    ),
    (
      '¿Qué pasa cuando se detecta un accidente?',
      'Aparecerá una pantalla con un contador de 30 segundos. Si no respondes, se enviará un SMS con tu ubicación exacta a todos tus contactos.',
    ),
    (
      '¿Funciona sin internet?',
      'Sí. Las ubicaciones se guardan localmente y se sincronizan cuando vuelve la conexión. El módulo BLE funciona independientemente del internet.',
    ),
    (
      '¿Cómo cancelo una alerta falsa?',
      'Cuando aparezca el contador, toca el botón verde "Estoy bien, cancelar" antes de que llegue a cero.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandle(),
            const SizedBox(height: 16),
            Text(
              'Ayuda frecuente',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: _faqs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _FaqTile(question: _faqs[i].$1, answer: _faqs[i].$2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        question,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            answer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
