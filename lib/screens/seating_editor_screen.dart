import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/repository.dart';
import '../models/classroom.dart';
import '../models/seat.dart';
import '../models/seating_layout.dart';
import '../logic/auto_assigner.dart';
import '../logic/print_plan.dart';
import '../theme/app_theme.dart';
import '../widgets/room_frame.dart';

// Tische sind rechteckig: breiter als hoch. Getrennte Rastergrößen für
// horizontale und vertikale Abstände.
const double kCellX = 108; // horizontaler Rasterabstand
const double kCellY = 80; // vertikaler Rasterabstand
const double kSeatW = 96; // Tisch-Breite
const double kSeatH = 60; // Tisch-Höhe

/// Editor für die Sitzordnung: Tische anordnen, Schüler zuweisen,
/// Vorlagen laden, automatisch zuweisen und Konflikte sehen.
class SeatingEditorScreen extends StatefulWidget {
  final Classroom classroom;

  /// Wenn true: nur Tische anordnen (kein „Schüler zuweisen"-Reiter),
  /// startet direkt im Anordnen-Modus. Genutzt aus dem Wizard.
  final bool tablesOnly;

  const SeatingEditorScreen({
    super.key,
    required this.classroom,
    this.tablesOnly = false,
  });

  @override
  State<SeatingEditorScreen> createState() => _SeatingEditorScreenState();
}

enum _Mode { assign, arrange }

class _SeatingEditorScreenState extends State<SeatingEditorScreen> {
  Classroom get c => widget.classroom;
  SeatingLayout get layout => c.layout;

  late _Mode _mode =
      widget.tablesOnly ? _Mode.arrange : _Mode.assign;
  List<Conflict> _conflicts = [];

  @override
  void initState() {
    super.initState();
    // Falls noch kein Plan existiert: Standard-Vorlage "Reihen".
    if (layout.seats.isEmpty) {
      c.layout = SeatingLayout.fromTemplate(
          LayoutTemplate.rows, c.students.length,
          windowSide: layout.windowSide);
    }
    _revalidate();
  }

  void _revalidate() {
    _conflicts = AutoAssigner(c).validate();
  }

  void _persist() {
    _revalidate();
    ClassroomRepository.instance.save(c);
    setState(() {});
  }

  // ---- Aktionen ----------------------------------------------------------

  void _autoAssign() {
    AutoAssigner(c, seed: DateTime.now().millisecondsSinceEpoch).assign();
    _persist();
    if (mounted) {
      final msg = _conflicts.isEmpty
          ? 'Alle Regeln erfüllt 🎉'
          : '${_conflicts.length} Regel(n) nicht erfüllbar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _applyTemplate(LayoutTemplate t) {
    // bestehende Schüler den neuen Plätzen der Reihe nach zuordnen
    final assigned =
        layout.seats.where((s) => s.studentId != null).map((s) => s.studentId!);
    final order = [
      ...assigned,
      ...c.students
          .map((s) => s.id)
          .where((id) => !assigned.contains(id)),
    ];
    c.layout = SeatingLayout.fromTemplate(t, c.students.length,
        windowSide: layout.windowSide);
    for (var i = 0; i < c.layout.seats.length && i < order.length; i++) {
      c.layout.seats[i].studentId = order[i];
    }
    _persist();
  }

  void _clearAll() {
    for (final s in layout.seats) {
      s.studentId = null;
    }
    _persist();
  }

  void _addSeat() {
    // neuen leeren Platz unten links hinzufügen
    final maxY = layout.seats.isEmpty
        ? 0.0
        : layout.seats.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    layout.seats.add(Seat(x: 0, y: maxY + 1));
    _persist();
  }

  // ---- Schüler-Zuweisung -------------------------------------------------

  Future<void> _onSeatTap(Seat seat) async {
    if (_mode == _Mode.arrange) return;
    final current = c.studentById(seat.studentId);
    final result = await showModalBottomSheet<_PickResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _StudentPicker(classroom: c, currentSeat: seat),
    );
    if (result == null) return;

    if (result.clear) {
      seat.studentId = null;
    } else if (result.studentId != null) {
      // falls Schüler woanders sitzt → tauschen
      for (final s in layout.seats) {
        if (s.studentId == result.studentId) s.studentId = seat.studentId;
      }
      seat.studentId = result.studentId;
    }
    _persist();
    // ignore: unnecessary_statements
    current;
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tablesOnly ? 'Tische anordnen' : 'Sitzplan'),
        actions: [
          IconButton(
            tooltip: 'Drucken / PDF',
            icon: const Icon(CupertinoIcons.printer),
            onPressed: () => printSeatingPlan(c),
          ),
          IconButton(
            tooltip: 'Vorlage',
            icon: const Icon(CupertinoIcons.square_grid_2x2),
            onPressed: _showTemplates,
          ),
          IconButton(
            tooltip: 'Mehr',
            icon: const Icon(CupertinoIcons.ellipsis_circle),
            onPressed: _showMore,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.tablesOnly)
            _ModeSwitch(
              mode: _mode,
              onChanged: (m) => setState(() => _mode = m),
            )
          else
            const _ArrangeHint(),
          if (_conflicts.isNotEmpty && !widget.tablesOnly)
            _ConflictBanner(conflicts: _conflicts),
          Expanded(child: _buildCanvas()),
        ],
      ),
      floatingActionButton: widget.tablesOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _autoAssign,
              icon: const Icon(CupertinoIcons.wand_stars),
              label: const Text('Auto-Sitzplan'),
            ),
    );
  }

  Widget _buildCanvas() {
    final seats = layout.seats;
    final maxX =
        seats.isEmpty ? 1.0 : seats.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    final maxY =
        seats.isEmpty ? 1.0 : seats.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    const frame = 44.0; // Platz für die Raum-Beschriftung am Rand
    final width = (maxX + 2) * kCellX + frame * 2;
    final height = (maxY + 2) * kCellY + frame * 2;

    final conflictIds = _conflicts.map((c) => c.studentId).toSet();

    return InteractiveViewer(
      constrained: false,
      minScale: 0.4,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(200),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: (width < 360 ? 360 : width),
          height: (height < 460 ? 460 : height),
          child: RoomFrame(
            layout: layout,
            child: Stack(
              children: [
                for (final seat in seats)
                  Positioned(
                    left: seat.x * kCellX + (kCellX - kSeatW) / 2,
                    top: seat.y * kCellY + (kCellY - kSeatH) / 2,
                    child: _buildSeat(seat, conflictIds),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeat(Seat seat, Set<String> conflictIds) {
    final student = c.studentById(seat.studentId);
    final idx = student == null ? 0 : c.students.indexOf(student);
    final hasConflict =
        student != null && conflictIds.contains(student.id);

    final tile = SeatTile(
      name: student?.displayName(idx),
      color: student == null ? null : AppTheme.avatarColor(student.id),
      textColor:
          student == null ? null : AppTheme.avatarTextColor(student.id),
      hasConflict: hasConflict,
      empty: student == null,
    );

    if (_mode == _Mode.arrange) {
      // Tische frei verschieben
      return GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            seat.x += d.delta.dx / kCellX;
            seat.y += d.delta.dy / kCellY;
            if (seat.x < 0) seat.x = 0;
            if (seat.y < 0) seat.y = 0;
          });
        },
        onPanEnd: (_) {
          // auf halbes Raster einrasten
          seat.x = (seat.x * 2).round() / 2;
          seat.y = (seat.y * 2).round() / 2;
          _persist();
        },
        onLongPress: () => _removeSeat(seat),
        child: tile,
      );
    }

    return GestureDetector(
      onTap: () => _onSeatTap(seat),
      child: tile,
    );
  }

  void _removeSeat(Seat seat) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Platz entfernen?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              layout.seats.remove(seat);
              _persist();
            },
            child: const Text('Platz löschen'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
      ),
    );
  }

  void _showTemplates() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Vorlage wählen',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            ...LayoutTemplate.values.map((t) => ListTile(
                  leading: const Icon(CupertinoIcons.square_grid_2x2,
                      color: AppTheme.primary),
                  title: Text(t.label),
                  subtitle: Text(t.description),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyTemplate(t);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showMore() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addSeat();
            },
            child: const Text('Platz hinzufügen'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _clearAll();
            },
            child: const Text('Alle Plätze leeren'),
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

// ---- Teilkomponenten -----------------------------------------------------

class _ModeSwitch extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;
  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: CupertinoSlidingSegmentedControl<_Mode>(
        groupValue: mode,
        children: const {
          _Mode.assign: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('Schüler zuweisen'),
          ),
          _Mode.arrange: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('Tische anordnen'),
          ),
        },
        onValueChanged: (m) {
          if (m != null) onChanged(m);
        },
      ),
    );
  }
}

/// Hinweiszeile im reinen Tische-Modus.
class _ArrangeHint extends StatelessWidget {
  const _ArrangeHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(CupertinoIcons.hand_draw, color: AppTheme.primary, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ziehe die Tische an die gewünschte Position. Langes Drücken entfernt einen Tisch.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  final List<Conflict> conflicts;
  const _ConflictBanner({required this.conflicts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                  color: AppTheme.orange, size: 18),
              const SizedBox(width: 8),
              Text('${conflicts.length} Konflikt(e)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.orange)),
            ],
          ),
          const SizedBox(height: 4),
          ...conflicts.take(4).map((c) => Padding(
                padding: const EdgeInsets.only(left: 26, top: 2),
                child: Text('• ${c.message}',
                    style: const TextStyle(fontSize: 13)),
              )),
          if (conflicts.length > 4)
            const Padding(
              padding: EdgeInsets.only(left: 26, top: 2),
              child: Text('…', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// Visuelle Sitz-Kachel (Tisch) – zeigt den vollen Namen direkt im Tisch.
class SeatTile extends StatelessWidget {
  final String? name;
  final Color? color;
  final Color? textColor;
  final bool hasConflict;
  final bool empty;
  final bool selected;

  const SeatTile({
    super.key,
    this.name,
    this.color,
    this.textColor,
    this.hasConflict = false,
    this.empty = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppTheme.primary
        : hasConflict
            ? AppTheme.red
            : empty
                ? const Color(0xFFC9CDD6)
                : Colors.transparent;
    return Container(
      width: kSeatW,
      height: kSeatH,
      decoration: BoxDecoration(
        // leerer Tisch: heller Holz-/Grauton, nicht weiß
        color: empty ? const Color(0xFFEDEFF3) : color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: (hasConflict || selected) ? 3 : 1.2,
        ),
        boxShadow: empty
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      child: empty
          // leerer Tisch wird als Tisch dargestellt (dünne Tischkante)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: kSeatW * 0.55,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB6BCC8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Tisch',
                    style: TextStyle(
                        color: Color(0xFF9AA0AC),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            )
          : Text(
              name ?? '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor ?? const Color(0xFF333333),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.1,
              ),
            ),
    );
  }
}

class _PickResult {
  final String? studentId;
  final bool clear;
  _PickResult({this.studentId, this.clear = false});
}

/// Bottom-Sheet zur Auswahl, welcher Schüler auf einen Platz soll.
class _StudentPicker extends StatelessWidget {
  final Classroom classroom;
  final Seat currentSeat;
  const _StudentPicker(
      {required this.classroom, required this.currentSeat});

  @override
  Widget build(BuildContext context) {
    final seatedIds = classroom.layout.seats
        .where((s) => s.studentId != null && s.id != currentSeat.id)
        .map((s) => s.studentId)
        .toSet();

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Wer sitzt hier?',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          if (currentSeat.studentId != null)
            ListTile(
              leading: const Icon(CupertinoIcons.clear_circled,
                  color: AppTheme.red),
              title: const Text('Platz freimachen'),
              onTap: () =>
                  Navigator.pop(context, _PickResult(clear: true)),
            ),
          ...classroom.students.map((s) {
            final i = classroom.students.indexOf(s);
            final seatedElsewhere = seatedIds.contains(s.id);
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
              subtitle:
                  seatedElsewhere ? const Text('sitzt bereits – tauschen') : null,
              trailing: s.id == currentSeat.studentId
                  ? const Icon(CupertinoIcons.checkmark_alt,
                      color: AppTheme.green)
                  : null,
              onTap: () => Navigator.pop(
                  context, _PickResult(studentId: s.id)),
            );
          }),
        ],
      ),
    );
  }
}
