import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/services/notification_service.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/splash/screens/splash_screen.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();

  runApp(const MotoShieldApp());
}

class MotoShieldApp extends StatefulWidget {
  final bool? startAsAdmin;
  const MotoShieldApp({super.key, this.startAsAdmin});

  @override
  State<MotoShieldApp> createState() => _MotoShieldAppState();
}

class _MotoShieldAppState extends State<MotoShieldApp> {
  late bool _isAdminMode;

  @override
  void initState() {
    super.initState();
    if (widget.startAsAdmin != null) {
      _isAdminMode = widget.startAsAdmin!;
    } else if (kIsWeb) {
      final uri = Uri.base;
      final mode = uri.queryParameters['mode']?.toLowerCase();
      final page = uri.queryParameters['page']?.toLowerCase();
      final path = uri.path.toLowerCase();
      final fragment = uri.fragment.toLowerCase();

      // If user specifies rider / login via URL parameter or hash
      if (mode == 'rider' ||
          mode == 'login' ||
          page == 'login' ||
          page == 'rider' ||
          path.contains('login') ||
          path.contains('rider') ||
          fragment.contains('login') ||
          fragment.contains('rider')) {
        _isAdminMode = false;
      } else {
        // Default on Web root without query params: Admin Dashboard
        _isAdminMode = true;
      }
    } else {
      _isAdminMode = false;
    }
  }

  void _toggleMode() {
    setState(() {
      _isAdminMode = !_isAdminMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoShield',
      debugShowCheckedModeBanner: false,

      themeMode: ThemeMode.system,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        colorSchemeSeed: const Color(0xFFFF5E3A),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141518),
        colorSchemeSeed: const Color(0xFFFF5E3A),
      ),

      onGenerateRoute: (settings) {
        final name = settings.name?.toLowerCase() ?? '';
        if (name == '/login' || name.contains('login')) {
          return MaterialPageRoute(
            builder: (_) => LoginScreen(
              onSwitchToAdmin: _toggleMode,
            ),
          );
        }
        if (name == '/rider' || name.contains('rider')) {
          return MaterialPageRoute(
            builder: (_) => LoginScreen(
              onSwitchToAdmin: _toggleMode,
            ),
          );
        }
        if (name == '/admin' || name.contains('admin')) {
          return MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(
              onSwitchToRiderApp: _toggleMode,
            ),
          );
        }
        return null;
      },

      home: _isAdminMode
          ? AdminDashboardScreen(
              onSwitchToRiderApp: _toggleMode,
            )
          : (kIsWeb
              ? LoginScreen(onSwitchToAdmin: _toggleMode)
              : const SplashScreen()),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0B0B),

      appBar: AppBar(title: const Text("MotoShield"), centerTitle: true),

      body: const Center(
        child: Text(
          "Firebase Connected Successfully",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
