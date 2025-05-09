import 'package:flutter/material.dart';
import 'package:renfrew_bridge_app/views/bridge_status_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Renfrew Bridge Status',
      color: Color(0xFF086E8F),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      // ← show the splash first
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctr;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _ctr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeOut = CurvedAnimation(parent: _ctr, curve: Curves.easeOut);

    // wait a bit, then *simultaneously* fade out splash & fade in the real page
    Future.delayed(const Duration(milliseconds: 800), () {
      _ctr.forward();  // splash begins fading out...
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          opaque: false,                    // <-- let splash show through
          transitionDuration: _ctr.duration!, // must match your controller
          pageBuilder: (_, __, ___) => const BridgeStatusPage(),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: ReverseAnimation(_fadeOut),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Color(0xFF086E8F),
              Color(0xFF086E8F),
              Color(0xFF2FA9BA),
              Color(0xFF2FA9BA),
            ],
          ),
        ),
        child: const Center(
          child: Image(
            image: AssetImage('assets/icon_transparent.png'),
            width: double.maxFinite,
          ),
        ),
      ),
    );
  }
}

