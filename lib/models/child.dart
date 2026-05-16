class Child {
  final String id;
  final String parentId;
  final String childName;
  final int age;
  final DateTime createdAt;

  Child({
    required this.id,
    required this.parentId,
    required this.childName,
    required this.age,
    required this.createdAt,
  });

  // Dari JSON Supabase ke object Dart
  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id:        json['id'] as String,
      parentId:  json['parent_id'] as String,
      childName: json['child_name'] as String,
      age:       json['age'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Dari object Dart ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id':         id,
      'parent_id':  parentId,
      'child_name': childName,
      'age':        age,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper — sapaan yang asik
  String get greeting => 'Hei, ini HP-nya $childName 👋';
}