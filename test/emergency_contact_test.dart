import 'package:flutter_test/flutter_test.dart';
import 'package:nexusride/features/contacts/domain/models/emergency_contact.dart';

void main() {
  test('maps a database contact and its notification preferences', () {
    final contact = EmergencyContact.fromJson({
      'id': 'contact-1',
      'user_id': 'user-1',
      'name': 'Ana Pérez',
      'phone': '+525500000000',
      'email': null,
      'relationship': 'familiar',
      'notify_sms': false,
      'notify_push': true,
    });

    expect(contact.name, 'Ana Pérez');
    expect(contact.notifySms, isFalse);
    expect(contact.notifyPush, isTrue);
    expect(contact.toJson()['phone'], '+525500000000');
  });
}
