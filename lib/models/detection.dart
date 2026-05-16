import 'dart:convert';

class Detection {
  final String id;
  final String childId;
  final String screenshotUrl;
  final double confidence;
  final String triggeredBy;
  final List<String> keywords;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  Detection({
    required this.id,
    required this.childId,
    required this.screenshotUrl,
    required this.confidence,
    required this.triggeredBy,
    required this.keywords,
    required this.details,
    required this.createdAt,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    // Handle details yang bisa String atau Map
    Map<String, dynamic> details = {};
    final rawDetails = json['details'];
    if (rawDetails is String && rawDetails.isNotEmpty) {
      try {
        details = Map<String, dynamic>.from(jsonDecode(rawDetails) as Map);
      } catch (_) {}
    } else if (rawDetails is Map) {
      details = Map<String, dynamic>.from(rawDetails);
    }

    // Handle confidence yang bisa String atau num
    final rawConfidence = json['confidence'];
    final confidence = rawConfidence is String
        ? double.tryParse(rawConfidence) ?? 0.0
        : (rawConfidence as num?)?.toDouble() ?? 0.0;

    // Handle screenshotUrl yang bisa null
    final screenshotUrl = json['screenshot_url'] as String? ?? '';

    // Handle triggeredBy yang bisa null
    final triggeredBy = json['triggered_by'] as String? ?? '';

    return Detection(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      screenshotUrl: screenshotUrl,
      confidence: confidence,
      triggeredBy: triggeredBy,
      keywords: List<String>.from(json['keywords'] ?? []),
      details: details,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'screenshot_url': screenshotUrl,
      'confidence': confidence,
      'triggered_by': triggeredBy,
      'keywords': keywords,
      'details': details,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  String get triggeredByLabel {
    switch (triggeredBy) {
      case 'ocr':
        return 'Baca Teks';
      case 'mobilenet':
        return 'Lihat Gambar';
      case 'trustpositif':
        return 'Cek URL';
      case 'combined':
        return 'Ketahuan dari mana-mana';
      default:
        return triggeredBy;
    }
  }

  bool get isHighConfidence => confidence >= 0.8;
}
