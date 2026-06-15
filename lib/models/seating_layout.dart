import 'seat.dart';

/// Eine Seite des Klassenraums.
enum RoomSide { top, right, bottom, left }

extension RoomSideInfo on RoomSide {
  String get label {
    switch (this) {
      case RoomSide.top:
        return 'Oben';
      case RoomSide.right:
        return 'Rechts';
      case RoomSide.bottom:
        return 'Unten';
      case RoomSide.left:
        return 'Links';
    }
  }
}

/// Beibehalten für ältere gespeicherte Daten (Migration auf [RoomSide]).
enum WindowSide { left, right }

/// Vorgefertigte Anordnungs-Vorlagen.
enum LayoutTemplate { rows, uShape, groups, pairs }

extension LayoutTemplateInfo on LayoutTemplate {
  String get label {
    switch (this) {
      case LayoutTemplate.rows:
        return 'Reihen';
      case LayoutTemplate.uShape:
        return 'U-Form';
      case LayoutTemplate.groups:
        return 'Gruppentische';
      case LayoutTemplate.pairs:
        return 'Partnertische';
    }
  }

  String get description {
    switch (this) {
      case LayoutTemplate.rows:
        return 'Klassische Reihen, Frontalunterricht';
      case LayoutTemplate.uShape:
        return 'Hufeisen – alle sehen sich';
      case LayoutTemplate.groups:
        return '4er-Inseln für Gruppenarbeit';
      case LayoutTemplate.pairs:
        return 'Zweiertische nebeneinander';
    }
  }

  String get icon {
    switch (this) {
      case LayoutTemplate.rows:
        return '▤';
      case LayoutTemplate.uShape:
        return '⊔';
      case LayoutTemplate.groups:
        return '⊞';
      case LayoutTemplate.pairs:
        return '◫';
    }
  }
}

/// Die komplette Sitzordnung einer Klasse: alle Plätze + Raum-Ausrichtung
/// (wo Tafel, Fenster und Ausgang liegen).
class SeatingLayout {
  List<Seat> seats;
  RoomSide boardSide; // Tafel / vorne (Lehrkraft)
  RoomSide windowSide; // Fenster
  RoomSide exitSide; // Ausgang / Tür

  SeatingLayout({
    List<Seat>? seats,
    this.boardSide = RoomSide.top,
    this.windowSide = RoomSide.left,
    this.exitSide = RoomSide.bottom,
  }) : seats = seats ?? [];

  Map<String, dynamic> toJson() => {
        'seats': seats.map((s) => s.toJson()).toList(),
        'boardSide': boardSide.name,
        'windowSide': windowSide.name,
        'exitSide': exitSide.name,
      };

  factory SeatingLayout.fromJson(Map<String, dynamic> json) {
    RoomSide parseSide(dynamic v, RoomSide fallback) {
      if (v == null) return fallback;
      // alte WindowSide-Werte ('left'/'right') sind direkt kompatibel
      return RoomSide.values.firstWhere(
        (s) => s.name == v,
        orElse: () => fallback,
      );
    }

    return SeatingLayout(
      seats: (json['seats'] as List<dynamic>? ?? [])
          .map((s) => Seat.fromJson(s as Map<String, dynamic>))
          .toList(),
      boardSide: parseSide(json['boardSide'], RoomSide.top),
      windowSide: parseSide(json['windowSide'], RoomSide.left),
      exitSide: parseSide(json['exitSide'], RoomSide.bottom),
    );
  }

  /// Erzeugt eine Sitzordnung aus einer Vorlage für [count] Schüler.
  factory SeatingLayout.fromTemplate(
    LayoutTemplate template,
    int count, {
    RoomSide boardSide = RoomSide.top,
    RoomSide windowSide = RoomSide.left,
    RoomSide exitSide = RoomSide.bottom,
  }) {
    final seats = <Seat>[];
    switch (template) {
      case LayoutTemplate.rows:
        const perRow = 6;
        for (var i = 0; i < count; i++) {
          final col = i % perRow;
          final row = i ~/ perRow;
          seats.add(Seat(x: col.toDouble(), y: row.toDouble()));
        }
        break;
      case LayoutTemplate.pairs:
        const perRow = 6; // 3 Paare pro Reihe
        for (var i = 0; i < count; i++) {
          final inRow = i % perRow;
          final row = i ~/ perRow;
          final col = inRow + (inRow ~/ 2) * 0.5;
          seats.add(Seat(x: col, y: row.toDouble()));
        }
        break;
      case LayoutTemplate.groups:
        const groupsPerRow = 3;
        for (var i = 0; i < count; i++) {
          final g = i ~/ 4;
          final inGroup = i % 4;
          final gCol = g % groupsPerRow;
          final gRow = g ~/ groupsPerRow;
          final dx = (inGroup % 2).toDouble();
          final dy = (inGroup ~/ 2).toDouble();
          seats.add(Seat(x: gCol * 3 + dx, y: gRow * 3 + dy));
        }
        break;
      case LayoutTemplate.uShape:
        _buildUShape(seats, count);
        break;
    }
    return SeatingLayout(
      seats: seats,
      boardSide: boardSide,
      windowSide: windowSide,
      exitSide: exitSide,
    );
  }

  static void _buildUShape(List<Seat> seats, int count) {
    const width = 7;
    const height = 4;
    final positions = <List<double>>[];
    for (var r = 0; r < height; r++) {
      positions.add([0, r.toDouble()]);
    }
    for (var col = 0; col < width; col++) {
      positions.add([col.toDouble(), height.toDouble()]);
    }
    for (var r = height - 1; r >= 0; r--) {
      positions.add([(width - 1).toDouble(), r.toDouble()]);
    }
    for (var i = 0; i < count; i++) {
      final p = positions[i % positions.length];
      final ring = i ~/ positions.length;
      seats.add(Seat(x: p[0] + ring.toDouble(), y: p[1] - ring.toDouble()));
    }
  }
}
