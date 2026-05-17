/// Status koneksi HP anak
enum ConnectionStatus {
  /// Terhubung — service aktif dan mengirim heartbeat
  online,

  /// Terputus karena internet/koneksi mati
  offlineInternet,

  /// Terputus karena anak sengaja matikan service
  offlineManual,
}

class Child {
  final String id;
  final String parentId;
  final String childName;
  final int age;
  final String? phone;
  final String? avatarUrl;
  final DateTime createdAt;
  final ConnectionStatus connectionStatus;
  final DateTime? lastSeen;

  Child({
    required this.id,
    required this.parentId,
    required this.childName,
    required this.age,
    this.phone,
    this.avatarUrl,
    required this.createdAt,
    this.connectionStatus = ConnectionStatus.online,
    this.lastSeen,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] as String,
      parentId: json['parent_id'] as String,
      childName: json['child_name'] as String,
      age: json['age'] as int,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      connectionStatus: _parseStatus(json['connection_status'] as String?),
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'child_name': childName,
      'age': age,
      'phone': phone,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'connection_status': connectionStatus.name,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  /// Parse string dari DB ke enum, default online kalau null
  static ConnectionStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'offline_internet':
        return ConnectionStatus.offlineInternet;
      case 'offline_manual':
        return ConnectionStatus.offlineManual;
      case 'online':
        return ConnectionStatus.online;
      default:
        return ConnectionStatus.online;
    }
  }

  // ─── Computed helpers ─────────────────────────────────
  String get firstName => childName.split(' ').first;
  String get greeting => 'Hei, ini HP-nya $childName 👋';

  /// Status efektif — kalau DB bilang online tapi heartbeat sudah
  /// basi (>2 menit) atau belum pernah ada, anggap tidak terhubung
  ConnectionStatus get effectiveStatus {
    if (connectionStatus == ConnectionStatus.online) {
      // Belum pernah kirim heartbeat — data lama/stale
      if (lastSeen == null) {
        return ConnectionStatus.offlineManual;
      }
      // Heartbeat basi > 2 menit — internet putus
      final staleness = DateTime.now().toUtc().difference(lastSeen!);
      if (staleness.inMinutes >= 2) {
        return ConnectionStatus.offlineInternet;
      }
    }
    return connectionStatus;
  }

  bool get isOnline => effectiveStatus == ConnectionStatus.online;

  String get connectionLabel {
    switch (effectiveStatus) {
      case ConnectionStatus.online:
        return 'Terhubung';
      case ConnectionStatus.offlineInternet:
        return 'Terputus — Koneksi';
      case ConnectionStatus.offlineManual:
        return 'Terputus — Manual';
    }
  }

  String get connectionDescription {
    switch (effectiveStatus) {
      case ConnectionStatus.online:
        return 'HP anak terhubung dan sedang dipantau oleh PERISAI';
      case ConnectionStatus.offlineInternet:
        return 'Koneksi internet anak terputus. PERISAI tidak bisa memantau sampai internet kembali stabil';
      case ConnectionStatus.offlineManual:
        return 'Anak mematikan layanan PERISAI secara manual. Hubungi anak kamu untuk mengaktifkan kembali';
    }
  }

  /// Teks "terakhir terlihat X menit/jam/hari lalu"
  String get lastSeenText {
    if (lastSeen == null) return 'Tidak diketahui';
    final diff = DateTime.now().difference(lastSeen!);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  /// Copy-with helper buat update status
  Child copyWith({
    String? childName,
    int? age,
    String? phone,
    String? avatarUrl,
    ConnectionStatus? connectionStatus,
    DateTime? lastSeen,
  }) {
    return Child(
      id: id,
      parentId: parentId,
      childName: childName ?? this.childName,
      age: age ?? this.age,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
