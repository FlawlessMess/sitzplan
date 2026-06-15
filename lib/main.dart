import 'package:flutter/material.dart';
import 'data/repository.dart';
import 'theme/app_theme.dart';
import 'screens/class_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SitzplanApp());
}

class SitzplanApp extends StatelessWidget {
  const SitzplanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sitzplan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Bootstrap(),
    );
  }
}

/// Lädt die gespeicherten Klassen, bevor die Liste angezeigt wird.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    ClassroomRepository.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ClassroomRepository.instance,
      builder: (context, _) {
        if (!ClassroomRepository.instance.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const ClassListScreen();
      },
    );
  }
}
