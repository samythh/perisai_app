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

  // Dari JSON Supabase ke object Dart
  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      id:            json['id'] as String,
      childId:       json['child_id'] as String,
      screenshotUrl: json['screenshot_url'] as String,
      confidence:    (json['confidence'] as num).toDouble(),
      triggeredBy:   json['triggered_by'] as String,
      keywords:      List<String>.from(json['keywords'] ?? []),
      details:       Map<String, dynamic>.from(json['details'] ?? {}),
      createdAt:     DateTime.parse(json['created_at'] as String),
    );
  }

  // Dari object Dart ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id':             id,
      'child_id':       childId,
      'screenshot_url': screenshotUrl,
      'confidence':     confidence,
      'triggered_by':   triggeredBy,
      'keywords':       keywords,
      'details':        details,
      'created_at':     createdAt.toIso8601String(),
    };
  }

  // Helper — confidence dalam persen
  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(0)}%';

  // Helper — label triggered_by yang friendly
  String get triggeredByLabel {
    switch (triggeredBy) {
      case 'ocr':          return 'Baca Teks';
      case 'mobilenet':    return 'Lihat Gambar';
      case 'trustpositif': return 'Cek URL';
      case 'combined':     return 'Ketahuan dari mana-mana 😬';
      default:             return triggeredBy;
    }
  }

  // Helper — apakah confidence tinggi (>= 80%)
  bool get isHighConfidence => confidence >= 0.8;
}