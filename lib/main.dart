import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:router_os_client/router_os_client.dart';

void main() {
  runApp(const WiTbryApp());
}

class WiTbryApp extends StatelessWidget {
  const WiTbryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wi-Tbry',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4016F9),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF081A33),
      ),
      home: const HomePage(),
    );
  }
}

/* ============================================================
   MODEL
============================================================ */

class HotspotCard {
  final String username;
  final String password;
  final String profile;

  HotspotCard({
    required this.username,
    required this.password,
    required this.profile,
  });
}

/* ============================================================
   MIKROTIK SERVICE
============================================================ */

class MikroTikService {
  RouterOSClient? client;

  bool connected = false;

  Future<void> connect({
    required String host,
    required String username,
    required String password,
    required int port,
    required bool ssl,
  }) async {
    await disconnect();

    client = RouterOSClient(
      address: host,
      user: username,
      password: password,
      port: port,
      useSsl: ssl,
      timeout: const Duration(seconds: 10),
    );

    final result = await client!.login();

    if (!result) {
      client = null;
      connected = false;
      throw Exception('فشل تسجيل الدخول إلى MikroTik');
    }

    connected = true;
  }

  Future<void> disconnect() async {
    try {
      client?.close();
    } catch (_) {}

    client = null;
    connected = false;
  }

  Future<List<Map<String, String>>> getProfiles() async {
    if (!connected || client == null) {
      throw Exception('MikroTik غير متصل');
    }

    return await client!.talk(
      '/ip/hotspot/user/profile/print',
    );
  }

  Future<List<Map<String, String>>> getUsers() async {
    if (!connected || client == null) {
      throw Exception('MikroTik غير متصل');
    }

    return await client!.talk(
      '/ip/hotspot/user/print',
    );
  }

  Future<List<Map<String, String>>> getActiveUsers() async {
    if (!connected || client == null) {
      throw Exception('MikroTik غير متصل');
    }

    return await client!.talk(
      '/ip/hotspot/active/print',
    );
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String profile,
  }) async {
    if (!connected || client == null) {
      throw Exception('MikroTik غير متصل');
    }

    await client!.talk(
      '/ip/hotspot/user/add',
      {
        'name': username,
        'password': password,
        'profile': profile,
      },
    );
  }

  Future<void> removeUser(String username) async {
    if (!connected || client == null) {
      throw Exception('MikroTik غير متصل');
    }

    final users = await client!.talk(
      '/ip/hotspot/user/print',
      {
        '?name': username,
      },
    );

    if (users.isEmpty) {
      throw Exception('الكرت غير موجود');
    }

    final id = users.first['.id'];

    if (id == null) {
      throw Exception('تعذر الحصول على ID الكرت');
    }

    await client!.talk(
      '/ip/hotspot/user/remove',
      {
        '.id': id,
      },
    );
  }
}

/* ============================================================
   CARD GENERATOR
============================================================ */

class CardGenerator {
  static final Random _random = Random();

  static String username() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    return List.generate(
      8,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  static String password() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

    return List.generate(
      6,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}

/* ============================================================
   PDF GENERATOR
============================================================ */

class PdfGenerator {
  static Future<Uint8List> createCardsPdf(
    List<HotspotCard> cards,
  ) async {
    final document = pw.Document();

    const columns = 3;
    const rows = 4;

    final cardsPerPage = columns * rows;

    for (int start = 0; start < cards.length; start += cardsPerPage) {
      final end = min(start + cardsPerPage, cards.length);

      final pageCards = cards.sublist(start, end);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (context) {
            return pw.GridView(
              crossAxisCount: columns,
              childAspectRatio: 1.65,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: List.generate(
                cardsPerPage,
                (index) {
                  if (index >= pageCards.length) {
                    return pw.Container();
                  }

                  final card = pageCards[index];

                  return _cardWidget(card);
                },
              ),
            );
          },
        ),
      );
    }

    return Uint8List.fromList(await document.save());
  }

  static pw.Widget _cardWidget(HotspotCard card) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(
          color: PdfColors.blue900,
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Wi-Tbry',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'HOTSPOT',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(
              card.username,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Password: ${card.password}',
            style: const pw.TextStyle(
              fontSize: 9,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            card.profile,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   HOME PAGE
============================================================ */

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MikroTikService mikrotik = MikroTikService();

  final TextEditingController hostController =
      TextEditingController(text: '10.10.10.1');

  final TextEditingController userController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController portController =
      TextEditingController(text: '8729');

  final TextEditingController countController =
      TextEditingController(text: '10');

  bool ssl = true;
  bool loading = false;

  String status = 'غير متصل';

  List<String> profiles = [];

  String selectedProfile = '';

  List<HotspotCard> generatedCards = [];

  List<Map<String, String>> activeUsers = [];

  @override
  void dispose() {
    hostController.dispose();
    userController.dispose();
    passwordController.dispose();
    portController.dispose();
    countController.dispose();

    mikrotik.disconnect();

    super.dispose();
  }

  bool get connected => mikrotik.connected;

  Future<void> connect() async {
    setState(() {
      loading = true;
      status = 'جاري الاتصال...';
    });

    try {
      await mikrotik.connect(
        host: hostController.text.trim(),
        username: userController.text.trim(),
        password: passwordController.text,
        port: int.tryParse(portController.text) ?? 8729,
        ssl: ssl,
      );

      final result = await mikrotik.getProfiles();

      final names = result
          .map((e) => e['name'])
          .whereType<String>()
          .toList();

      setState(() {
        status = 'متصل';
        profiles = names;

        if (profiles.isNotEmpty) {
          selectedProfile = profiles.first;
        }
      });
    } catch (e) {
      setState(() {
        status = 'خطأ';
      });

      showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> generateCards() async {
    if (!connected) {
      showError('اتصل بالـ MikroTik أولًا');
      return;
    }

    final count = int.tryParse(countController.text);

    if (count == null || count < 1 || count > 5000) {
      showError('عدد الكروت يجب أن يكون من 1 إلى 5000');
      return;
    }

    if (selectedProfile.isEmpty) {
      showError('اختر البروفايل');
      return;
    }

    setState(() {
      loading = true;
      generatedCards.clear();
    });

    try {
      final cards = <HotspotCard>[];

      for (int i = 0; i < count; i++) {
        final username = CardGenerator.username();
        final password = CardGenerator.password();

        await mikrotik.createUser(
          username: username,
          password: password,
          profile: selectedProfile,
        );

        cards.add(
          HotspotCard(
            username: username,
            password: password,
            profile: selectedProfile,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        generatedCards = cards;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إنشاء ${cards.length} كرت بنجاح',
          ),
        ),
      );
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> printCards() async {
    if (generatedCards.isEmpty) {
      showError('لا توجد كروت للطباعة');
      return;
    }

    final Uint8List pdf =
        await PdfGenerator.createCardsPdf(generatedCards);

    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'Wi-Tbry-Cards.pdf',
    );
  }

  Future<void> loadActiveUsers() async {
    if (!connected) {
      showError('اتصل بالـ MikroTik أولًا');
      return;
    }

    try {
      final result = await mikrotik.getActiveUsers();

      setState(() {
        activeUsers = result;
      });

      showActiveUsers();
    } catch (e) {
      showError(e.toString());
    }
  }

  Future<void> searchUser() async {
    if (!connected) {
      showError('اتصل بالـ MikroTik أولًا');
      return;
    }

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();

        return AlertDialog(
          title: const Text('البحث عن كرت'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'اسم المستخدم',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child: const Text('بحث'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    try {
      final users = await mikrotik.getUsers();

      final found = users.where(
        (u) => u['name'] == name,
      );