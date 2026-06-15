import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/repository.dart';
import '../models/classroom.dart';
import '../models/seat.dart';
import '../models/student.dart';
import '../models/constraint.dart';
import '../models/seating_layout.dart';
import '../logic/auto_assigner.dart';
import '../logic/print_plan.dart';
import '../theme/app_theme.dart';
import '../widgets/room_frame.dart';
import '../widgets/responsive.dart';
import 'seating_editor_screen.dart';

/// Geführter Assistent zum Erstellen eines kompletten Sitzplans in Schritten:
/// 1) Klasse  2) Schüler  3) Klassenraum  4) Auto-Zuordnung  5) Fertig.
class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  final Classroom c = Classroom(name: '');
  int _step = 0;
  LayoutTemplate _template = LayoutTemplate.rows;
  List<Conflict> _conflicts = [];
  String? _selectedSeatId; // für den Tausch per Antippen in Schritt 4

  static const _titles = [
    'Klasse anlegen',
    'Schüler hinzufügen',
    'Klassenraum',
    'Auto-Zuordnung',
    'Fertig!',
  ];

  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canProceed => _step != 1 || c.students.isNotEmpty;

  void _next() {
    if (_step == 0) c.name = _nameController.text;
    if (_step == 1) _rebuildLayout();
    if (_step == 2) _runAutoAssign();
    if (_step < _titles.length - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _rebuildLayout() {
    c.layout = SeatingLayout.fromTemplate(
      _template,
      c.students.length,
      boardSide: c.layout.boardSide,
      windowSide: c.layout.windowSide,
      exitSide: c.layout.exitSide,
    );
  }

  void _runAutoAssign() {
    _rebuildLayout();
    AutoAssigner(c, seed: DateTime.now().millisecondsSinceEpoch).assign();
    _conflicts = AutoAssigner(c).validate();
    _selectedSeatId = null;
  }

  /// Zwei-Tipp-Tausch direkt in der Vorschau (Schritt 4).
  void _onSeatTap(Seat seat) {
    setState(() {
      if (_selectedSeatId == null) {
        _selectedSeatId = seat.id;
      } else if (_selectedSeatId == seat.id) {
        _selectedSeatId = null;
      } else {
        final a =
            c.layout.seats.firstWhere((s) => s.id == _selectedSeatId);
        final tmp = a.studentId;
        a.studentId = seat.studentId;
        seat.studentId = tmp;
        _selectedSeatId = null;
        _conflicts = AutoAssigner(c).validate();
      }
    });
  }

  Future<void> _openEditor({bool tablesOnly = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              SeatingEditorScreen(classroom: c, tablesOnly: tablesOnly)),
    );
    setState(() => _conflicts = AutoAssigner(c).validate());
  }

  Future<void> _finish() async {
    c.name = _nameController.text;
    await ClassroomRepository.instance.addClassroom(c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _titles.length - 1;
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? IconButton(
                icon: const Icon(CupertinoIcons.xmark),
                onPressed: () => Navigator.pop(context))
            : IconButton(
                icon: const Icon(CupertinoIcons.chevron_back),
                onPressed: _back),
        title: Text(_titles[_step]),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            _ProgressBar(step: _step, total: _titles.length),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child:
                    KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
              ),
            ),
            _buildBottomBar(last),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool last) {
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_step > 0 && !last) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _back,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Zurück'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed:
                  last ? _finish : (_canProceed ? _next : null),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(last ? 'Speichern & schließen' : 'Weiter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepClass(controller: _nameController);
      case 1:
        return _StepStudents(
            classroom: c, onChanged: () => setState(() {}));
      case 2:
        return _StepRoom(
          classroom: c,
          template: _template,
          onTemplate: (t) => setState(() {
            _template = t;
            _rebuildLayout();
          }),
          onSideChanged: () => setState(_rebuildLayout),
          onArrangeTables: () => _openEditor(tablesOnly: true),
        );
      case 3:
        return _StepAssign(
          classroom: c,
          conflicts: _conflicts,
          selectedSeatId: _selectedSeatId,
          onShuffle: () => setState(_runAutoAssign),
          onSeatTap: _onSeatTap,
          onEdit: () => _openEditor(tablesOnly: true),
        );
      default:
        return _StepDone(classroom: c, conflicts: _conflicts);
    }
  }
}

// ---- Fortschrittsbalken --------------------------------------------------

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(total, (i) {
              final active = i <= step;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary
                        : Colors.black.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text('Schritt ${step + 1} von $total',
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---- Schritt 1: Klasse ---------------------------------------------------

class _StepClass extends StatelessWidget {
  final TextEditingController controller;
  const _StepClass({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepHeader(
          icon: CupertinoIcons.person_3_fill,
          title: 'Wie heißt die Klasse?',
          subtitle:
              'Gib einen Namen ein – oder lass das Feld leer für eine anonyme Klasse.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'z. B. 7b, Mathe LK …',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Schritt 2: Schüler --------------------------------------------------

class _StepStudents extends StatefulWidget {
  final Classroom classroom;
  final VoidCallback onChanged;
  const _StepStudents({required this.classroom, required this.onChanged});

  @override
  State<_StepStudents> createState() => _StepStudentsState();
}

class _StepStudentsState extends State<_StepStudents> {
  final _input = TextEditingController();
  Classroom get c => widget.classroom;

  void _addSingle() {
    final text = _input.text.trim();
    if (text.isEmpty) {
      c.students.add(Student(name: ''));
    } else {
      c.students.add(Student(name: text));
    }
    _input.clear();
    widget.onChanged();
  }

  Future<void> _addBulk() async {
    final added = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _BulkAddSheet(classroom: c),
    );
    if (added != null) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Erklärung
        Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(CupertinoIcons.info_circle_fill,
                  color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tippe auf einen Schüler, um Regeln zu setzen – z. B. „nicht neben", „am Fenster" oder „vorne bei der Tafel".',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        // Eingabe
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Name (leer = anonym)',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _addSingle(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _addSingle,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: const CircleBorder(),
                ),
                child: const Icon(CupertinoIcons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _addBulk,
                icon: const Icon(CupertinoIcons.list_bullet, size: 18),
                label: const Text('Mehrere auf einmal eingeben'),
              ),
              const Spacer(),
              if (c.students.isNotEmpty)
                Text('${c.students.length} Schüler',
                    style: const TextStyle(color: Colors.black45)),
            ],
          ),
        ),
        if (c.students.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Noch keine Schüler.\nFüge den ersten hinzu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45)),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              itemCount: c.students.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = c.students[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.avatarColor(s.id),
                      child: Text(s.initials(i),
                          style: TextStyle(
                              color: AppTheme.avatarTextColor(s.id),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    title: Text(s.displayName(i)),
                    subtitle: s.constraints.isEmpty
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: s.constraints
                                  .map((con) => _RulePill(
                                      con: con, classroom: c))
                                  .toList(),
                            ),
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // direkter Regel-Button
                        IconButton(
                          tooltip: 'Regel hinzufügen',
                          icon: const Icon(CupertinoIcons.slider_horizontal_3,
                              color: AppTheme.primary),
                          onPressed: () => _editStudent(s, i),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.minus_circle,
                              color: AppTheme.red),
                          onPressed: () {
                            c.students.removeAt(i);
                            widget.onChanged();
                          },
                        ),
                      ],
                    ),
                    onTap: () => _editStudent(s, i),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _editStudent(Student s, int index) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          StudentRulesSheet(student: s, index: index, classroom: c),
    );
    widget.onChanged();
  }
}

/// Sheet zum Einfügen mehrerer Schüler auf einmal (ein Name pro Zeile).
class _BulkAddSheet extends StatefulWidget {
  final Classroom classroom;
  const _BulkAddSheet({required this.classroom});

  @override
  State<_BulkAddSheet> createState() => _BulkAddSheetState();
}

class _BulkAddSheetState extends State<_BulkAddSheet> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mehrere Schüler einfügen',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Ein Name pro Zeile – ideal zum Einfügen aus einer Liste.',
                  style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 8,
                minLines: 5,
                decoration: InputDecoration(
                  hintText: 'Anna\nBen\nCem\nDilara\n…',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    var count = 0;
                    for (final line in _controller.text.split('\n')) {
                      if (line.trim().isNotEmpty) {
                        widget.classroom.students
                            .add(Student(name: line.trim()));
                        count++;
                      }
                    }
                    Navigator.pop(context, count);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Hinzufügen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleines Label für eine gesetzte Regel.
class _RulePill extends StatelessWidget {
  final Constraint con;
  final Classroom classroom;
  const _RulePill({required this.con, required this.classroom});

  @override
  Widget build(BuildContext context) {
    var text = con.type.label;
    if (con.type.needsTarget) {
      final t = classroom.studentById(con.targetStudentId);
      final ti = t == null ? 0 : classroom.students.indexOf(t);
      text = '${con.type.icon} ${t?.displayName(ti) ?? '?'}';
    } else {
      text = '${con.type.icon} ${con.type.label}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}

// ---- Schritt 3: Klassenraum ----------------------------------------------

class _StepRoom extends StatelessWidget {
  final Classroom classroom;
  final LayoutTemplate template;
  final ValueChanged<LayoutTemplate> onTemplate;
  final VoidCallback onSideChanged;
  final VoidCallback onArrangeTables;

  const _StepRoom({
    required this.classroom,
    required this.template,
    required this.onTemplate,
    required this.onSideChanged,
    required this.onArrangeTables,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepHeader(
          icon: CupertinoIcons.square_grid_2x2,
          title: 'Wie sieht der Raum aus?',
          subtitle:
              'Ziehe Tafel, Fenster und Ausgang an die passende Wand und wähle die Tisch-Anordnung.',
        ),
        const SizedBox(height: 16),
        _RoomConfigurator(
          layout: classroom.layout,
          onChanged: onSideChanged,
        ),
        const SizedBox(height: 24),
        const Text('Anordnung der Tische',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _TemplatePicker(
          count: classroom.students.length,
          selected: template,
          onSelect: onTemplate,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onArrangeTables,
            icon: const Icon(CupertinoIcons.hand_draw, size: 18),
            label: const Text('Tische einzeln anordnen'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Raum, in dem Tafel/Fenster/Ausgang per Drag an die Wände gezogen werden.
class _RoomConfigurator extends StatelessWidget {
  final SeatingLayout layout;
  final VoidCallback onChanged;
  const _RoomConfigurator({required this.layout, required this.onChanged});

  static const _edge = 50.0;

  List<_Param> _paramsOn(RoomSide side) =>
      _Param.values.where((p) => p.sideOf(layout) == side).toList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // Raumkörper mit Sitz-Vorschau
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_edge - 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black12, width: 1.5),
                ),
                padding: const EdgeInsets.all(10),
                child: layout.seats.isEmpty
                    ? const SizedBox.shrink()
                    : FittedBox(
                        child: _SeatPreview(seats: layout.seats),
                      ),
              ),
            ),
          ),
          _strip(RoomSide.top),
          _strip(RoomSide.bottom),
          _strip(RoomSide.left),
          _strip(RoomSide.right),
        ],
      ),
    );
  }

  Widget _strip(RoomSide side) {
    final vertical = side == RoomSide.left || side == RoomSide.right;
    final chips = _paramsOn(side)
        .map((p) => _DraggableParam(param: p, rotatedFor: side))
        .toList();

    final content = DragTarget<_Param>(
      onAcceptWithDetails: (d) {
        d.data.setSide(layout, side);
        onChanged();
      },
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: highlight
                ? AppTheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: chips,
          ),
        );
      },
    );

    switch (side) {
      case RoomSide.top:
        return Positioned(top: 0, left: 0, right: 0, height: _edge, child: content);
      case RoomSide.bottom:
        return Positioned(
            bottom: 0, left: 0, right: 0, height: _edge, child: content);
      case RoomSide.left:
        return Positioned(
            left: 0, top: _edge, bottom: _edge, width: _edge, child: content);
      case RoomSide.right:
        return Positioned(
            right: 0, top: _edge, bottom: _edge, width: _edge, child: content);
    }
  }
}

class _DraggableParam extends StatelessWidget {
  final _Param param;
  final RoomSide rotatedFor;
  const _DraggableParam({required this.param, required this.rotatedFor});

  @override
  Widget build(BuildContext context) {
    final vertical =
        rotatedFor == RoomSide.left || rotatedFor == RoomSide.right;
    Widget chip = _ParamChip(param: param);
    if (vertical) {
      chip = RotatedBox(
          quarterTurns: rotatedFor == RoomSide.left ? 3 : 1, child: chip);
    }
    return Draggable<_Param>(
      data: param,
      feedback: Material(
        color: Colors.transparent,
        child: _ParamChip(param: param, elevated: true),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: Padding(padding: const EdgeInsets.all(2), child: chip),
    );
  }
}

class _ParamChip extends StatelessWidget {
  final _Param param;
  final bool elevated;
  const _ParamChip({required this.param, this.elevated = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: param.fill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: param.textColor.withValues(alpha: 0.20)),
        boxShadow: elevated
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 8)
              ]
            : null,
      ),
      child: Text(param.text,
          style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: param.textColor)),
    );
  }
}

enum _Param { board, window, exit }

extension _ParamInfo on _Param {
  String get text {
    switch (this) {
      case _Param.board:
        return '📋 Tafel';
      case _Param.window:
        return '🪟 Fenster';
      case _Param.exit:
        return '🚪 Ausgang';
    }
  }

  Color get fill {
    switch (this) {
      case _Param.board:
        return const Color(0xFFDCE8DC);
      case _Param.window:
        return const Color(0xFFD6E4F0);
      case _Param.exit:
        return const Color(0xFFF0E6D6);
    }
  }

  Color get textColor {
    switch (this) {
      case _Param.board:
        return const Color(0xFF3A5240);
      case _Param.window:
        return const Color(0xFF2C4A66);
      case _Param.exit:
        return const Color(0xFF5E4B30);
    }
  }

  RoomSide sideOf(SeatingLayout l) {
    switch (this) {
      case _Param.board:
        return l.boardSide;
      case _Param.window:
        return l.windowSide;
      case _Param.exit:
        return l.exitSide;
    }
  }

  void setSide(SeatingLayout l, RoomSide s) {
    switch (this) {
      case _Param.board:
        l.boardSide = s;
        break;
      case _Param.window:
        l.windowSide = s;
        break;
      case _Param.exit:
        l.exitSide = s;
        break;
    }
  }
}

/// Auswahl der Tisch-Anordnung – jede Option zeigt eine Mini-Vorschau.
class _TemplatePicker extends StatelessWidget {
  final int count;
  final LayoutTemplate selected;
  final ValueChanged<LayoutTemplate> onSelect;
  const _TemplatePicker(
      {required this.count, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cols =
        MediaQuery.sizeOf(context).width >= 600 ? 4 : 2;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: LayoutTemplate.values.map((t) {
        final sel = t == selected;
        final preview = SeatingLayout.fromTemplate(t, count == 0 ? 8 : count);
        return GestureDetector(
          onTap: () => onSelect(t),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? AppTheme.primary : Colors.black12,
                width: sel ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: FittedBox(
                    child: _SeatPreview(seats: preview.seats),
                  ),
                ),
                const SizedBox(height: 6),
                Text(t.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? AppTheme.primary : Colors.black87)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Schematische Vorschau einer Tisch-Anordnung (kleine Quadrate, ohne Namen).
class _SeatPreview extends StatelessWidget {
  final List<Seat> seats;
  const _SeatPreview({required this.seats});

  static const double _cellX = 20;
  static const double _cellY = 15;
  static const double _rectW = 16;
  static const double _rectH = 10;

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) return const SizedBox(width: _cellX, height: _cellY);
    final maxX = seats.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    final maxY = seats.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      width: (maxX + 1) * _cellX,
      height: (maxY + 1) * _cellY,
      child: Stack(
        children: [
          for (final s in seats)
            Positioned(
              left: s.x * _cellX,
              top: s.y * _cellY,
              child: Container(
                width: _rectW,
                height: _rectH,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Schritt 4: Auto-Zuordnung -------------------------------------------

class _StepAssign extends StatelessWidget {
  final Classroom classroom;
  final List<Conflict> conflicts;
  final String? selectedSeatId;
  final VoidCallback onShuffle;
  final ValueChanged<Seat> onSeatTap;
  final VoidCallback onEdit;

  const _StepAssign({
    required this.classroom,
    required this.conflicts,
    required this.selectedSeatId,
    required this.onShuffle,
    required this.onSeatTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepHeader(
          icon: CupertinoIcons.wand_stars,
          title: conflicts.isEmpty
              ? 'Sitzplan erstellt 🎉'
              : 'Sitzplan erstellt',
          subtitle: conflicts.isEmpty
              ? 'Alle Regeln berücksichtigt. Tippe zwei Schüler nacheinander an, um sie zu tauschen.'
              : 'Tippe zwei Schüler nacheinander an, um sie zu tauschen – oder ordne neu an.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: _MiniPlan(
            classroom: classroom,
            conflicts: conflicts,
            interactive: true,
            selectedSeatId: selectedSeatId,
            onSeatTap: onSeatTap,
            fitToBox: true,
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '🔍 Mit zwei Fingern zoomen und verschieben',
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        if (conflicts.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: conflicts
                  .take(5)
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• ${c.message}',
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShuffle,
                icon: const Icon(CupertinoIcons.shuffle, size: 18),
                label: const Text('Zufällig anordnen'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(CupertinoIcons.hand_draw, size: 18),
                label: const Text('Sitzordnung anpassen'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- Schritt 5: Fertig ---------------------------------------------------

class _StepDone extends StatelessWidget {
  final Classroom classroom;
  final List<Conflict> conflicts;
  const _StepDone({required this.classroom, required this.conflicts});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        const Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.green,
            child: Icon(CupertinoIcons.checkmark_alt,
                color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(classroom.displayName(0),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '${classroom.students.length} Schüler · ${conflicts.isEmpty ? 'alle Regeln erfüllt' : '${conflicts.length} offene Regel(n)'}',
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 300,
          child: _MiniPlan(
            classroom: classroom,
            conflicts: conflicts,
            fitToBox: true,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => printSeatingPlan(classroom),
            icon: const Icon(CupertinoIcons.printer, size: 18),
            label: const Text('Drucken / als PDF (A4 quer)'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Du kannst den Sitzplan jederzeit über die Klasse erneut öffnen und anpassen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ---- gemeinsam genutzte Teile --------------------------------------------

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primary, size: 30),
        const SizedBox(height: 12),
        Text(title,
            style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

/// Sitzplan-Vorschau mit vollen Namen. Optional interaktiv (Tausch per Tipp).
class _MiniPlan extends StatelessWidget {
  final Classroom classroom;
  final List<Conflict> conflicts;
  final bool interactive;
  final String? selectedSeatId;
  final ValueChanged<Seat>? onSeatTap;

  /// Wenn true: der gesamte Plan wird in die Box eingepasst (skaliert),
  /// bleibt aber per Zwei-Finger-Geste zoom- und verschiebbar.
  final bool fitToBox;

  const _MiniPlan({
    required this.classroom,
    required this.conflicts,
    this.interactive = false,
    this.selectedSeatId,
    this.onSeatTap,
    this.fitToBox = false,
  });

  static const double _frame = 40;

  @override
  Widget build(BuildContext context) {
    final layout = classroom.layout;
    final seats = layout.seats;
    if (seats.isEmpty) return const Center(child: Text('Keine Plätze'));
    final maxX = seats.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    final maxY = seats.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final conflictIds = conflicts.map((c) => c.studentId).toSet();

    final plan = SizedBox(
      width: (maxX + 1) * kCellX + _frame * 2,
      height: (maxY + 1) * kCellY + _frame * 2,
      child: RoomFrame(
        layout: layout,
        inset: _frame,
        child: Stack(
          children: [
            for (final seat in seats)
              Positioned(
                left: seat.x * kCellX + (kCellX - kSeatW) / 2,
                top: seat.y * kCellY + (kCellY - kSeatH) / 2,
                child: _seat(seat, conflictIds),
              ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: const Color(0xFFF7F7FA),
        padding: const EdgeInsets.all(12),
        child: fitToBox
            // gesamten Plan einpassen, trotzdem zoombar
            ? InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(child: FittedBox(child: plan)),
              )
            : InteractiveViewer(
                constrained: false,
                minScale: 0.3,
                maxScale: 2,
                boundaryMargin: const EdgeInsets.all(80),
                child: plan,
              ),
      ),
    );
  }

  Widget _seat(Seat seat, Set<String> conflictIds) {
    final student = classroom.studentById(seat.studentId);
    final idx = student == null ? 0 : classroom.students.indexOf(student);
    final tile = SeatTile(
      name: student?.displayName(idx),
      color: student == null ? null : AppTheme.avatarColor(student.id),
      textColor:
          student == null ? null : AppTheme.avatarTextColor(student.id),
      hasConflict: student != null && conflictIds.contains(student.id),
      empty: student == null,
      selected: seat.id == selectedSeatId,
    );
    if (!interactive) return tile;
    return GestureDetector(
      onTap: () => onSeatTap?.call(seat),
      child: tile,
    );
  }
}

/// Bottom-Sheet zum Bearbeiten von Name & Regeln eines Schülers.
class StudentRulesSheet extends StatefulWidget {
  final Student student;
  final int index;
  final Classroom classroom;
  const StudentRulesSheet({
    super.key,
    required this.student,
    required this.index,
    required this.classroom,
  });

  @override
  State<StudentRulesSheet> createState() => _StudentRulesSheetState();
}

class _StudentRulesSheetState extends State<StudentRulesSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.student.name);

  Student get s => widget.student;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _hasType(ConstraintType t) =>
      s.constraints.any((c) => c.type == t);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Name (leer = anonym)'),
                  onChanged: (v) => s.name = v,
                ),
                const SizedBox(height: 18),
                const Text('Regeln',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('Tippe auf eine Regel, um sie hinzuzufügen.',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 12),
                // alle Regeltypen als antippbare Karten mit Erklärung
                ...ConstraintType.values.map((t) {
                  final active = _hasType(t);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _toggle(t),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.primary.withValues(alpha: 0.10)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? AppTheme.primary
                                : Colors.black12,
                            width: active ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(t.icon,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(t.label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(t.description,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54)),
                                ],
                              ),
                            ),
                            Icon(
                              active
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.add_circled,
                              color: active
                                  ? AppTheme.primary
                                  : Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // bei "nicht neben" zusätzlich die konkreten Zuordnungen
                if (_hasType(ConstraintType.notNextTo)) _notNextToList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notNextToList() {
    final pairs = s.constraints
        .where((c) => c.type == ConstraintType.notNextTo)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        for (final con in pairs)
          Builder(builder: (_) {
            final t = widget.classroom.studentById(con.targetStudentId);
            final ti =
                t == null ? 0 : widget.classroom.students.indexOf(t);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Text('🚫', style: TextStyle(fontSize: 18)),
              title: Text('Nicht neben ${t?.displayName(ti) ?? '?'}'),
              trailing: IconButton(
                icon: const Icon(CupertinoIcons.minus_circle_fill,
                    color: AppTheme.red, size: 20),
                onPressed: () =>
                    setState(() => s.constraints.remove(con)),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _toggle(ConstraintType t) async {
    if (t.needsTarget) {
      // immer einen weiteren Ziel-Schüler hinzufügen
      final target = await _pickStudent();
      if (target == null) return;
      setState(() => s.constraints
          .add(Constraint(type: t, targetStudentId: target)));
      return;
    }
    setState(() {
      if (_hasType(t)) {
        s.constraints.removeWhere((c) => c.type == t);
      } else {
        s.constraints.add(Constraint(type: t));
      }
    });
  }

  Future<String?> _pickStudent() {
    final others =
        widget.classroom.students.where((o) => o.id != s.id).toList();
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
            ...others.map((o) {
              final i = widget.classroom.students.indexOf(o);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.avatarColor(o.id),
                  child: Text(o.initials(i),
                      style: TextStyle(
                          color: AppTheme.avatarTextColor(o.id),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                title: Text(o.displayName(i)),
                onTap: () => Navigator.pop(ctx, o.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}
