import 'package:nexusride/shared/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexusride/features/contacts/domain/models/emergency_contact.dart';
import 'package:nexusride/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:nexusride/features/contacts/presentation/widgets/contact_card.dart';
import 'package:nexusride/features/contacts/presentation/widgets/add_contact_sheet.dart';
import 'package:nexusride/core/services/haptic_service.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contactos de emergencia'),
            Text('Se notificarán si hay un accidente',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryWidget(
          message: 'No pudimos cargar tus contactos. Verifica tu conexión.',
          onRetry: () => ref.invalidate(contactsProvider),
        ),
        data: (contacts) => contacts.isEmpty
            ? _EmptyState(onAdd: () => _showAddSheet(context, ref))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${contacts.length} contacto${contacts.length == 1 ? '' : 's'} activo${contacts.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...contacts.map((c) => ContactCard(
                        contact: c,
                        onEdit: () => _showAddSheet(context, ref, existing: c),
                        onDelete: () => _confirmDelete(context, ref, c),
                      )),
                  const SizedBox(height: 12),
                  _InfoBanner(),
                  const SizedBox(height: 80), // espacio para el FAB
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Agregar contacto'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref,
      {EmergencyContact? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddContactSheet(existing: existing),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content:
            Text('¿Eliminar a ${contact.name} de tus contactos de emergencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              HapticService.error();
              ref.read(contactsProvider.notifier).deleteContact(contact.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_add_outlined,
              size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Sin contactos aún',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Agrega al menos un contacto para que reciban alertas si tienes un accidente.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Agregar contacto'),
          ),
        ]),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSecondaryContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Los contactos recibirán tu ubicación exacta y un link de Google Maps.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
          ),
        ),
      ]),
    );
  }
}
