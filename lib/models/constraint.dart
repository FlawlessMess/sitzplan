import 'package:uuid/uuid.dart';

/// Art einer Sitz-Regel, die einem Schüler zugeordnet werden kann.
enum ConstraintType {
  notNextTo, // darf nicht neben einem bestimmten Schüler sitzen
  preferFront, // soll vorne bei der Lehrkraft sitzen
  preferBack, // soll hinten sitzen
  preferWindow, // soll am Fenster sitzen
  preferAisle, // soll am Gang / an der Tür sitzen
  needsQuiet, // soll einen ruhigen Platz bekommen
}

extension ConstraintTypeInfo on ConstraintType {
  String get label {
    switch (this) {
      case ConstraintType.notNextTo:
        return 'Nicht neben';
      case ConstraintType.preferFront:
        return 'Vorne sitzen';
      case ConstraintType.preferBack:
        return 'Hinten sitzen';
      case ConstraintType.preferWindow:
        return 'Am Fenster';
      case ConstraintType.preferAisle:
        return 'Am Gang / Tür';
      case ConstraintType.needsQuiet:
        return 'Ruhiger Platz';
    }
  }

  String get icon {
    switch (this) {
      case ConstraintType.notNextTo:
        return '🚫';
      case ConstraintType.preferFront:
        return '⬆️';
      case ConstraintType.preferBack:
        return '⬇️';
      case ConstraintType.preferWindow:
        return '🪟';
      case ConstraintType.preferAisle:
        return '🚪';
      case ConstraintType.needsQuiet:
        return '🤫';
    }
  }

  /// Kurze Erklärung, was die Regel bewirkt.
  String get description {
    switch (this) {
      case ConstraintType.notNextTo:
        return 'Setzt zwei Schüler nicht nebeneinander';
      case ConstraintType.preferFront:
        return 'Platz nah an der Tafel';
      case ConstraintType.preferBack:
        return 'Platz weiter hinten';
      case ConstraintType.preferWindow:
        return 'Platz auf der Fensterseite';
      case ConstraintType.preferAisle:
        return 'Platz nah am Ausgang';
      case ConstraintType.needsQuiet:
        return 'Ruhiger Platz, wenig Durchgang';
    }
  }

  /// Ob diese Regel sich auf einen anderen Schüler bezieht.
  bool get needsTarget => this == ConstraintType.notNextTo;
}

/// Eine konkrete Regel für einen Schüler. Optional mit Ziel-Schüler.
class Constraint {
  final String id;
  final ConstraintType type;
  final String? targetStudentId; // nur für notNextTo relevant

  Constraint({
    String? id,
    required this.type,
    this.targetStudentId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'targetStudentId': targetStudentId,
      };

  factory Constraint.fromJson(Map<String, dynamic> json) => Constraint(
        id: json['id'] as String?,
        type: ConstraintType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ConstraintType.needsQuiet,
        ),
        targetStudentId: json['targetStudentId'] as String?,
      );
}
