import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:router_os_client/router_os_client.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const WiTbryApp());
}

// ============================================================
// APP
// ============================================================

class WiTbryApp extends StatelessWidget {
  const WiTbryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wi-Tbry',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
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

// ============================================================
// HOTSPOT CARD
// ============================================================

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

// ============================================================
// MIKROTIK SERVICE
// ============================================================

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
      throw Exception(
        'فشل تسجيل الدخول إلى MikroTik',
      );
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
      throw Exception(
        'MikroTik غير متصل',
      );
    }

    return await client!.talk(
      '/ip/hotspot/user/profile/print',
    );
  }

  Future<List<Map<String, String>>> getUsers() async {
    if (!connected || client == null) {
      throw Exception(
        'MikroTik غير متصل',
      );
    }

    return await client!.talk(
      '/ip/hotspot/user/print',
    );
  }

  Future<List<Map<String, String>>> getActiveUsers() async {
    if (!connected || client == null) {
      throw Exception(
        'MikroTik غير متصل',
      );
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
      throw Exception(
        'MikroTik غير متصل',
      );
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

  Future<void> removeUser(
    String username,
  ) async {
    if (!connected || client == null) {
      throw Exception(
        'MikroTik غير متصل',
      );
    }

    final users = await client!.talk(
      '/ip/hotspot/user/print',
      {
        '?name': username,
      },
    );

    if (users.isEmpty) {
      throw Exception(
        'الكرت غير موجود',
      );
    }

    final id = users.first['.id'];

    if (id == null) {
      throw Exception(
        'تعذر الحصول على ID الكرت',
      );
    }

    await client!.talk(
      '/ip/hotspot/user/remove',
      {
        '.id': id,
      },
    );
  }
}

// ============================================================
// CARD GENERATOR
// ============================================================

class CardGenerator {
  static final Random _random = Random();

  static String username() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    return List.generate(
      8,
      (_) => chars[
          _random.nextInt(chars.length)
      ],
    ).join();
  }

  static String password() {
    const chars =
        '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

    return List.generate(
      6,
      (_) => chars[
          _random.nextInt(chars.length)
      ],
    ).join();
  }
}

// ============================================================
// PDF GENERATOR
// ============================================================

class PdfGenerator {
  static Future<Uint8List> createCardsPdf(
    List<HotspotCard> cards,
  ) async {
    final document = pw.Document();

    const int columns = 3;
    const int rows = 4;
    const int cardsPerPage =
        columns * rows;

    for (
      int start = 0;
      start < cards.length;
      start += cardsPerPage
    ) {
      final int end = min(
        start + cardsPerPage,
        cards.length,
      );

      final pageCards =
          cards.sublist(start, end);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin:
              const pw.EdgeInsets.all(18),
          build: (context) {
            return pw.GridView(
              crossAxisCount: columns,
              childAspectRatio: 1.65,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: List.generate(
                cardsPerPage,
                (index) {
                  if (index >=
                      pageCards.length) {
                    return pw.Container();
                  }

                  return _cardWidget(
                    pageCards[index],
                  );
                },
              ),
            );
          },
        ),
      );
    }

    return Uint8List.fromList(
      await document.save(),
    );
  }

  static pw.Widget _cardWidget(
    HotspotCard card,
  ) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        borderRadius:
            pw.BorderRadius.circular(12),
        border: pw.Border.all(
          color: PdfColors.blue900,
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.center,
        mainAxisAlignment:
            pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Wi-Tbry',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight:
                  pw.FontWeight.bold,
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
            padding:
                const pw.EdgeInsets
                    .symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration:
                pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius:
                  pw.BorderRadius.circular(
                5,
              ),
            ),
            child: pw.Text(
              card.username,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 5),

          pw.Text(
            'Password: ${card.password}',
            style:
                const pw.TextStyle(
              fontSize: 9,
            ),
          ),

          pw.SizedBox(height: 4),

          pw.Text(
            card.profile,
            style:
                const pw.TextStyle(
              fontSize: 8,
              color:
                  PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState
    extends State<HomePage> {
  final MikroTikService mikrotik =
      MikroTikService();

  final TextEditingController
      hostController =
      TextEditingController(
    text: '10.10.10.1',
  );

  final TextEditingController
      userController =
      TextEditingController();

  final TextEditingController
      passwordController =
      TextEditingController();

  final TextEditingController
      portController =
      TextEditingController(
    text: '8729',
  );

  final TextEditingController
      countController =
      TextEditingController(
    text: '10',
  );

  bool ssl = true;
  bool loading = false;

  String status = 'غير متصل';

  List<String> profiles = [];

  String selectedProfile = '';

  List<HotspotCard> generatedCards = [];

  List<Map<String, String>>
      activeUsers = [];

  bool get connected =>
      mikrotik.connected;

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

  // ==========================================================
  // CONNECT
  // ==========================================================

  Future<void> connect() async {
    setState(() {
      loading = true;
      status = 'جاري الاتصال...';
    });

    try {
      await mikrotik.connect(
        host:
            hostController.text.trim(),
        username:
            userController.text.trim(),
        password:
            passwordController.text,
        port:
            int.tryParse(
                  portController.text,
                ) ??
                8729,
        ssl: ssl,
      );

      final result =
          await mikrotik.getProfiles();

      final List<String> names =
          result
              .map(
                (e) => e['name'],
              )
              .whereType<String>()
              .toList();

      if (!mounted) return;

      setState(() {
        status = 'متصل';
        profiles = names;

        if (profiles.isNotEmpty) {
          selectedProfile =
              profiles.first;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        status = 'خطأ';
      });

      showError(
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // GENERATE CARDS
  // ==========================================================

  Future<void> generateCards() async {
    if (!connected) {
      showError(
        'اتصل بالـ MikroTik أولًا',
      );
      return;
    }

    final int? count =
        int.tryParse(
      countController.text,
    );

    if (count == null ||
        count < 1 ||
        count > 5000) {
      showError(
        'عدد الكروت يجب أن يكون من 1 إلى 5000',
      );
      return;
    }

    if (selectedProfile.isEmpty) {
      showError(
        'اختر البروفايل',
      );
      return;
    }

    setState(() {
      loading = true;
      generatedCards.clear();
    });

    try {
      final List<HotspotCard> cards =
          [];

      for (int i = 0;
          i < count;
          i++) {
        final String username =
            CardGenerator.username();

        final String password =
            CardGenerator.password();

        await mikrotik.createUser(
          username: username,
          password: password,
          profile: selectedProfile,
        );

        cards.add(
          HotspotCard(
            username: username,
            password: password,
            profile:
                selectedProfile,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        generatedCards = cards;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'تم إنشاء ${cards.length} كرت بنجاح',
          ),
        ),
      );
    } catch (e) {
      showError(
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // PRINT
  // ==========================================================

  Future<void> printCards() async {
    if (generatedCards.isEmpty) {
      showError(
        'لا توجد كروت للطباعة',
      );
      return;
    }

    try {
      final Uint8List pdf =
          await PdfGenerator
              .createCardsPdf(
        generatedCards,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name:
            'Wi-Tbry-Cards.pdf',
      );
    } catch (e) {
      showError(
        'فشل إنشاء PDF: $e',
      );
    }
  }

  // ==========================================================
  // ACTIVE USERS
  // ==========================================================

  Future<void> loadActiveUsers() async {
    if (!connected) {
      showError(
        'اتصل بالـ MikroTik أولًا',
      );
      return;
    }

    try {
      final result =
          await mikrotik
              .getActiveUsers();

      if (!mounted) return;

      setState(() {
        activeUsers = result;
      });

      showActiveUsers();
    } catch (e) {
      showError(
        e.toString(),
      );
    }
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  Future<void> searchUser() async {
    if (!connected) {
      showError(
        'اتصل بالـ MikroTik أولًا',
      );
      return;
    }

    final String? name =
        await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController
            controller =
            TextEditingController();

        return AlertDialog(
          title: const Text(
            'البحث عن كرت',
          ),
          content: TextField(
            controller: controller,
            decoration:
                const InputDecoration(
              labelText:
                  'اسم المستخدم',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                'إلغاء',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text
                      .trim(),
                );
              },
              child: const Text(
                'بحث',
              ),
            ),
          ],
        );
      },
    );

    if (name == null ||
        name.isEmpty) {
      return;
    }

    try {
      final users =
          await mikrotik.getUsers();

      final found = users.where(
        (u) => u['name'] == name,
      );

      if (found.isEmpty) {
        showError(
          'الكرت غير موجود',
        );
        return;
      }

      final user = found.first;

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text(
              'بيانات الكرت',
            ),
            content: Text(
              'Username: ${user['name'] ?? ''}\n'
              'Profile: ${user['profile'] ?? ''}\n'
              'Disabled: ${user['disabled'] ?? ''}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                },
                child: const Text(
                  'إغلاق',
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      showError(
        e.toString(),
      );
    }
  }

  // ==========================================================
  // ACTIVE USERS DIALOG
  // ==========================================================

  void showActiveUsers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SizedBox(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  0.8,
          child: Column(
            children: [
              const SizedBox(
                height: 15,
              ),

              const Text(
                'المتصلون حاليًا',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const Divider(),

              Expanded(
                child:
                    activeUsers.isEmpty
                        ? const Center(
                            child: Text(
                              'لا يوجد مستخدمون متصلون',
                            ),
                          )
                        : ListView.builder(
                            itemCount:
                                activeUsers.length,
                            itemBuilder:
                                (_, index) {
                              final u =
                                  activeUsers[
                                      index];

                              return ListTile(
                                leading:
                                    const Icon(
                                  Icons.person,
                                  color: Colors
                                      .green,
                                ),
                                title:
                                    Text(
                                  u['user'] ??
                                      u['name'] ??
                                      'Unknown',
                                ),
                                subtitle:
                                    Text(
                                  'IP: ${u['address'] ?? '-'}',
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  void showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        backgroundColor:
            Colors.red.shade800,
        content: Text(
          message,
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wi-Tbry',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,

        actions: [
          Icon(
            connected
                ? Icons.cloud_done
                : Icons.cloud_off,
            color: connected
                ? Colors.greenAccent
                : Colors.redAccent,
          ),

          IconButton(
            tooltip:
                'عن التطبيق',
            icon: const Icon(
              Icons.info_outline,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AboutPage(),
                ),
              );
            },
          ),

          const SizedBox(
            width: 8,
          ),
        ],
      ),

      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child: Column(
            children: [
              connectionCard(),

              const SizedBox(
                height: 15,
              ),

              cardGeneratorCard(),

              const SizedBox(
                height: 15,
              ),

              actionButtons(),

              const SizedBox(
                height: 15,
              ),

              cardsPreview(),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // CONNECTION CARD
  // ==========================================================

  Widget connectionCard() {
    return Card(
      elevation: 5,
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(
                  Icons.router,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  'اتصال MikroTik',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            TextField(
              controller:
                  hostController,
              decoration:
                  const InputDecoration(
                labelText:
                    'IP / Host',
                prefixIcon:
                    Icon(
                  Icons.language,
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            TextField(
              controller:
                  userController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Username',
                prefixIcon:
                    Icon(
                  Icons.person,
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            TextField(
              controller:
                  passwordController,
              obscureText: true,
              decoration:
                  const InputDecoration(
                labelText:
                    'Password',
                prefixIcon:
                    Icon(
                  Icons.lock,
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        portController,
                    keyboardType:
                        TextInputType
                            .number,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'API Port',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Column(
                  children: [
                    const Text(
                      'SSL',
                    ),

                    Switch(
                      value: ssl,
                      onChanged:
                          (value) {
                        setState(() {
                          ssl = value;

                          portController
                                  .text =
                              value
                                  ? '8729'
                                  : '8728';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style:
                        TextStyle(
                      color: connected
                          ? Colors
                              .greenAccent
                          : Colors
                              .orangeAccent,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                FilledButton.icon(
                  onPressed:
                      loading
                          ? null
                          : connect,
                  icon:
                      const Icon(
                    Icons.link,
                  ),
                  label:
                      const Text(
                    'اتصال',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // CARD GENERATOR
  // ==========================================================

  Widget cardGeneratorCard() {
    return Card(
      elevation: 5,
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(
                  Icons.confirmation_num,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  'إصدار الكروت',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            DropdownButtonFormField<
                String>(
              value:
                  selectedProfile
                          .isEmpty
                      ? null
                      : selectedProfile,

              decoration:
                  const InputDecoration(
                labelText:
                    'Hotspot Profile',
                prefixIcon:
                    Icon(
                  Icons.speed,
                ),
              ),

              items: profiles
                  .map(
                    (profile) {
                      return DropdownMenuItem<
                          String>(
                        value: profile,
                        child:
                            Text(
                          profile,
                        ),
                      );
                    },
                  )
                  .toList(),

              onChanged:
                  connected
                      ? (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            selectedProfile =
                                value;
                          });
                        }
                      : null,
            ),

            const SizedBox(
              height: 15,
            ),

            TextField(
              controller:
                  countController,
              keyboardType:
                  TextInputType
                      .number,
              decoration:
                  const InputDecoration(
                labelText:
                    'عدد الكروت',
                hintText:
                    'من 1 إلى 5000',
                prefixIcon:
                    Icon(
                  Icons.numbers,
                ),
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            SizedBox(
              width:
                  double.infinity,
              height: 52,
              child:
                  FilledButton.icon(
                onPressed:
                    loading
                        ? null
                        : generateCards,
                icon:
                    const Icon(
                  Icons.add_card,
                ),
                label: Text(
                  loading
                      ? 'جاري إنشاء الكروت...'
                      : 'إنشاء الكروت',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ACTION BUTTONS
  // ==========================================================

  Widget actionButtons() {
    return Row(
      children: [
        Expanded(
          child:
              OutlinedButton.icon(
            onPressed:
                connected
                    ? loadActiveUsers
                    : null,
            icon:
                const Icon(
              Icons.people,
            ),
            label:
                const Text(
              'المتصلون',
            ),
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        Expanded(
          child:
              OutlinedButton.icon(
            onPressed:
                connected
                    ? searchUser
                    : null,
            icon:
                const Icon(
              Icons.search,
            ),
            label:
                const Text(
              'بحث',
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CARDS PREVIEW
  // ==========================================================

  Widget cardsPreview() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الكروت الجاهزة',
                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  '${generatedCards.length}',
                  style:
                      const TextStyle(
                    fontSize: 20,
                    color:
                        Colors.greenAccent,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            if (generatedCards
                .isEmpty)
              const Padding(
                padding:
                    EdgeInsets.all(
                  20,
                ),
                child: Text(
                  'لم يتم إنشاء كروت بعد',
                ),
              )
            else ...[
              SizedBox(
                height: 250,
                child:
                    ListView.builder(
                  itemCount:
                      generatedCards
                          .length,
                  itemBuilder:
                      (_, index) {
                    final card =
                        generatedCards[
                            index];

                    return ListTile(
                      leading:
                          CircleAvatar(
                        child: Text(
                          '${index + 1}',
                        ),
                      ),

                      title: Text(
                        card.username,
                      ),

                      subtitle:
                          Text(
                        'Password: ${card.password}\n'
                        'Profile: ${card.profile}',
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    FilledButton.icon(
                  onPressed:
                      loading
                          ? null
                          : printCards,
                  icon:
                      const Icon(
                    Icons.print,
                  ),
                  label:
                      const Text(
                    'تصدير / طباعة PDF',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ABOUT PAGE
// ============================================================

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() =>
      _AboutPageState();
}

class _AboutPageState
    extends State<AboutPage> {
  String appVersion =
      'جاري التحميل...';

  static const String developerName =
      'حمزة الطيب';

  static const String whatsappNumber =
      '249916537047';

  @override
  void initState() {
    super.initState();

    loadAppVersion();
  }

  // ==========================================================
  // APP VERSION
  // ==========================================================

  Future<void> loadAppVersion() async {
    try {
      final info =
          await PackageInfo
              .fromPlatform();

      if (!mounted) return;

      setState(() {
        appVersion =
            '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        appVersion =
            'غير معروف';
      });
    }
  }

  // ==========================================================
  // WHATSAPP
  // ==========================================================

  Future<void> openWhatsApp() async {
    final Uri url = Uri.parse(
      'https://wa.me/$whatsappNumber',
    );

    try {
      final launched =
          await launchUrl(
        url,
        mode:
            LaunchMode
                .externalApplication,
      );

      if (!launched &&
          mounted) {
        showError(
          'تعذر فتح واتساب',
        );
      }
    } catch (_) {
      if (mounted) {
        showError(
          'تعذر فتح واتساب',
        );
      }
    }
  }

  // ==========================================================
  // CONTACT
  // ==========================================================

  Future<void> openContact() async {
    final Uri url =
        Uri.parse(
      'https://wa.me/$whatsappNumber',
    );

    try {
      final launched =
          await launchUrl(
        url,
        mode:
            LaunchMode
                .externalApplication,
      );

      if (!launched &&
          mounted) {
        showError(
          'تعذر فتح صفحة التواصل',
        );
      }
    } catch (_) {
      if (mounted) {
        showError(
          'تعذر فتح صفحة التواصل',
        );
      }
    }
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  void showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        backgroundColor:
            Colors.red.shade800,
        content: Text(
          message,
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'عن التطبيق',
        ),
        centerTitle: true,
      ),

      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          20,
        ),
        child: Column(
          children: [

            const SizedBox(
              height: 20,
            ),

            // =================================================
            // LOGO
            // =================================================

            Container(
              width: 120,
              height: 120,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  32,
                ),
                gradient:
                    const LinearGradient(
                  begin:
                      Alignment.topLeft,
                  end: Alignment
                      .bottomRight,
                  colors: [
                    Color(
                      0xFF4016F9,
                    ),
                    Color(
                      0xFF1677FF,
                    ),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 25,
                    spreadRadius: 2,
                    color:
                        Colors.black45,
                  ),
                ],
              ),

              child: const Icon(
                Icons.wifi_rounded,
                size: 68,
                color:
                    Colors.white,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'Wi-Tbry',
              style: TextStyle(
                fontSize: 32,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            const Text(
              'MikroTik Hotspot Manager',
              style: TextStyle(
                fontSize: 15,
                color:
                    Colors.white70,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            // =================================================
            // VERSION
            // =================================================

            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                color:
                    Colors.white10,
              ),
              child: Text(
                'الإصدار $appVersion',
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            // =================================================
            // ABOUT
            // =================================================

            Card(
              elevation: 5,
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                child: Column(
                  children: const [

                    Text(
                      'عن Wi-Tbry',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height: 12,
                    ),

                    Text(
                      'Wi-Tbry هو تطبيق متخصص في إدارة شبكات '
                      'MikroTik Hotspot وتسهيل إنشاء وإدارة '
                      'وطباعة بطاقات الإنترنت من الهاتف عبر '
                      'الشبكة المحلية. تم تطويره لتقديم حلول '
                      'عملية وبسيطة لأصحاب الشبكات ومقدمي '
                      'خدمات الإنترنت.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color:
                            Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // =================================================
            // FEATURES
            // =================================================

            Card(
              elevation: 4,
              child: Column(
                children: const [

                  ListTile(
                    leading: Icon(
                      Icons.add_card,
                      color:
                          Colors.blueAccent,
                    ),
                    title: Text(
                      'إنشاء بطاقات Hotspot',
                    ),
                    subtitle: Text(
                      'إنشاء عدد كبير من بطاقات المستخدمين.',
                    ),
                  ),

                  Divider(
                    height: 1,
                  ),

                  ListTile(
                    leading: Icon(
                      Icons.print,
                      color:
                          Colors.greenAccent,
                    ),
                    title: Text(
                      'طباعة البطاقات',
                    ),
                    subtitle: Text(
                      'تصدير البطاقات بصيغة PDF والطباعة.',
                    ),
                  ),

                  Divider(
                    height: 1,
                  ),

                  ListTile(
                    leading: Icon(
                      Icons.people,
                      color:
                          Colors.orangeAccent,
                    ),
                    title: Text(
                      'المستخدمون المتصلون',
                    ),
                    subtitle: Text(
                      'عرض المستخدمين المتصلين حاليًا.',
                    ),
                  ),

                  Divider(
                    height: 1,
                  ),

                  ListTile(
                    leading: Icon(
                      Icons.search,
                      color:
                          Colors.purpleAccent,
                    ),
                    title: Text(
                      'البحث عن البطاقات',
                    ),
                    subtitle: Text(
                      'البحث عن المستخدمين داخل MikroTik.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // =================================================
            // DEVELOPER
            // =================================================

            Card(
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                child: Column(
                  children: [

                    const CircleAvatar(
                      radius: 35,
                      child: Icon(
                        Icons.person,
                        size: 40,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    const Text(
                      'حمزة الطيب',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    const Text(
                      'مهتم بحلول الشبكات والإنترنت وتطوير '
                      'الأدوات والتطبيقات التي تساعد في إدارة '
                      'الشبكات وتقديم خدمات الإنترنت بسهولة '
                      'وكفاءة.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color:
                            Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // =================================================
            // CONTACT
            // =================================================

            Card(
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  children: [

                    const Text(
                      'تواصل معنا',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          FilledButton
                              .icon(
                        onPressed:
                            openWhatsApp,
                        icon:
                            const Icon(
                          Icons.chat,
                        ),
                        label:
                            const Text(
                          'تواصل عبر واتساب',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          OutlinedButton
                              .icon(
                        onPressed:
                            openContact,
                        icon:
                            const Icon(
                          Icons.contact_page,
                        ),
                        label:
                            const Text(
                          'صفحة التواصل',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // =================================================
            // TERMS & PRIVACY
            // =================================================

            Card(
              child: Column(
                children: [

                  ListTile(
                    leading:
                        const Icon(
                      Icons
                          .description_outlined,
                    ),
                    title:
                        const Text(
                      'شروط الاستخدام',
                    ),
                    trailing:
                        const Icon(
                      Icons
                          .chevron_right,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const TermsPage(),
                        ),
                      );
                    },
                  ),

                  const Divider(
                    height: 1,
                  ),

                  ListTile(
                    leading:
                        const Icon(
                      Icons
                          .privacy_tip_outlined,
                    ),
                    title:
                        const Text(
                      'سياسة الخصوصية',
                    ),
                    trailing:
                        const Icon(
                      Icons
                          .chevron_right,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const PrivacyPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            const Text(
              '© 2026 Wi-Tbry',
              style: TextStyle(
                color:
                    Colors.white54,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            const Text(
              'جميع الحقوق محفوظة',
              style: TextStyle(
                color:
                    Colors.white38,
              ),
            ),

            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TERMS PAGE
// ============================================================

class TermsPage
    extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'شروط الاستخدام',
        ),
        centerTitle: true,
      ),

      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          20,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: const [

            Text(
              'شروط استخدام Wi-Tbry',
              style: TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '1. استخدام التطبيق',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'يُستخدم Wi-Tbry لإدارة أجهزة MikroTik Hotspot '
              'التي يملك المستخدم صلاحية إدارتها أو لديه إذن '
              'صريح لإدارتها.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '2. بيانات الدخول',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'المستخدم مسؤول عن بيانات الدخول إلى جهاز MikroTik '
              'وعن المحافظة على سرية اسم المستخدم وكلمة المرور.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '3. مسؤولية المستخدم',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'يجب استخدام التطبيق بطريقة قانونية وعدم استخدامه '
              'للدخول غير المصرح به إلى أي شبكة أو جهاز.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '4. البطاقات',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'المستخدم مسؤول عن البطاقات التي يتم إنشاؤها من '
              'خلال التطبيق وعن استخدامها وإدارتها.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '5. التحديثات',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'قد يتم تحديث التطبيق وإضافة ميزات جديدة أو تعديل '
              'الميزات الحالية لتحسين الأداء والأمان.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 30,
            ),

            Text(
              'آخر تحديث: 2026',
              style: TextStyle(
                color:
                    Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PRIVACY PAGE
// ============================================================

class PrivacyPage
    extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'سياسة الخصوصية',
        ),
        centerTitle: true,
      ),

      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          20,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: const [

            Text(
              'سياسة الخصوصية',
              style: TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '1. البيانات التي يستخدمها التطبيق',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'يحتاج Wi-Tbry إلى بيانات الاتصال التي يدخلها '
              'المستخدم للوصول إلى جهاز MikroTik، مثل عنوان '
              'الجهاز واسم المستخدم وكلمة المرور.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '2. الاتصال بالشبكة',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'يتصل التطبيق بجهاز MikroTik عبر RouterOS API '
              'لإدارة المستخدمين والبطاقات وعرض المعلومات '
              'المطلوبة من الجهاز.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '3. عدم بيع البيانات',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'لا يبيع التطبيق بيانات المستخدم أو معلومات '
              'الشبكة إلى أطراف أخرى.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '4. بيانات الشبكة',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'معلومات المستخدمين والبطاقات الموجودة على MikroTik '
              'تظل مرتبطة بجهاز الشبكة الذي يديره المستخدم. '
              'يجب على المستخدم حماية جهازه وبيانات الدخول الخاصة به.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              '5. الأمان',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'يُنصح باستخدام API-SSL عندما يكون متاحًا، '
              'واستخدام حساب MikroTik بصلاحيات مناسبة بدلًا '
              'من مشاركة حساب المدير الرئيسي.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            SizedBox(
              height: 30,
            ),

            Text(
              'آخر تحديث: 2026',
              style: TextStyle(
                color:
                    Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}