import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/emergency_contact.dart';

final contactsProvider =
    AsyncNotifierProvider<ContactsNotifier, List<EmergencyContact>>(
  ContactsNotifier.new,
);

class ContactsNotifier extends AsyncNotifier<List<EmergencyContact>> {
  @override
  Future<List<EmergencyContact>> build() async {
    return _fetchContacts();
  }

  Future<List<EmergencyContact>> _fetchContacts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final data = await Supabase.instance.client
        .from('emergency_contacts')
        .select()
        .eq('user_id', user.id)
        .order('created_at');

    return (data as List)
        .map((j) => EmergencyContact.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> addContact(EmergencyContact contact) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client
          .from('emergency_contacts')
          .insert({...contact.toJson(), 'user_id': user.id});
      return _fetchContacts();
    });
  }

  Future<void> deleteContact(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client
          .from('emergency_contacts')
          .delete()
          .eq('id', id);
      return _fetchContacts();
    });
  }

  Future<void> updateContact(EmergencyContact contact) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client
          .from('emergency_contacts')
          .update(contact.toJson())
          .eq('id', contact.id);
      return _fetchContacts();
    });
  }
}
