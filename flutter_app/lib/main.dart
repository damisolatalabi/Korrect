import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/tutorial_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final tutorialDone = prefs.getBool('korrect_tutorial_done') ?? false;
  runApp(KorrectApp(showTutorial: !tutorialDone));
}

class KorrectApp extends StatelessWidget {
  final bool showTutorial;

  const KorrectApp({super.key, required this.showTutorial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Korrect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
        ),
        useMaterial3: true,
      ),
      home: showTutorial ? const TutorialScreen() : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
