import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/repository.dart';
import '../models/classroom.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive.dart';
import 'class_detail_screen.dart';
import 'wizard_screen.dart';
import 'about_screen.dart';

/// Übersicht aller angelegten Klassen.
class ClassListScreen extends StatelessWidget {
  const ClassListScreen({super.key});

  /// Startet den geführten Assistenten zum Anlegen einer Klasse + Sitzplan.
  void _createClass(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WizardScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _openAbout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ClassroomRepository.instance,
      builder: (context, _) {
        final classes = ClassroomRepository.instance.classrooms;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Klassen'),
            leading: IconButton(
              tooltip: 'Über',
              icon: const Icon(CupertinoIcons.info_circle),
              onPressed: () => _openAbout(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.add),
                onPressed: () => _createClass(context),
              ),
            ],
          ),
          body: ResponsiveCenter(
            child: Column(
              children: [
                const _PrivacyNote(),
                Expanded(
                  child: classes.isEmpty
                      ? _EmptyState(onCreate: () => _createClass(context))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: classes.length,
                          itemBuilder: (context, i) =>
                              _ClassCard(classroom: classes[i], index: i),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kurzer Datenschutz-Hinweis: alles bleibt lokal auf dem Gerät.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE8DC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(CupertinoIcons.lock_shield, color: Color(0xFF3A5240), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Alle Daten bleiben nur lokal auf deinem Gerät – keine Cloud, kein Konto, keine Übertragung.',
              style: TextStyle(fontSize: 13, color: Color(0xFF3A5240)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final Classroom classroom;
  final int index;
  const _ClassCard({required this.classroom, required this.index});

  @override
  Widget build(BuildContext context) {
    final seated =
        classroom.layout.seats.where((s) => s.studentId != null).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.avatarColor(classroom.id),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(CupertinoIcons.person_3_fill,
              color: AppTheme.avatarTextColor(classroom.id)),
        ),
        title: Text(
          classroom.displayName(index),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        subtitle: Text(
          '${classroom.students.length} Schüler · $seated platziert',
          style: const TextStyle(color: Colors.black54),
        ),
        trailing: const Icon(CupertinoIcons.chevron_right,
            size: 18, color: Colors.black26),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ClassDetailScreen(classroom: classroom)),
        ),
        onLongPress: () => _confirmDelete(context),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(classroom.displayName(index)),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ClassroomRepository.instance.deleteClassroom(classroom);
            },
            child: const Text('Klasse löschen'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.person_3,
              size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          const Text('Noch keine Klassen',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Lege deine erste Klasse an.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Klasse anlegen'),
          ),
        ],
      ),
    );
  }
}
