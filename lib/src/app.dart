import 'package:flutter/material.dart';

import 'app_config.dart';
import 'classic_theme.dart';
import 'project_controller.dart';

class SrTunerApp extends StatelessWidget {
  const SrTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ClassicTheme.light(),
      darkTheme: ClassicTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const ProjectController(),
    );
  }
}
