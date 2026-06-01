import 'package:flutter/material.dart';

import '../ui/screens/project_open_screen.dart';

class CvModelLabApp extends StatelessWidget {
  const CvModelLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CV Model Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2563eb),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
      ),
      home: const ProjectOpenScreen(),
    );
  }
}
