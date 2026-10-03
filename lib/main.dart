import 'package:flutter/material.dart';

void main() {
  runApp(const AlTabriApp());
}

class AlTabriApp extends StatelessWidget {
  const AlTabriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'التبري Server',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'sans',
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA6),
          brightness: Brightness.dark,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    DashboardHome(),
    MikrotikPage(),
    CardsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'التبري Server',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          backgroundColor: const Color(0xFF161B22),
        ),
        body: pages[currentIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.router_outlined),
              selectedIcon: Icon(Icons.router),
              label: 'MikroTik',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number),
              label: 'الكروت',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================
// الصفحة الرئيسية
// ===========================

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'لوحة التحكم',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'إدارة MikroTik والـ Hotspot من مكان واحد',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: StatusCard(
                  title: 'السيرفرات',
                  value: '0',
                  icon: Icons.router,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatusCard(
                  title: 'المتصلة',
                  value: '0',
                  icon: Icons.wifi,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: StatusCard(
                  title: 'الكروت',
                  value: '0',
                  icon: Icons.confirmation_number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatusCard(
                  title: 'المستخدمون',
                  value: '0',
                  icon: Icons.people,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Text(
            'اختصارات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ActionButton(
            icon: Icons.add_box,
            title: 'إضافة MikroTik',
            subtitle: 'إضافة جهاز جديد إلى التبري',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddMikrotikPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          ActionButton(
            icon: Icons.confirmation_number,
            title: 'إنشاء كروت',
            subtitle: 'إنشاء بطاقات Hotspot جديدة',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GenerateCardsPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          ActionButton(
            icon: Icons.print,
            title: 'طباعة الكروت',
            subtitle: 'طباعة البطاقات التي تم إنشاؤها',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('سيتم إضافة الطباعة الفعلية في الخطوة القادمة'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ===========================
// MikroTik
// ===========================

class MikrotikPage extends StatelessWidget {
  const MikrotikPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'MikroTik',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF30363D),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.router,
                size: 60,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 12),
              const Text(
                'لا توجد أجهزة MikroTik',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'أضف جهاز MikroTik متصل بنفس الشبكة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddMikrotikPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('إضافة جهاز'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================
// إضافة MikroTik
// ===========================

class AddMikrotikPage extends StatefulWidget {
  const AddMikrotikPage({super.key});

  @override
  State<AddMikrotikPage> createState() => _AddMikrotikPageState();
}

class _AddMikrotikPageState extends State<AddMikrotikPage> {
  final nameController = TextEditingController();
  final ipController = TextEditingController(text: '10.10.10.1');
  final usernameController = TextEditingController(text: 'admin');
  final passwordController = TextEditingController();

  bool obscurePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    ipController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void saveRouter() {
    if (nameController.text.trim().isEmpty ||
        ipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل اسم الجهاز وعنوان IP'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ بيانات MikroTik — سنضيف الاتصال الحقيقي لاحقًا'),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة MikroTik'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'بيانات الجهاز',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الجهاز',
                hintText: 'مثال: سيرفر القرية',
                prefixIcon: Icon(Icons.router),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: ipController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'عنوان IP',
                hintText: 'مثال: 10.10.10.1',
                prefixIcon: Icon(Icons.lan),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: saveRouter,
              icon: const Icon(Icons.save),
              label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'حفظ الجهاز',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================
// الكروت
// ===========================

class CardsPage extends StatelessWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'كروت Hotspot',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        ActionButton(
          icon: Icons.add_circle,
          title: 'إنشاء كروت جديدة',
          subtitle: 'تحديد العدد والمدة والسرعة',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GenerateCardsPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        ActionButton(
          icon: Icons.print,
          title: 'طباعة الكروت',
          subtitle: 'طباعة الكروت التي تم إنشاؤها',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الطباعة ستتم إضافتها بعد ربط MikroTik'),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ===========================
// إنشاء الكروت
// ===========================

class GenerateCardsPage extends StatefulWidget {
  const GenerateCardsPage({super.key});

  @override
  State<GenerateCardsPage> createState() => _GenerateCardsPageState();
}

class _GenerateCardsPageState extends State<GenerateCardsPage> {
  int quantity = 10;
  String duration = '1 يوم';
  String speed = '5 Mbps';

  void generate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تجهيز $quantity كرت — سيتم ربطها بـ MikroTik لاحقًا'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إنشاء الكروت'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'إعداد الكروت',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'عدد الكروت',
              style: TextStyle(fontSize: 17),
            ),

            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      if (quantity > 1) {
                        setState(() {
                          quantity--;
                        });
                      }
                    },
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    '$quantity',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        quantity++;
                      });
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: duration,
              decoration: const InputDecoration(
                labelText: 'مدة الكرت',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: '1 ساعة',
                  child: Text('1 ساعة'),
                ),
                DropdownMenuItem(
                  value: '6 ساعات',
                  child: Text('6 ساعات'),
                ),
                DropdownMenuItem(
                  value: '1 يوم',
                  child: Text('1 يوم'),
                ),
                DropdownMenuItem(
                  value: '7 أيام',
                  child: Text('7 أيام'),
                ),
                DropdownMenuItem(
                  value: '30 يوم',
                  child: Text('30 يوم'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    duration = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: speed,
              decoration: const InputDecoration(
                labelText: 'السرعة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: '1 Mbps',
                  child: Text('1 Mbps'),
                ),
                DropdownMenuItem(
                  value: '2 Mbps',
                  child: Text('2 Mbps'),
                ),
                DropdownMenuItem(
                  value: '5 Mbps',
                  child: Text('5 Mbps'),
                ),
                DropdownMenuItem(
                  value: '10 Mbps',
                  child: Text('10 Mbps'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    speed = value;
                  });
                }
              },
            ),

            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'إنشاء الكروت',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================
// الإعدادات
// ===========================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'الإعدادات',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Card(
          child: ListTile(
            leading: const Icon(Icons.language),
            title: const Text('اللغة'),
            subtitle: const Text('العربية'),
            onTap: () {},
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('عن التبري'),
            subtitle: const Text('التبري Server'),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

// ===========================
// Widgets
// ===========================

class StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatusCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF30363D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 28,
            color: const Color(0xFF00BFA6),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161B22),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF00BFA6).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF00BFA6),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}