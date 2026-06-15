import 'package:uuid/uuid.dart';

/// Ein einzelner Sitzplatz / Tisch auf dem Plan.
///
/// Position wird in logischen Einheiten gespeichert (1 Einheit ≈ ein Tisch),
/// sodass der Plan unabhängig von der Bildschirmgröße ist. Beim Drag & Drop
/// werden [x]/[y] frei verändert; Vorlagen setzen sie auf ein Raster.
class Seat {
  final String id;
  double x;
  double y;
  String? studentId; // belegt durch diesen Schüler (null = leer)

  Seat({
    String? id,
    required this.x,
    required this.y,
    this.studentId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'studentId': studentId,
      };

  factory Seat.fromJson(Map<String, dynamic> json) => Seat(
        id: json['id'] as String?,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        studentId: json['studentId'] as String?,
      );
}
