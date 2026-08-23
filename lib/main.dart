import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/morning_routine_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ],
  );

  runApp(const SpiedApp());
}

class SpiedApp extends StatelessWidget {
  const SpiedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SP!ED Morning',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
      ),
      home: const MorningRoutinePage(),
    );
  }
}
