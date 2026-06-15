import 'package:uuid/uuid.dart';
import 'constraint.dart';

/// Ein Schüler. Kann benannt oder anonym (z. B. "Schüler 3") sein.
class Student {
  final String id;
  String name;
  List<Constraint> constraints;

  Student({
    String? id,
    required this.name,
    List<Constraint>? constraints,
  })  : id = id ?? const Uuid().v4(),
        constraints = constraints ?? [];

  /// Anzeigename – fällt auf einen Platzhalter zurück, wenn leer (anonym).
  String displayName(int indexFallback) =>
      name.trim().isEmpty ? 'Schüler ${indexFallback + 1}' : name.trim();

  /// Initialen für die Sitz-Kachel.
  String initials(int indexFallback) {
    final n = displayName(indexFallback).trim();
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    }
    return n.length >= 2 ? n.substring(0, 2).toUpperCase() : n.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'constraints': constraints.map((c) => c.toJson()).toList(),
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        constraints: (json['constraints'] as List<dynamic>? ?? [])
            .map((c) => Constraint.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
