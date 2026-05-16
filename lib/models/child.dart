class Child {
  final String id;
  final String parentId;
  final String childName;
  final int age;
  final String? phone; // ← tambahkan
  final String? avatarUrl;
  final DateTime createdAt;

  Child({
    required this.id,
    required this.parentId,
    required this.childName,
    required this.age,
    this.phone, // ← tambahkan
    this.avatarUrl,
    required this.createdAt,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] as String,
      parentId: json['parent_id'] as String,
      childName: json['child_name'] as String,
      age: json['age'] as int,
      phone: json['phone'] as String?, // ← tambahkan
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'child_name': childName,
      'age': age,
      'phone': phone, // ← tambahkan
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get firstName => childName.split(' ').first;
  String get greeting => 'Hei, ini HP-nya $childName 👋';
}
