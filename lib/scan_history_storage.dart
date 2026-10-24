
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String scanHistoryKey = 'scamsathi_scan_history';

class ScanRecord {
  final String url;
  final String status;
  final String message;
  final DateTime timestamp;
  final String type;
  final String? scannedMessage;
  final int? score;
  final List<String> links;

  const ScanRecord({
    required this.url,
    required this.status,
    required this.message,
    required this.timestamp,
    this.type = 'link',
    this.scannedMessage,
    this.score,
    this.links = const [],
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'status': status,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'scannedMessage': scannedMessage,
    'score': score,
    'links': links,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      url: json['url'] as String? ?? '',
      status: json['status'] as String? ?? 'error',
      message: json['message'] as String? ?? 'No message available',
      timestamp: DateTime.tryParse(
        json['timestamp'] as String? ?? '',
      ) ?? DateTime.now(),
      type: json['type'] as String? ?? 'link',
      scannedMessage: json['scannedMessage'] as String?,
      score: json['score'] is num
          ? (json['score'] as num).toInt()
          : null,
      links: (json['links'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }
}

class ScanHistoryStorage {
  static Future<List<ScanRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(scanHistoryKey) ?? [];
    final records = <ScanRecord>[];

    for (final item in saved) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          records.add(ScanRecord.fromJson(decoded));
        }
      } catch (_) {}
    }

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  static Future<void> addRecord(ScanRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getHistory();
    records.insert(0, record);

    await prefs.setStringList(
      scanHistoryKey,
      records.take(100).map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(scanHistoryKey);
  }
}
