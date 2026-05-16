import '../../models/detection.dart';
import '../../models/child.dart';

class MockData {
  // Ganti ke false kalau Supabase sudah siap
  static const bool useMock = false;

  static final List<Child> children = [
    Child(
      id: 'mock-child-001',
      parentId: 'mock-parent-001',
      childName: 'Budi',
      age: 12,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    Child(
      id: 'mock-child-002',
      parentId: 'mock-parent-001',
      childName: 'Siti',
      age: 9,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  static final List<Detection> detections = [
    Detection(
      id: 'mock-det-001',
      childId: 'mock-child-001',
      screenshotUrl: 'https://placehold.co/400x800',
      confidence: 0.91,
      triggeredBy: 'combined',
      keywords: ['SPIN', 'BET', 'JACKPOT'],
      details: {
        'trustpositif': true,
        'mobilenet_confidence': 0.85,
        'ocr_keywords': ['SPIN', 'BET', 'JACKPOT'],
      },
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Detection(
      id: 'mock-det-002',
      childId: 'mock-child-001',
      screenshotUrl: 'https://placehold.co/400x800',
      confidence: 0.78,
      triggeredBy: 'mobilenet',
      keywords: [],
      details: {
        'trustpositif': false,
        'mobilenet_confidence': 0.78,
        'ocr_keywords': [],
      },
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Detection(
      id: 'mock-det-003',
      childId: 'mock-child-001',
      screenshotUrl: 'https://placehold.co/400x800',
      confidence: 0.95,
      triggeredBy: 'trustpositif',
      keywords: ['SLOT', 'DEPOSIT'],
      details: {
        'trustpositif': true,
        'mobilenet_confidence': 0.60,
        'ocr_keywords': ['SLOT', 'DEPOSIT'],
      },
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Detection(
      id: 'mock-det-004',
      childId: 'mock-child-002',
      screenshotUrl: 'https://placehold.co/400x800',
      confidence: 0.83,
      triggeredBy: 'ocr',
      keywords: ['WITHDRAW', 'BONUS', 'BET'],
      details: {
        'trustpositif': false,
        'mobilenet_confidence': 0.45,
        'ocr_keywords': ['WITHDRAW', 'BONUS', 'BET'],
      },
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    Detection(
      id: 'mock-det-005',
      childId: 'mock-child-001',
      screenshotUrl: 'https://placehold.co/400x800',
      confidence: 0.88,
      triggeredBy: 'combined',
      keywords: ['SPIN', 'WIN'],
      details: {
        'trustpositif': true,
        'mobilenet_confidence': 0.91,
        'ocr_keywords': ['SPIN', 'WIN'],
      },
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}