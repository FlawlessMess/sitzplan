import 'package:flutter_test/flutter_test.dart';
import 'package:sitzplan/models/classroom.dart';
import 'package:sitzplan/models/student.dart';
import 'package:sitzplan/models/constraint.dart';
import 'package:sitzplan/models/seating_layout.dart';
import 'package:sitzplan/logic/auto_assigner.dart';

void main() {
  test('Auto-Assign platziert alle Schüler', () {
    final a = Student(name: 'Anna');
    final b = Student(name: 'Ben');
    final c = Student(name: 'Cem');
    final room = Classroom(name: '7b', students: [a, b, c]);
    room.layout = SeatingLayout.fromTemplate(LayoutTemplate.rows, 3);

    AutoAssigner(room).assign();

    final seated =
        room.layout.seats.where((s) => s.studentId != null).length;
    expect(seated, 3);
  });

  test('"Nicht neben" wird nach Möglichkeit eingehalten', () {
    final a = Student(name: 'Anna');
    final b = Student(name: 'Ben');
    a.constraints
        .add(Constraint(type: ConstraintType.notNextTo, targetStudentId: b.id));
    // genug Plätze, damit eine konfliktfreie Lösung existiert
    final room = Classroom(name: '7b', students: [a, b]);
    room.layout = SeatingLayout.fromTemplate(LayoutTemplate.rows, 6);

    AutoAssigner(room, seed: 1).assign();
    final conflicts = AutoAssigner(room).validate();

    expect(conflicts.where((c) => c.studentId == a.id), isEmpty);
  });

  test('JSON-Serialisierung ist verlustfrei', () {
    final room = Classroom(name: '10a', students: [Student(name: 'Tim')]);
    room.layout = SeatingLayout.fromTemplate(LayoutTemplate.groups, 1);
    final restored = Classroom.fromJson(room.toJson());

    expect(restored.name, '10a');
    expect(restored.students.length, 1);
    expect(restored.students.first.name, 'Tim');
    expect(restored.layout.seats.length, room.layout.seats.length);
  });
}
