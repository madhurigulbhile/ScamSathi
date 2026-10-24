
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'login_screen.dart';
import 'scan_history_storage.dart';
import 'scam_message_checker_screen.dart';

void main() {
  runApp(const ScamSathiApp());
}

const Color appPurple = Color(0xFF6C3CE1);
const String backendUrl = 'http://10.150.101.58:3000/check';
const String authTokenKey = 'scamsathi_auth_token';

// ---------------- APP ----------------

class ScamSathiApp extends StatelessWidget {
  const ScamSathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScamSathi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: appPurple),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: appPurple,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ---------------- AUTH GATE ----------------

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<String?> tokenFuture;

  @override
  void initState() {
    super.initState();
    tokenFuture = AuthService.getToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const LoginScreen();
        }

        if (snapshot.data != null && snapshot.data!.isNotEmpty) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

// ---------------- HOME SCREEN ----------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout from ScamSathi?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove the saved authentication token.
      await prefs.remove(authTokenKey);

      if (!context.mounted) return;

      // Clear previous screens and open Login.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ScamSathi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan History',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ScanHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: appPurple,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_moon,
                  color: Colors.white,
                  size: 42,
                ),
                SizedBox(height: 12),
                Text(
                  'Stay Safe. Stay Alert.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your digital companion for detecting suspicious links '
                  'and learning about online scams.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Explore ScamSathi',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _feature(
            context,
            Icons.link,
            'Check Suspicious Links',
            'Check a URL using URLhaus.',
            Colors.deepPurple,
            const LinkCheckerScreen(),
          ),
          _feature(
            context,
            Icons.message_outlined,
            'Scam Message Checker',
            'Analyze suspicious SMS, WhatsApp messages and emails with AI.',
            Colors.deepOrange,
            const ScamMessageCheckerScreen(),
          ),
          _feature(
            context,
            Icons.history,
            'Scan History',
            'View your saved scans and results.',
            Colors.blue,
            const ScanHistoryScreen(),
          ),
          _feature(
            context,
            Icons.menu_book,
            'Learn About Scams',
            'Learn practical ways to protect yourself.',
            Colors.teal,
            const SafetyTipsScreen(),
          ),
          _feature(
            context,
            Icons.quiz,
            'Scam Awareness Quiz',
            'Test your knowledge with 10 questions.',
            Colors.orange,
            const QuizScreen(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Never share your OTP, PIN or password with anyone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
    Widget page,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(description),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
      ),
    );
  }
}

// ---------------- LINK CHECKER ----------------

class LinkCheckerScreen extends StatefulWidget {
  const LinkCheckerScreen({super.key});

  @override
  State<LinkCheckerScreen> createState() => _LinkCheckerScreenState();
}

class _LinkCheckerScreenState extends State<LinkCheckerScreen> {
  final TextEditingController urlController = TextEditingController();

  bool isLoading = false;
  String? resultStatus;
  String resultMessage = '';
  String? checkedUrl;

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  Future<void> checkUrl() async {
    String enteredUrl = urlController.text.trim();

    if (enteredUrl.isEmpty) {
      showMessage('Please enter a URL.');
      return;
    }

    if (!enteredUrl.contains('://')) {
      enteredUrl = 'https://$enteredUrl';
    }

    final uri = Uri.tryParse(enteredUrl);

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !uri.host.contains('.') ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      showMessage('Please enter a valid HTTP or HTTPS URL.');
      return;
    }

    setState(() {
      isLoading = true;
      resultStatus = null;
      resultMessage = '';
      checkedUrl = uri.toString();
    });

    String status = 'error';
    String message = 'Could not verify this URL.';

    try {
      final response = await http
          .post(
            Uri.parse(backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': uri.toString()}),
          )
          .timeout(const Duration(seconds: 25));

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        status = decoded['status']?.toString() ?? 'error';
        message = decoded['message']?.toString() ??
            'No additional details available.';
      } else {
        message = 'Scan service returned HTTP ${response.statusCode}.';
      }
    } catch (e) {
      message = 'Could not connect to the scan service: $e';
    }

    try {
      await ScanHistoryStorage.addRecord(
        ScanRecord(
          url: uri.toString(),
          status: status,
          message: message,
          timestamp: DateTime.now(),
          type: 'link',
        ),
      );
    } catch (e) {
      message += '\nWarning: This scan could not be saved to history.';
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      resultStatus = status;
      resultMessage = message;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color get resultColor {
    switch (resultStatus) {
      case 'listed':
        return Colors.red;
      case 'not_found':
        return Colors.orange.shade800;
      default:
        return Colors.deepOrange;
    }
  }

  String get resultTitle {
    switch (resultStatus) {
      case 'listed':
        return 'Threat Listed';
      case 'not_found':
        return 'No Listing Found';
      default:
        return 'Could Not Verify';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check Suspicious Links')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.travel_explore,
            size: 65,
            color: appPurple,
          ),
          const SizedBox(height: 12),
          const Text(
            'Check a suspicious link',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://example.com',
              labelText: 'Website URL',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (_) {
              if (!isLoading) checkUrl();
            },
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: isLoading ? null : checkUrl,
            icon: const Icon(Icons.security),
            label: Text(isLoading ? 'Checking...' : 'Check URL'),
            style: FilledButton.styleFrom(
              backgroundColor: appPurple,
              padding: const EdgeInsets.all(16),
            ),
          ),
          if (isLoading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (resultStatus != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resultTitle,
                      style: TextStyle(
                        color: resultColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(checkedUrl ?? ''),
                    const SizedBox(height: 10),
                    Text(resultMessage),
                    const SizedBox(height: 12),
                    const Text(
                      'A URL not found in URLhaus is not guaranteed safe.',
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScanHistoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('View Scan History'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------- SCAN HISTORY ----------------

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  List<ScanRecord> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    setState(() => isLoading = true);

    try {
      final savedRecords = await ScanHistoryStorage.getHistory();

      if (!mounted) return;

      setState(() {
        records = savedRecords;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => isLoading = false);
      showMessage('Could not load scan history.');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> clearHistory() async {
    if (records.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Scan History?'),
        content: const Text(
          'This will delete all locally saved scan records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ScanHistoryStorage.clearHistory();

    if (!mounted) return;

    setState(() => records = []);
    showMessage('Scan history cleared.');
  }

  String formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loadHistory,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear history',
            onPressed: records.isEmpty ? null : clearHistory,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 70,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Scan History Yet',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Your saved scans will appear here.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LinkCheckerScreen(),
                            ),
                          ).then((_) => loadHistory());
                        },
                        icon: const Icon(Icons.link),
                        label: const Text('Check a URL'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${records.length} saved scan(s)',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: clearHistory,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Clear All'),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'A URL not listed in URLhaus is not necessarily safe.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: loadHistory,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            final isMessage = record.type == 'message';

                            final color =
                                record.status.toLowerCase() == 'high' ||
                                        record.status == 'listed'
                                    ? Colors.red
                                    : record.status.toLowerCase() == 'medium' ||
                                            record.status == 'not_found'
                                        ? Colors.orange.shade800
                                        : Colors.green.shade700;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isMessage
                                              ? Icons.message_outlined
                                              : Icons.link,
                                          color: color,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isMessage
                                                ? 'AI Message Scan'
                                                : 'URL Scan',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (record.score != null)
                                          Text(
                                            '${record.score}/100',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      record.status,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (isMessage &&
                                        (record.scannedMessage ?? '').isNotEmpty)
                                      Text(
                                        'Scanned message: ${record.scannedMessage}',
                                      ),
                                    if (!isMessage && record.url.isNotEmpty)
                                      SelectableText(
                                        record.url,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(record.message),
                                    if (record.links.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Detected links:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      ...record.links.map(
                                        (link) => SelectableText('• $link'),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(
                                      formatDate(record.timestamp),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ---------------- SAFETY TIPS ----------------

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  static const List<Map<String, String>> tips = [
    {
      'title': 'Never Share Your OTP',
      'description':
          'Never disclose an OTP, PIN or password to a caller or message sender.',
    },
    {
      'title': 'Check Links Carefully',
      'description':
          'Look for misspelled domains, strange URLs and shortened links.',
    },
    {
      'title': 'Avoid Unknown Payments',
      'description':
          'Do not scan unknown QR codes or approve payment requests to receive money.',
    },
    {
      'title': 'Verify Customer Support',
      'description':
          'Find customer-care numbers through the official website or app.',
    },
    {
      'title': 'Beware of Fake Jobs',
      'description':
          'Be cautious if a recruiter asks for a fee or deposit to offer a job.',
    },
    {
      'title': 'Report Cybercrime',
      'description':
          'In India, call 1930 for financial cyber fraud and report at cybercrime.gov.in.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn About Scams')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          final tip = tips[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                child: Icon(Icons.shield, color: appPurple),
              ),
              title: Text(
                tip['title']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(tip['description']!),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- QUIZ ----------------

class QuizQuestion {
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });
}

const List<QuizQuestion> quizQuestions = [
  QuizQuestion(
    question: 'Someone asks for your bank OTP. What should you do?',
    options: ['Share it', 'Never share it', 'Post it online', 'Send half'],
    answerIndex: 1,
    explanation: 'Keep OTPs private.',
  ),
  QuizQuestion(
    question: 'You receive a suspicious bank link. What is safest?',
    options: [
      'Open it immediately',
      'Enter your PIN',
      'Use the official bank app',
      'Forward it to everyone',
    ],
    answerIndex: 2,
    explanation: 'Use the official app or website.',
  ),
  QuizQuestion(
    question: 'A job offer requires an upfront fee. What might it be?',
    options: ['A guarantee', 'A possible scam', 'A bank service', 'A reward'],
    answerIndex: 1,
    explanation: 'Upfront job fees are a warning sign.',
  ),
  QuizQuestion(
    question: 'How should you manage passwords?',
    options: [
      'Share them',
      'Reuse everywhere',
      'Keep them private and strong',
      'Post them online',
    ],
    answerIndex: 2,
    explanation: 'Use strong, unique passwords.',
  ),
  QuizQuestion(
    question: 'Someone asks you to scan a QR code to receive money.',
    options: [
      'Scan without checking',
      'Enter your UPI PIN',
      'Verify the request',
      'Share your OTP',
    ],
    answerIndex: 2,
    explanation: 'Be cautious. A UPI PIN authorises payments.',
  ),
  QuizQuestion(
    question: 'A URL is not found in a threat database. What does it mean?',
    options: [
      'Guaranteed safe',
      'Not found in that database',
      'Cannot be hacked',
      'Always trustworthy',
    ],
    answerIndex: 1,
    explanation: 'New or unreported malicious URLs may be missing.',
  ),
  QuizQuestion(
    question: 'A caller demands instant payment and threatens you.',
    options: [
      'Pay immediately',
      'Share bank details',
      'Verify independently',
      'Give them your OTP',
    ],
    answerIndex: 2,
    explanation: 'Do not let threats stop independent verification.',
  ),
  QuizQuestion(
    question: 'What is two-factor authentication?',
    options: [
      'No password',
      'An additional identity check',
      'Sharing passwords',
      'A scam link',
    ],
    answerIndex: 1,
    explanation: 'It adds another verification step.',
  ),
  QuizQuestion(
    question: 'You suspect online financial fraud in India. What should you do?',
    options: [
      'Wait weeks',
      'Delete evidence',
      'Call 1930 promptly',
      'Share your OTP',
    ],
    answerIndex: 2,
    explanation: 'Report financial cyber fraud promptly.',
  ),
  QuizQuestion(
    question: 'Where should you download apps from?',
    options: [
      'Unknown links',
      'Trusted official sources',
      'Random messages',
      'Strangers asking for PINs',
    ],
    answerIndex: 1,
    explanation: 'Use trusted sources and review app permissions.',
  ),
];

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int questionIndex = 0;
  int score = 0;
  int? selectedAnswer;
  bool answered = false;
  bool finished = false;

  void chooseAnswer(int index) {
    if (answered) return;

    setState(() {
      selectedAnswer = index;
      answered = true;

      if (index == quizQuestions[questionIndex].answerIndex) {
        score++;
      }
    });
  }

  void nextQuestion() {
    if (questionIndex == quizQuestions.length - 1) {
      setState(() => finished = true);
    } else {
      setState(() {
        questionIndex++;
        selectedAnswer = null;
        answered = false;
      });
    }
  }

  void restartQuiz() {
    setState(() {
      questionIndex = 0;
      score = 0;
      selectedAnswer = null;
      answered = false;
      finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scam Awareness Quiz')),
      body: finished
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 80,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Quiz Completed!',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your score: $score / ${quizQuestions.length}',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      score >= 8
                          ? 'Excellent! Keep staying alert.'
                          : 'Keep learning safe online habits.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: restartQuiz,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Restart Quiz'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Question ${questionIndex + 1} of ${quizQuestions.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: appPurple,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (questionIndex + 1) / quizQuestions.length,
                  color: appPurple,
                  minHeight: 8,
                ),
                const SizedBox(height: 25),
                Text(
                  quizQuestions[questionIndex].question,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(
                  quizQuestions[questionIndex].options.length,
                  (index) {
                    final question = quizQuestions[questionIndex];
                    Color? tileColor;

                    if (answered && index == question.answerIndex) {
                      tileColor = Colors.green.withValues(alpha: 0.12);
                    } else if (answered && index == selectedAnswer) {
                      tileColor = Colors.red.withValues(alpha: 0.12);
                    }

                    return Card(
                      color: tileColor,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(question.options[index]),
                        onTap: () => chooseAnswer(index),
                      ),
                    );
                  },
                ),
                if (answered) ...[
                  const SizedBox(height: 12),
                  Text(quizQuestions[questionIndex].explanation),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: nextQuestion,
                    child: Text(
                      questionIndex == quizQuestions.length - 1
                          ? 'See Results'
                          : 'Next Question',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

