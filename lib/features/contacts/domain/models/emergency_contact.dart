class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? email;
  final String relationship;
  final bool notifySms;
  final bool notifyPush;

  const EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.email,
    this.relationship = 'otro',
    this.notifySms = true,
    this.notifyPush = true,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      relationship: json['relationship'] as String? ?? 'otro',
      notifySms: json['notify_sms'] as bool? ?? true,
      notifyPush: json['notify_push'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'relationship': relationship,
        'notify_sms': notifySms,
        'notify_push': notifyPush,
      };
}
