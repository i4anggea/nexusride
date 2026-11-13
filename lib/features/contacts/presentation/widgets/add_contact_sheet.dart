import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/emergency_contact.dart';
import '../providers/contacts_provider.dart';
import 'package:nexusride/core/services/haptic_service.dart';

class AddContactSheet extends ConsumerStatefulWidget {
  final EmergencyContact? existing;
  const AddContactSheet({super.key, this.existing});

  @override
  ConsumerState<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _relationship = 'otro';
  bool _notifySms = true;
  bool _notifyPush = true;

  final _relationships = ['mamá', 'papá', 'pareja', 'amigo', 'otro'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _phoneCtrl.text = widget.existing!.phone;
      _relationship = widget.existing!.relationship;
      _notifySms = widget.existing!.notifySms;
      _notifyPush = widget.existing!.notifyPush;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Editar contacto' : 'Nuevo contacto de emergencia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Nombre
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                if (v.trim().length < 2) {
                  return 'Mínimo 2 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Teléfono
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El teléfono es requerido';
                }
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10) {
                  return 'Ingresa un número válido de 10 dígitos';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Relación
            Text('Relación',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _relationships.map((r) {
                final selected = _relationship == r;
                return FilterChip(
                  label: Text(r),
                  selected: selected,
                  onSelected: (_) => setState(() => _relationship = r),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Notificaciones
            SwitchListTile(
              title: const Text('Notificar por SMS'),
              value: _notifySms,
              onChanged: (v) => setState(() => _notifySms = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Notificar por Push'),
              value: _notifyPush,
              onChanged: (v) => setState(() => _notifyPush = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Botón guardar
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? 'Guardar cambios' : 'Guardar contacto'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      await HapticService.error(); // vibración de error
      return;
    }

    final contact = EmergencyContact(
      id: widget.existing?.id ?? '',
      userId: '',
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      relationship: _relationship,
      notifySms: _notifySms,
      notifyPush: _notifyPush,
    );

    if (widget.existing != null) {
      await ref.read(contactsProvider.notifier).updateContact(contact);
    } else {
      await ref.read(contactsProvider.notifier).addContact(contact);
    }

    await HapticService.success(); // vibración de éxito
    if (mounted) Navigator.of(context).pop();
  }
}
