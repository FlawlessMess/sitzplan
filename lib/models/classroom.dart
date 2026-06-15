import 'package:uuid/uuid.dart';
import 'student.dart';
import 'seating_layout.dart';

/// Eine Klasse mit ihren Schülern und der aktuellen Sitzordnung.
class Classroom {
  final String id;
  String name;
  List<Student> students;
  SeatingLayout layout;
  DateTime updatedAt;

  Classroom({
    String? id,
    required this.name,
    List<Student>? students,
    SeatingLayout? layout,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        students = students ?? [],
        layout = layout ?? SeatingLayout(),
        updatedAt = updatedAt ?? DateTime.now();

  String displayName(int indexFallback) =>
      name.trim().isEmpty ? 'Klasse ${indexFallback + 1}' : name.trim();

  Student? studentById(String? id) {
    if (id == null) return null;
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'students': students.map((s) => s.toJson()).toList(),
        'layout': layout.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Classroom.fromJson(Map<String, dynamic> json) => Classroom(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        students: (json['students'] as List<dynamic>? ?? [])
            .map((s) => Student.fromJson(s as Map<String, dynamic>))
            .toList(),
        layout: json['layout'] != null
            ? SeatingLayout.fromJson(json['layout'] as Map<String, dynamic>)
            : SeatingLayout(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
