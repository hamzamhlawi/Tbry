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
        scaffoldBackgroundColor: const Color(0xFF071426),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B35F5),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF101F35),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF6C4CFF),
              width: 1.5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0D1C30),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================
// COLORS
// ============================================================

class AppColors {
  static const Color primary = Color(0xFF6845FF);
  static const Color secondary = Color(0xFF1687FF);
  static const Color background = Color(0xFF071426);
  static const Color card = Color(0xFF0D1C30);
  static const Color card2 = Color(0xFF12243B);
  static const Color green = Color(0xFF31D48C);
  static const Color orange = Color(0xFFFFB547);
  static const Color red = Color(0xFFFF5C70);
  static const Color textMuted = Color(0xFF91A2B8);
}

// ============================================================
// HOTSPOT CARD MODEL
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
    _checkConnection();

    return await client!.talk(
      '/ip/hotspot/user/profile/print',
    );
  }

  Future<List<Map<String, String>>> getUsers() async {
    _checkConnection();

    return await client!.talk(
      '/ip/hotspot/user/print',
    );
  }

  Future<List<Map<String, String>>> getActiveUsers() async {
    _checkConnection();

    return await client!.talk(
      '/ip/hotspot/active/print',
    );
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String profile,
  }) async {
    _checkConnection();

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
    _checkConnection();

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

  void _checkConnection() {
    if (!connected || client == null) {
      throw Exception('MikroTik غير متصل');
    }
  }
}

// ============================================================
// CARD GENERATOR
// ============================================================

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
    const int cardsPerPage = columns * rows;

    for (
      int start = 0;
      start < cards.length;
      start += cardsPerPage
    ) {
      final int end = min(
        start + cardsPerPage,
        cards.length,
      );

      final pageCards = cards.sublist(
        start,
        end,
      );

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
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
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
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
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'HOTSPOT INTERNET',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
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
          pw.SizedBox(height: 3),
          pw.Text(
            'Profile: ${card.profile}',
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

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MikroTikService mikrotik =
      MikroTikService();

  final TextEditingController hostController =
      TextEditingController(
    text: '10.10.10.1',
  );

  final TextEditingController userController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController portController =
      TextEditingController(
    text: '8729',
  );

  final TextEditingController countController =
      TextEditingController(
    text: '10',
  );

  bool ssl = true;
  bool loading = false;

  String status = 'غير متصل';

  List<String> profiles = [];
  String selectedProfile = '';

  List<HotspotCard> generatedCards = [];

  List<Map<String, String>> activeUsers = [];

  List<Map<String, String>> allUsers = [];

  int currentPage = 0;

  int generationCurrent = 0;
  int generationTotal = 0;

  bool get connected => mikrotik.connected;

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
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      loading = true;
      status = 'جاري الاتصال...';
    });

    try {
      await mikrotik.connect(
        host: hostController.text.trim(),
        username: userController.text.trim(),
        password: passwordController.text,
        port: int.tryParse(
              portController.text,
            ) ??
            8729,
        ssl: ssl,
      );

      await refreshData();

      if (!mounted) return;

      setState(() {
        status = 'متصل';
      });

      showSuccess(
        'تم الاتصال بجهاز MikroTik بنجاح',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        status = 'خطأ في الاتصال';
      });

      showError(
        cleanError(e),
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
  // DISCONNECT
  // ==========================================================

  Future<void> disconnect() async {
    await mikrotik.disconnect();

    if (!mounted) return;

    setState(() {
      status = 'غير متصل';
      profiles.clear();
      activeUsers.clear();
      allUsers.clear();
      selectedProfile = '';
    });

    showSuccess('تم قطع الاتصال');
  }

  // ==========================================================
  // REFRESH
  // ==========================================================

  Future<void> refreshData() async {
    if (!connected) return;

    try {
      final profileResult =
          await mikrotik.getProfiles();

      final userResult =
          await mikrotik.getUsers();

      final activeResult =
          await mikrotik.getActiveUsers();

      final names = profileResult
          .map((e) => e['name'])
          .whereType<String>()
          .toList();

      if (!mounted) return;

      setState(() {
        profiles = names;
        allUsers = userResult;
        activeUsers = activeResult;

        if (profiles.isNotEmpty &&
            !profiles.contains(selectedProfile)) {
          selectedProfile = profiles.first;
        }
      });
    } catch (_) {}
  }

  // ==========================================================
  // GENERATE CARDS
  // ==========================================================

  Future<void> generateCards() async {
    if (!connected) {
      showError('اتصل بالـ MikroTik أولًا');
      return;
    }

    final int? count = int.tryParse(
      countController.text.trim(),
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
      showError('اختر البروفايل أولًا');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      loading = true;
      generatedCards.clear();
      generationCurrent = 0;
      generationTotal = count;
    });

    try {
      final List<HotspotCard> cards = [];

      final existingNames = allUsers
          .map((e) => e['name'])
          .whereType<String>()
          .toSet();

      for (int i = 0; i < count; i++) {
        String username;

        do {
          username = CardGenerator.username();
        } while (existingNames.contains(username));

        existingNames.add(username);

        final password =
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
            profile: selectedProfile,
          ),
        );

        if (!mounted) return;

        setState(() {
          generationCurrent = i + 1;
        });
      }

      if (!mounted) return;

      setState(() {
        generatedCards = cards;
        loading = false;
      });

      showSuccess(
        'تم إنشاء ${cards.length} كرت بنجاح',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showError(
        cleanError(e),
      );
    }
  }

  // ==========================================================
  // PRINT
  // ==========================================================

  Future<void> printCards() async {
    if (generatedCards.isEmpty) {
      showError('لا توجد كروت للطباعة');
      return;
    }

    try {
      final Uint8List pdf =
          await PdfGenerator.createCardsPdf(
        generatedCards,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name: 'Wi-Tbry-Cards.pdf',
      );
    } catch (e) {
      showError(
        'فشل إنشاء PDF: ${cleanError(e)}',
      );
    }
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  Future<void> searchUser() async {
    if (!connected) {
      showError('اتصل بالـ MikroTik أولًا');
      return;
    }

    final String? name =
        await showDialog<String>(
      context: context,
      builder: (context) {
        final controller =
            TextEditingController();

        return AlertDialog(
          title: const Text('البحث عن كرت'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'اسم المستخدم',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
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
      final users =
          await mikrotik.getUsers();

      final found = users.where(
        (u) =>
            (u['name'] ?? '')
                .toLowerCase() ==
            name.toLowerCase(),
      );

      if (found.isEmpty) {
        showError('الكرت غير موجود');
        return;
      }

      final user = found.first;

      if (!mounted) return;

      showCardDetails(user);
    } catch (e) {
      showError(cleanError(e));
    }
  }

  // ==========================================================
  // SHOW CARD DETAILS
  // ==========================================================

  void showCardDetails(
    Map<String, String> user,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        final name = user['name'] ?? '-';
        final profile = user['profile'] ?? '-';
        final disabled = user['disabled'] ?? 'false';

        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withOpacity(.15),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.confirmation_num,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text('بيانات الكرت'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              infoRow(
                'Username',
                name,
                Icons.person,
              ),
              infoRow(
                'Profile',
                profile,
                Icons.speed,
              ),
              infoRow(
                'الحالة',
                disabled == 'true'
                    ? 'معطل'
                    : 'فعال',
                disabled == 'true'
                    ? Icons.block
                    : Icons.check_circle,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Widget infoRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ACTIVE USERS
  // ==========================================================

  Future<void> loadActiveUsers() async {
    if (!connected) {
      showError('اتصل بالـ MikroTik أولًا');
      return;
    }

    try {
      final result =
          await mikrotik.getActiveUsers();

      if (!mounted) return;

      setState(() {
        activeUsers = result;
      });

      showActiveUsers();
    } catch (e) {
      showError(cleanError(e));
    }
  }

  void showActiveUsers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height * .82,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'المتصلون حاليًا',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green
                              .withOpacity(.12),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${activeUsers.length}',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Expanded(
                  child: activeUsers.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 60,
                                color:
                                    AppColors.textMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'لا يوجد مستخدمون متصلون',
                                style: TextStyle(
                                  color:
                                      AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.all(16),
                          itemCount:
                              activeUsers.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(
                            height: 8,
                          ),
                          itemBuilder:
                              (_, index) {
                            final u =
                                activeUsers[index];

                            final username =
                                u['user'] ??
                                    u['name'] ??
                                    'Unknown';

                            final address =
                                u['address'] ?? '-';

                            return Container(
                              padding:
                                  const EdgeInsets.all(
                                14,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    AppColors.card,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  18,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration:
                                        BoxDecoration(
                                      color: AppColors
                                          .green
                                          .withOpacity(
                                        .12,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        14,
                                      ),
                                    ),
                                    child:
                                        const Icon(
                                      Icons.person,
                                      color:
                                          AppColors.green,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          username,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 4),
                                        Text(
                                          'IP: $address',
                                          style:
                                              const TextStyle(
                                            color: AppColors
                                                .textMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.circle,
                                    size: 10,
                                    color:
                                        AppColors.green,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // GENERATED CARDS
  // ==========================================================

  void clearGeneratedCards() {
    if (generatedCards.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مسح الكروت'),
        content: const Text(
          'هل تريد مسح قائمة الكروت من التطبيق؟\n'
          'هذا لا يحذف المستخدمين من MikroTik.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                generatedCards.clear();
              });

              Navigator.pop(context);
            },
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  String cleanError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring(11);
    }

    return text;
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
      ),
    );
  }

  void showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: currentPage,
          children: [
            dashboardPage(),
            cardsPage(),
            usersPage(),
            settingsPage(),
          ],
        ),
      ),
      bottomNavigationBar:
          NavigationBar(
        selectedIndex: currentPage,
        onDestinationSelected: (index) {
          setState(() {
            currentPage = index;
          });
        },
        backgroundColor:
            const Color(0xFF0B1A2E),
        indicatorColor:
            AppColors.primary.withOpacity(.22),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon:
                Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_num_outlined),
            selectedIcon:
                Icon(Icons.confirmation_num),
            label: 'الكروت',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon:
                Icon(Icons.people),
            label: 'المتصلون',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon:
                Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DASHBOARD
  // ==========================================================

  Widget dashboardPage() {
    return RefreshIndicator(
      onRefresh: refreshData,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          18,
          14,
          18,
          25,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            header(),

            const SizedBox(height: 22),

            connectionBanner(),

            const SizedBox(height: 18),

            statsGrid(),

            const SizedBox(height: 22),

            sectionTitle(
              'إصدار كروت الإنترنت',
              'إنشاء بطاقات جديدة',
              Icons.add_card,
            ),

            const SizedBox(height: 12),

            generatorPanel(),

            const SizedBox(height: 22),

            sectionTitle(
              'الوصول السريع',
              'أدوات الشبكة',
              Icons.flash_on,
            ),

            const SizedBox(height: 12),

            quickActions(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget header() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
                BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.primary.withOpacity(.3),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(
            Icons.wifi_rounded,
            size: 29,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Wi-Tbry',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'MikroTik Hotspot Manager',
                style: TextStyle(
                  color:
                      AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'تحديث',
          onPressed:
              connected ? refreshData : null,
          icon:
              const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  // ==========================================================
  // CONNECTION BANNER
  // ==========================================================

  Widget connectionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connected
              ? [
                  const Color(0xFF103B35),
                  const Color(0xFF0D2A2D),
                ]
              : [
                  const Color(0xFF2A1D27),
                  const Color(0xFF171A28),
                ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: connected
              ? AppColors.green.withOpacity(.22)
              : AppColors.red.withOpacity(.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.green.withOpacity(.12)
                  : AppColors.red.withOpacity(.12),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Icon(
              connected
                  ? Icons.cloud_done
                  : Icons.cloud_off,
              color: connected
                  ? AppColors.green
                  : AppColors.red,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  connected
                      ? 'متصل بجهاز MikroTik'
                      : 'MikroTik غير متصل',
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected
                      ? hostController.text
                      : 'قم بإعداد الاتصال من الإعدادات',
                  style: const TextStyle(
                    color:
                        AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!connected)
            FilledButton(
              onPressed:
                  loading ? null : connect,
              child: const Text('اتصال'),
            )
          else
            IconButton(
              tooltip: 'قطع الاتصال',
              onPressed: disconnect,
              icon:
                  const Icon(Icons.logout),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATS
  // ==========================================================

  Widget statsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        statCard(
          title: 'الكروت المنشأة',
          value: '${allUsers.length}',
          icon: Icons.confirmation_num,
          color: AppColors.primary,
        ),
        statCard(
          title: 'المتصلون الآن',
          value: '${activeUsers.length}',
          icon: Icons.people,
          color: AppColors.green,
        ),
        statCard(
          title: 'البروفايلات',
          value: '${profiles.length}',
          icon: Icons.speed,
          color: AppColors.orange,
        ),
        statCard(
          title: 'جاهز للطباعة',
          value:
              '${generatedCards.length}',
          icon: Icons.print,
          color: AppColors.secondary,
        ),
      ],
    );
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(.04),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color:
                  AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SECTION TITLE
  // ==========================================================

  Widget sectionTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color:
                AppColors.primary.withOpacity(.12),
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color:
                    AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================
  // GENERATOR PANEL
  // ==========================================================

  Widget generatorPanel() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(.04),
        ),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedProfile.isEmpty
                ? null
                : selectedProfile,
            decoration:
                const InputDecoration(
              labelText:
                  'Hotspot Profile',
              prefixIcon:
                  Icon(Icons.speed),
            ),
            items: profiles.map(
              (profile) {
                return DropdownMenuItem<String>(
                  value: profile,
                  child: Text(profile),
                );
              },
            ).toList(),
            onChanged: connected
                ? (value) {
                    if (value == null) return;

                    setState(() {
                      selectedProfile =
                          value;
                    });
                  }
                : null,
            hint: Text(
              connected
                  ? 'اختر السرعة'
                  : 'اتصل أولًا',
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller:
                countController,
            keyboardType:
                TextInputType.number,
            decoration:
                const InputDecoration(
              labelText: 'عدد الكروت',
              hintText: 'من 1 إلى 5000',
              prefixIcon:
                  Icon(Icons.numbers),
            ),
          ),

          const SizedBox(height: 14),

          if (loading &&
              generationTotal > 0)
            Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'جاري إنشاء الكروت',
                        style: TextStyle(
                          color:
                              AppColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      '$generationCurrent / $generationTotal',
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: generationTotal == 0
                      ? 0
                      : generationCurrent /
                          generationTotal,
                  minHeight: 7,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                const SizedBox(height: 12),
              ],
            ),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed:
                  loading ? null : generateCards,
              icon: const Icon(
                Icons.add_card,
              ),
              label: Text(
                loading
                    ? 'جاري الإنشاء...'
                    : 'إنشاء الكروت',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // QUICK ACTIONS
  // ==========================================================

  Widget quickActions() {
    return Row(
      children: [
        Expanded(
          child: quickAction(
            title: 'المتصلون',
            icon: Icons.people,
            color: AppColors.green,
            onTap: connected
                ? loadActiveUsers
                : () {
                    showError(
                      'اتصل بالـ MikroTik أولًا',
                    );
                  },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: quickAction(
            title: 'بحث عن كرت',
            icon: Icons.search,
            color: AppColors.secondary,
            onTap: connected
                ? searchUser
                : () {
                    showError(
                      'اتصل بالـ MikroTik أولًا',
                    );
                  },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: quickAction(
            title: 'الطباعة',
            icon: Icons.print,
            color: AppColors.orange,
            onTap: () {
              setState(() {
                currentPage = 1;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget quickAction({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          vertical: 17,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 25,
            ),
            const SizedBox(height: 9),
            Text(
              title,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // CARDS PAGE
  // ==========================================================

  Widget cardsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        25,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          pageHeader(
            'الكروت',
            'إدارة وطباعة البطاقات',
            Icons.confirmation_num,
          ),

          const SizedBox(height: 20),

          if (generatedCards.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الكروت الجاهزة',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'هذه الكروت تم إنشاؤها ويمكن طباعتها',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${generatedCards.length}',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight:
                          FontWeight.w900,
                      color:
                          AppColors.green,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          if (generatedCards.isEmpty)
            emptyState(
              icon: Icons.confirmation_num_outlined,
              title: 'لا توجد كروت جاهزة',
              subtitle:
                  'قم بإنشاء الكروت من الصفحة الرئيسية',
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        printCards,
                    icon:
                        const Icon(Icons.print),
                    label:
                        const Text('طباعة PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed:
                      clearGeneratedCards,
                  child:
                      const Text('مسح'),
                ),
              ],
            ),

            const SizedBox(height: 14),

            ListView.separated(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount:
                  generatedCards.length,
              separatorBuilder:
                  (_, __) =>
                      const SizedBox(height: 8),
              itemBuilder:
                  (_, index) {
                final card =
                    generatedCards[index];

                return Container(
                  padding:
                      const EdgeInsets.all(14),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.card,
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        alignment:
                            Alignment.center,
                        decoration:
                            BoxDecoration(
                          gradient:
                              const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.secondary,
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: Text(
                          '${index + 1}',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.username,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              'Password: ${card.password}',
                              style:
                                  const TextStyle(
                                color:
                                    AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Profile: ${card.profile}',
                              style:
                                  const TextStyle(
                                color:
                                    AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // USERS PAGE
  // ==========================================================

  Widget usersPage() {
    return RefreshIndicator(
      onRefresh: () async {
        if (connected) {
          try {
            final result =
                await mikrotik
                    .getActiveUsers();

            if (!mounted) return;

            setState(() {
              activeUsers = result;
            });
          } catch (e) {
            showError(cleanError(e));
          }
        }
      },
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          18,
          14,
          18,
          25,
        ),
        child: Column(
          children: [
            pageHeader(
              'المتصلون',
              'مستخدمو Hotspot المتصلون حاليًا',
              Icons.people,
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFF103B35),
                    Color(0xFF0C2630),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.people_alt,
                    size: 42,
                    color:
                        AppColors.green,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${activeUsers.length}',
                    style:
                        const TextStyle(
                      fontSize: 36,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'مستخدم متصل',
                    style:
                        TextStyle(
                      color:
                          AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child:
                        FilledButton.icon(
                      onPressed:
                          connected
                              ? loadActiveUsers
                              : null,
                      icon:
                          const Icon(
                        Icons.refresh,
                      ),
                      label:
                          const Text(
                        'تحديث المتصلين',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            if (!connected)
              emptyState(
                icon: Icons.cloud_off,
                title: 'غير متصل',
                subtitle:
                    'اتصل بجهاز MikroTik لعرض المستخدمين',
              )
            else if (activeUsers.isEmpty)
              emptyState(
                icon:
                    Icons.people_outline,
                title:
                    'لا يوجد متصلون',
                subtitle:
                    'لا توجد جلسات Hotspot نشطة حاليًا',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount:
                    activeUsers.length,
                separatorBuilder:
                    (_, __) =>
                        const SizedBox(height: 8),
                itemBuilder:
                    (_, index) {
                  final u =
                      activeUsers[index];

                  return Container(
                    padding:
                        const EdgeInsets.all(14),
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.card,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.green
                                  .withOpacity(
                            .12,
                          ),
                          child:
                              const Icon(
                            Icons.person,
                            color:
                                AppColors.green,
                          ),
                        ),
                        const SizedBox(
                            width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                u['user'] ??
                                    u['name'] ??
                                    'Unknown',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                  height: 4),
                              Text(
                                'IP: ${u['address'] ?? '-'}',
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.circle,
                          size: 9,
                          color:
                              AppColors.green,
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // SETTINGS PAGE
  // ==========================================================

  Widget settingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        25,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          pageHeader(
            'الإعدادات',
            'إعداد اتصال MikroTik والتطبيق',
            Icons.settings,
          ),

          const SizedBox(height: 20),

          settingsConnectionCard(),

          const SizedBox(height: 15),

          settingsOption(
            icon: Icons.search,
            title: 'البحث عن كرت',
            subtitle:
                'البحث داخل مستخدمي MikroTik',
            onTap:
                connected ? searchUser : null,
          ),

          const SizedBox(height: 10),

          settingsOption(
            icon: Icons.people,
            title: 'المستخدمون المتصلون',
            subtitle:
                'عرض الجلسات النشطة',
            onTap: connected
                ? loadActiveUsers
                : null,
          ),

          const SizedBox(height: 10),

          settingsOption(
            icon: Icons.info_outline,
            title: 'عن Wi-Tbry',
            subtitle:
                'معلومات التطبيق والمطور',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AboutPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          settingsOption(
            icon:
                Icons.description_outlined,
            title: 'شروط الاستخدام',
            subtitle:
                'شروط استخدام التطبيق',
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

          const SizedBox(height: 10),

          settingsOption(
            icon:
                Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            subtitle:
                'سياسة الخصوصية',
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
    );
  }

  // ==========================================================
  // SETTINGS CONNECTION CARD
  // ==========================================================

  Widget settingsConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withOpacity(.12),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.router,
                  color:
                      AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'اتصال MikroTik',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  Text(
                    'RouterOS API',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          TextField(
            controller:
                hostController,
            decoration:
                const InputDecoration(
              labelText: 'IP / Host',
              prefixIcon:
                  Icon(Icons.language),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller:
                userController,
            decoration:
                const InputDecoration(
              labelText: 'Username',
              prefixIcon:
                  Icon(Icons.person),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller:
                passwordController,
            obscureText: true,
            decoration:
                const InputDecoration(
              labelText: 'Password',
              prefixIcon:
                  Icon(Icons.lock),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      portController,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      const InputDecoration(
                    labelText: 'API Port',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card2,
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('SSL'),
                    Switch(
                      value: ssl,
                      onChanged: (value) {
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
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.green
                      .withOpacity(.08)
                  : AppColors.red
                      .withOpacity(.08),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  connected
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 20,
                  color: connected
                      ? AppColors.green
                      : AppColors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connected
                        ? 'متصل: ${hostController.text}'
                        : 'الحالة: $status',
                    style: TextStyle(
                      color: connected
                          ? AppColors.green
                          : AppColors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed:
                        loading
                            ? null
                            : connect,
                    icon:
                        const Icon(Icons.link),
                    label:
                        const Text('اتصال'),
                  ),
                ),
              ),
              if (connected) ...[
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child:
                      OutlinedButton.icon(
                    onPressed: disconnect,
                    icon:
                        const Icon(Icons.logout),
                    label:
                        const Text('قطع'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SETTINGS OPTION
  // ==========================================================

  Widget settingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.card,
      borderRadius:
          BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withOpacity(.1),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color:
                      AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color:
                    AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // PAGE HEADER
  // ==========================================================

  Widget pageHeader(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.secondary,
              ],
            ),
            borderRadius:
                BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 13),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color:
                    AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================
  // EMPTY STATE
  // ==========================================================

  Widget emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 45,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 58,
            color:
                AppColors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              color:
                  AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
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

  Future<void> loadAppVersion() async {
    try {
      final info =
          await PackageInfo.fromPlatform();

      if (!mounted) return;

      setState(() {
        appVersion =
            '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        appVersion = 'غير معروف';
      });
    }
  }

  Future<void> openWhatsApp() async {
    final Uri url = Uri.parse(
      'https://wa.me/$whatsappNumber',
    );

    try {
      final launched =
          await launchUrl(
        url,
        mode:
            LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        showError('تعذر فتح واتساب');
      }
    } catch (_) {
      if (mounted) {
        showError('تعذر فتح واتساب');
      }
    }
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor: AppColors.red,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('عن التطبيق'),
        centerTitle: true,
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 15),

            // LOGO
            Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                  begin:
                      Alignment.topLeft,
                  end:
                      Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary
                        .withOpacity(.28),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.wifi_rounded,
                size: 70,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Wi-Tbry',
              style: TextStyle(
                fontSize: 34,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'MikroTik Hotspot Manager',
              style: TextStyle(
                color:
                    AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                'الإصدار $appVersion',
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                ),
              ),
            ),

            const SizedBox(height: 25),

            aboutCard(),

            const SizedBox(height: 15),

            featuresCard(),

            const SizedBox(height: 15),

            developerCard(),

            const SizedBox(height: 15),

            contactCard(),

            const SizedBox(height: 15),

            legalCard(),

            const SizedBox(height: 25),

            const Text(
              '© 2026 Wi-Tbry',
              style: TextStyle(
                color:
                    Colors.white54,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'جميع الحقوق محفوظة',
              style: TextStyle(
                color:
                    Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget aboutCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
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
            SizedBox(height: 12),
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
                fontSize: 15,
                height: 1.7,
                color:
                    Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget featuresCard() {
    return Card(
      child: Column(
        children: const [
          ListTile(
            leading: Icon(
              Icons.add_card,
              color:
                  AppColors.primary,
            ),
            title:
                Text('إنشاء بطاقات Hotspot'),
            subtitle: Text(
              'إنشاء عدد كبير من بطاقات المستخدمين.',
            ),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.print,
              color:
                  AppColors.green,
            ),
            title:
                Text('طباعة البطاقات'),
            subtitle: Text(
              'تصدير البطاقات بصيغة PDF والطباعة.',
            ),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.people,
              color:
                  AppColors.orange,
            ),
            title:
                Text('المستخدمون المتصلون'),
            subtitle: Text(
              'عرض المستخدمين المتصلين حاليًا.',
            ),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.search,
              color:
                  Colors.purpleAccent,
            ),
            title:
                Text('البحث عن البطاقات'),
            subtitle: Text(
              'البحث عن المستخدمين داخل MikroTik.',
            ),
          ),
        ],
      ),
    );
  }

  Widget developerCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 35,
              child: Icon(
                Icons.person,
                size: 40,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              developerName,
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'مهتم بحلول الشبكات والإنترنت وتطوير '
              'الأدوات والتطبيقات التي تساعد في إدارة '
              'الشبكات وتقديم خدمات الإنترنت بسهولة '
              'وكفاءة.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color:
                    Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget contactCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
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
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 52,
              child:
                  FilledButton.icon(
                onPressed:
                    openWhatsApp,
                icon:
                    const Icon(Icons.chat),
                label:
                    const Text(
                  'تواصل عبر واتساب',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget legalCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading:
                const Icon(
              Icons.description_outlined,
            ),
            title:
                const Text(
              'شروط الاستخدام',
            ),
            trailing:
                const Icon(
              Icons.chevron_right,
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
          const Divider(height: 1),
          ListTile(
            leading:
                const Icon(
              Icons.privacy_tip_outlined,
            ),
            title:
                const Text(
              'سياسة الخصوصية',
            ),
            trailing:
                const Icon(
              Icons.chevron_right,
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
    );
  }
}

// ============================================================
// TERMS
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
            const Text('شروط الاستخدام'),
        centerTitle: true,
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: const [
            Text(
              'شروط استخدام Wi-Tbry',
              style: TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '1. استخدام التطبيق',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'يُستخدم Wi-Tbry لإدارة أجهزة MikroTik Hotspot '
              'التي يملك المستخدم صلاحية إدارتها أو لديه إذن '
              'صريح لإدارتها.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '2. بيانات الدخول',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'المستخدم مسؤول عن بيانات الدخول إلى جهاز MikroTik '
              'وعن المحافظة على سرية اسم المستخدم وكلمة المرور.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '3. مسؤولية المستخدم',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'يجب استخدام التطبيق بطريقة قانونية وعدم استخدامه '
              'للدخول غير المصرح به إلى أي شبكة أو جهاز.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '4. البطاقات',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'المستخدم مسؤول عن البطاقات التي يتم إنشاؤها من '
              'خلال التطبيق وعن استخدامها وإدارتها.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '5. التحديثات',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'قد يتم تحديث التطبيق وإضافة ميزات جديدة أو تعديل '
              'الميزات الحالية لتحسين الأداء والأمان.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 30),
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
// PRIVACY
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
            const Text('سياسة الخصوصية'),
        centerTitle: true,
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: const [
            Text(
              'سياسة الخصوصية',
              style: TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '1. البيانات التي يستخدمها التطبيق',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'يحتاج Wi-Tbry إلى بيانات الاتصال التي يدخلها '
              'المستخدم للوصول إلى جهاز MikroTik، مثل عنوان '
              'الجهاز واسم المستخدم وكلمة المرور.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '2. الاتصال بالشبكة',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'يتصل التطبيق بجهاز MikroTik عبر RouterOS API '
              'لإدارة المستخدمين والبطاقات وعرض المعلومات '
              'المطلوبة من الجهاز.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '3. عدم بيع البيانات',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'لا يبيع التطبيق بيانات المستخدم أو معلومات '
              'الشبكة إلى أطراف أخرى.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '4. بيانات الشبكة',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'معلومات المستخدمين والبطاقات الموجودة على MikroTik '
              'تظل مرتبطة بجهاز الشبكة الذي يديره المستخدم. '
              'يجب على المستخدم حماية جهازه وبيانات الدخول الخاصة به.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '5. الأمان',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'يُنصح باستخدام API-SSL عندما يكون متاحًا، '
              'واستخدام حساب MikroTik بصلاحيات مناسبة بدلًا '
              'من مشاركة حساب المدير الرئيسي.',
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
            SizedBox(height: 30),
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