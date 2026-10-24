
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'scan_history_storage.dart';

class ScamMessageCheckerScreen extends StatefulWidget {
  const ScamMessageCheckerScreen({super.key});

  @override
  State<ScamMessageCheckerScreen> createState() =>
      _ScamMessageCheckerScreenState();
}

class _ScamMessageCheckerScreenState
    extends State<ScamMessageCheckerScreen> {
  final TextEditingController _messageController =
      TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _linkError;

  Map<String, dynamic>? _result;
  Map<String, dynamic>? _linkResult;

  String _selectedPlatform = 'WhatsApp';

  static const String _aiApiUrl =
      'http://10.150.101.58:3000/api/scam-messages/analyze-message';

  static const String _linkApiUrl =
      'http://10.150.101.58:3000/api/message-links/check-message-links';

  // ---------------- API REQUEST ----------------

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 130),
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        return {
          '_requestError':
              'The server returned an invalid response '
              '(HTTP ${response.statusCode}).',
        };
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      final errorMessage =
          decoded is Map && decoded['error'] != null
              ? decoded['error'].toString()
              : 'Request failed with HTTP ${response.statusCode}.';

      return {'_requestError': errorMessage};
    } catch (e) {
      debugPrint('API request error: $e');

      return {
        '_requestError':
            'Could not connect to the service. Check your network, '
            'backend server and API address.',
      };
    }
  }

  // ---------------- ANALYZE MESSAGE ----------------

  Future<void> _analyzeMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      setState(() {
        _error = 'Please enter a message to analyze.';
        _linkError = null;
        _result = null;
        _linkResult = null;
      });
      return;
    }

    if (message.length > 10000) {
      setState(() {
        _error = 'Message must be 10,000 characters or fewer.';
        _linkError = null;
        _result = null;
        _linkResult = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _linkError = null;
      _result = null;
      _linkResult = null;
    });

    try {
      // AI analysis and link checking run together.
      final results = await Future.wait([
        _postJson(
          _aiApiUrl,
          {
            'message': message,
            'platform': _selectedPlatform,
          },
        ),
        _postJson(
          _linkApiUrl,
          {'message': message},
          timeout: const Duration(seconds: 45),
        ),
      ]);

      final aiData = results[0];
      final linkData = results[1];

      // Save the message scan when AI analysis succeeds.
      if (!aiData.containsKey('_requestError')) {
        try {
          final dynamic rawScore = aiData['score'];
          final dynamic rawLinks = linkData['results'];

          final List<String> detectedLinks = rawLinks is List
              ? rawLinks
                  .whereType<Map>()
                  .map(
                    (item) => item['url']?.toString() ?? '',
                  )
                  .where((url) => url.isNotEmpty)
                  .toList()
              : <String>[];

          await ScanHistoryStorage.addRecord(
            ScanRecord(
              url: '',
              status: aiData['riskLevel']?.toString() ?? 'Unknown',
              message: aiData['summary']?.toString() ??
                  'No summary available.',
              timestamp: DateTime.now(),
              type: 'message',
              scannedMessage: message,
              score: rawScore is num ? rawScore.toInt() : null,
              links: detectedLinks,
            ),
          );

          debugPrint('AI scan saved to history.');
        } catch (e) {
          // A storage problem should not hide the AI result.
          debugPrint('Could not save AI scan history: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        if (aiData.containsKey('_requestError')) {
          _error = aiData['_requestError'].toString();
        } else {
          _result = aiData;
        }

        if (linkData.containsKey('_requestError')) {
          _linkError = linkData['_requestError'].toString();
        } else {
          _linkResult = linkData;
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Unexpected analysis error: $e');

      if (!mounted) return;

      setState(() {
        _error = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ---------------- COLORS AND LABELS ----------------

  Color _riskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange.shade800;
      case 'low':
        return Colors.green.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  Color _linkColor(String status) {
    switch (status.toLowerCase()) {
      case 'listed':
        return Colors.red;
      case 'not_found':
        return Colors.orange.shade800;
      case 'error':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _linkIcon(String status) {
    switch (status.toLowerCase()) {
      case 'listed':
        return Icons.gpp_bad;
      case 'not_found':
        return Icons.help_outline;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.link;
    }
  }

  String _linkStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'listed':
        return 'MALICIOUS URL LISTING FOUND';
      case 'not_found':
        return 'NOT FOUND IN URLHAUS';
      case 'error':
        return 'CHECK FAILED';
      default:
        return 'UNKNOWN STATUS';
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => item.toString()).toList();
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        const SizedBox(width: 0),
        Icon(
          icon,
          color: const Color(0xFF6C3CE1),
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bulletList(
    List<String> items, {
    bool numbered = false,
  }) {
    if (items.isEmpty) {
      return const Text(
        'No specific details returned. Continue to use caution.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (numbered)
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFFEDE7F6),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6C3CE1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 19,
                  color: Colors.deepOrange,
                ),
              const SizedBox(width: 9),
              Expanded(child: Text(items[index])),
            ],
          ),
        );
      }),
    );
  }

  // ---------------- AI RESULT ----------------

  Widget _buildAiResult() {
    final result = _result!;

    final risk = result['riskLevel']?.toString() ?? 'Unknown';
    final color = _riskColor(risk);
    final score = result['score'];

    final scoreValue = score is num
        ? score.toDouble().clamp(0.0, 100.0).toDouble()
        : 0.0;

    final scamTypes = _stringList(result['scamTypes']);
    final indicators = _stringList(result['indicators']);
    final recommendations = _stringList(result['recommendations']);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              'AI Analysis Result',
              Icons.auto_awesome,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  risk.toLowerCase() == 'high'
                      ? Icons.gpp_bad
                      : risk.toLowerCase() == 'medium'
                          ? Icons.warning_amber_rounded
                          : Icons.verified_user_outlined,
                  size: 42,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$risk Risk',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text('Selected source: $_selectedPlatform'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Risk Score',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  score == null ? 'N/A' : '$score/100',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: scoreValue / 100,
              minHeight: 9,
              borderRadius: BorderRadius.circular(8),
              color: color,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 20),
            _sectionTitle(
              'AI Summary',
              Icons.description_outlined,
            ),
            const SizedBox(height: 8),
            Text('${result['summary'] ?? 'No summary available.'}'),
            if (scamTypes.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionTitle(
                'Possible Scam Categories',
                Icons.category_outlined,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: scamTypes.map((type) {
                  return Chip(
                    avatar: const Icon(
                      Icons.flag_outlined,
                      size: 17,
                    ),
                    label: Text(type),
                    backgroundColor: const Color(0xFFEDE7F6),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 22),
            _sectionTitle(
              'Warning Signs',
              Icons.warning_amber_rounded,
            ),
            _bulletList(indicators),
            const SizedBox(height: 22),
            _sectionTitle(
              'Safety Recommendations',
              Icons.health_and_safety_outlined,
            ),
            _bulletList(recommendations, numbered: true),
            const SizedBox(height: 12),
            const Divider(),
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Successful AI scans are saved to Scan History.',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- LINK RESULTS ----------------

  Widget _buildLinkResults() {
    final data = _linkResult!;
    final dynamic rawResults = data['results'];

    final links = rawResults is List
        ? rawResults.whereType<Map>().toList()
        : <Map>[];

    final totalLinks = data['totalLinks'] is num
        ? (data['totalLinks'] as num).toInt()
        : links.length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              'Smart Link Detection',
              Icons.travel_explore,
            ),
            const SizedBox(height: 8),
            Text(
              totalLinks == 0
                  ? 'No recognizable links found in this message.'
                  : '$totalLinks link(s) detected',
              style: const TextStyle(color: Colors.grey),
            ),
            if (links.isEmpty && totalLinks == 0) ...[
              const SizedBox(height: 12),
              const Text(
                'The message did not contain a link that this checker '
                'could recognize. This does not mean the message itself '
                'is safe.',
              ),
            ],
            ...links.map((item) {
              final url = item['url']?.toString() ?? 'Unknown URL';
              final status = item['status']?.toString() ?? 'unknown';
              final message =
                  item['message']?.toString() ?? 'No details available.';
              final color = _linkColor(status);
              final urlStatus = item['urlStatus']?.toString();
              final reference = item['reference']?.toString();

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _linkIcon(status),
                          color: color,
                          size: 25,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: SelectableText(
                            url,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _linkStatusLabel(status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(message),
                    if (urlStatus != null) ...[
                      const SizedBox(height: 6),
                      Text('URL status: $urlStatus'),
                    ],
                    if (reference != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'URLhaus reference: $reference',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (data['skippedLinks'] is num &&
                (data['skippedLinks'] as num) > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${data['skippedLinks']} additional link(s) were not checked.',
                style: const TextStyle(color: Colors.orange),
              ),
            ],
            const SizedBox(height: 18),
            const Divider(),
            const Text(
              'Important: “Not found in URLhaus” does not mean a link '
              'is safe. Newly created or unreported malicious links may '
              'not be listed. Do not open suspicious links.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- DISPOSE ----------------

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ---------------- SCREEN UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScamSathi AI Checker'),
        backgroundColor: const Color(0xFF6C3CE1),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 56,
            color: Color(0xFF6C3CE1),
          ),
          const SizedBox(height: 10),
          const Text(
            'Smart Scam Detection',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analyze suspicious messages and check their links '
            'using AI and URLhaus.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            'Where did you receive this message?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedPlatform,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.forum_outlined,
                color: Color(0xFF6C3CE1),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'WhatsApp',
                child: Text('WhatsApp Message'),
              ),
              DropdownMenuItem(
                value: 'SMS',
                child: Text('SMS / Text Message'),
              ),
              DropdownMenuItem(
                value: 'Email',
                child: Text('Email'),
              ),
              DropdownMenuItem(
                value: 'Other',
                child: Text('Other'),
              ),
            ],
            onChanged: _isLoading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPlatform = value;
                      });
                    }
                  },
          ),
          const SizedBox(height: 18),
          const Text(
            'Paste your message',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 7,
            maxLength: 10000,
            decoration: InputDecoration(
              hintText: 'Paste suspicious SMS, WhatsApp or email text...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyzeMessage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.security),
              label: Text(
                _isLoading
                    ? 'Analyzing message and links...'
                    : 'Analyze Message & Links',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3CE1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'AI analysis and URL checks are running. This may take '
              'a little time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 18),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'AI analysis: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
          if (_linkError != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Link check: $_linkError',
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 22),
            _buildAiResult(),
          ],
          if (_linkResult != null) ...[
            const SizedBox(height: 16),
            _buildLinkResults(),
          ],
        ],
      ),
    );
  }
}
