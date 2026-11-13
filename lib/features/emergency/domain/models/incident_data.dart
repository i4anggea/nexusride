class NotifiedContact {
  final String name;
  final String method;
  final String status;
  final String initials;

  const NotifiedContact({
    required this.name,
    required this.method,
    required this.status,
    required this.initials,
  });
}

class IncidentData {
  final String id;
  final double gForce;
  final double latitude;
  final double longitude;
  final String status;
  final List<NotifiedContact> notifiedContacts;

  const IncidentData({
    required this.id,
    required this.gForce,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.notifiedContacts,
  });

  factory IncidentData.fromJson(Map<String, dynamic> json) {
    final notifications =
        (json['incident_notifications'] as List<dynamic>? ?? []).map((n) {
      final contact = n['emergency_contacts'] as Map<String, dynamic>?;
      final name = contact?['name'] as String? ?? 'Contacto';
      final initials = name
          .split(' ')
          .take(2)
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
          .join();
      return NotifiedContact(
        name: name,
        method: n['method'] as String? ?? 'sms',
        status: n['status'] as String? ?? 'pending',
        initials: initials,
      );
    }).toList();

    return IncidentData(
      id: json['id'] as String,
      gForce: (json['g_force'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'] as String? ?? 'detected',
      notifiedContacts: notifications,
    );
  }
}
