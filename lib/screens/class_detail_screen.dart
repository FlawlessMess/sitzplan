import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/repository.dart';
import '../models/classroom.dart';
import '../models/student.dart';
import '../models/constraint.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive.dart';
import 'seating_editor_screen.dart';

/// Detailansicht einer Klasse: Schüler verwalten + Regeln + Sitzplan öffnen.
class ClassDetailScreen extends StatefulWidget {
  final Classroom classroom;
  const ClassDetailScreen({super.key, required this.classroom});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  Classroom get c => widget.classroom;

  void _save() {
    ClassroomRepository.instance.save(c);
    setState(() {});
  }

  Future<void> _addStudent() async {
    final name = await _promptText(
      title: 'Neuer Schüler',
      hint: 'Name – leer = anonym',
    );
    if (name == null) return;
    c.students.add(Student(name: name));
    _save();
  }

  Future<void> _addMultiple() async {
    final text = await _promptText(
      title: 'Mehrere Schüler',
      hint: 'Ein Name pro Zeile',
      multiline: true,
    );
    if (text == null) return;
    for (final line in text.split('\n')) {
      if (line.trim().isNotEmpty) {
        c.students.add(Student(name: line.trim()));
      }
    }
    _save();
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    String initial = '',
    bool multiline = false,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: multiline ? 6 : 1,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: multiline ? null : (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openSeating() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeatingEditorScreen(classroom: c),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final idx = ClassroomRepository.instance.classrooms.indexOf(c);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.displayName(idx < 0 ? 0 : idx)),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.ellipsis_circle),
            onPressed: _showAddMenu,
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: c.students.isEmpty
            ? _emptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: c.students.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _StudentCard(
                  student: c.students[i],
                  index: i,
                  classroom: c,
                  onChanged: _save,
                  onDelete: () {
                    c.students.removeAt(i);
                    _save();
                  },
                ),
              ),
      ),
      floatingActionButton: c.students.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openSeating,
              icon: const Icon(CupertinoIcons.square_grid_2x2),
              label: const Text('Sitzplan'),
            ),
    );
  }

  void _showAddMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addStudent();
            },
            child: const Text('Einzelnen Schüler hinzufügen'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addMultiple();
            },
            child: const Text('Mehrere (Liste) hinzufügen'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.person_badge_plus,
              size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          const Text('Keine Schüler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Füge Schüler hinzu – benannt oder anonym.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _addStudent,
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Schüler hinzufügen'),
          ),
          TextButton(
            onPressed: _addMultiple,
            child: const Text('Mehrere auf einmal'),
          ),
        ],
      ),
    );
  }
}

/// Eine Schüler-Karte mit Name und seinen Regeln (aufklappbar).
class _StudentCard extends StatelessWidget {
  final Student student;
  final int index;
  final Classroom classroom;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _StudentCard({
    required this.student,
    required this.index,
    required this.classroom,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          leading: CircleAvatar(
            backgroundColor: AppTheme.avatarColor(student.id),
            child: Text(
              student.initials(index),
              style: TextStyle(
                  color: AppTheme.avatarTextColor(student.id),
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
          title: Text(student.displayName(index),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: student.constraints.isEmpty
              ? const Text('Keine Regeln',
                  style: TextStyle(color: Colors.black38))
              : Wrap(
                  spacing: 4,
                  children: student.constraints
                      .map((c) => Text(c.type.icon))
                      .toList(),
                ),
          children: [
            ...student.constraints.map((con) => _ConstraintRow(
                  constraint: con,
                  classroom: classroom,
                  onRemove: () {
                    student.constraints.remove(con);
                    onChanged();
                  },
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _addConstraint(context),
                    icon: const Icon(CupertinoIcons.add, size: 18),
                    label: const Text('Regel'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _rename(context),
                    icon: const Icon(CupertinoIcons.pencil, size: 18),
                    label: const Text('Umbenennen'),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(CupertinoIcons.trash,
                        size: 18, color: AppTheme.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: student.name);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Umbenennen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (v != null) {
      student.name = v;
      onChanged();
    }
  }

  Future<void> _addConstraint(BuildContext context) async {
    final type = await showModalBottomSheet<ConstraintType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ConstraintType.values.map((t) {
            return ListTile(
              leading: Text(t.icon, style: const TextStyle(fontSize: 22)),
              title: Text(t.label),
              onTap: () => Navigator.pop(ctx, t),
            );
          }).toList(),
        ),
      ),
    );
    if (type == null) return;

    String? target;
    if (type.needsTarget) {
      target = await _pickStudent(context);
      if (target == null) return;
    }
    student.constraints
        .add(Constraint(type: type, targetStudentId: target));
    onChanged();
  }

  Future<String?> _pickStudent(BuildContext context) {
    final others =
        classroom.students.where((s) => s.id != student.id).toList();
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nicht neben wem?',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            ...others.map((s) {
              final i = classroom.students.indexOf(s);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.avatarColor(s.id),
                  child: Text(s.initials(i),
                      style: TextStyle(
                          color: AppTheme.avatarTextColor(s.id),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                title: Text(s.displayName(i)),
                onTap: () => Navigator.pop(ctx, s.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ConstraintRow extends StatelessWidget {
  final Constraint constraint;
  final Classroom classroom;
  final VoidCallback onRemove;

  const _ConstraintRow({
    required this.constraint,
    required this.classroom,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    var label = constraint.type.label;
    if (constraint.type.needsTarget) {
      final target = classroom.studentById(constraint.targetStudentId);
      final i = target == null ? 0 : classroom.students.indexOf(target);
      label = '${constraint.type.label}: ${target?.displayName(i) ?? '?'}';
    }
    return ListTile(
      dense: true,
      leading: Text(constraint.type.icon,
          style: const TextStyle(fontSize: 20)),
      title: Text(label),
      trailing: IconButton(
        icon: const Icon(CupertinoIcons.minus_circle_fill,
            color: AppTheme.red, size: 20),
        onPressed: onRemove,
      ),
    );
  }
}
