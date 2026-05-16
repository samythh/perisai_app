class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper — ambil nama depan saja
  String get firstName => fullName.split(' ').first;

  // Helper — sapaan dashboard
  String get dashboardGreeting => 'Hai, $firstName! 👋';
}