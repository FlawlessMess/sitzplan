import 'dart:math';
import '../models/classroom.dart';
import '../models/seat.dart';
import '../models/student.dart';
import '../models/constraint.dart';
import '../models/seating_layout.dart';

/// Ein erkannter Regel-Verstoß (für die Konflikt-Anzeige im Editor).
class Conflict {
  final String studentId;
  final String message;
  Conflict(this.studentId, this.message);
}

/// Berechnet automatische Sitzordnungen anhand der Schüler-Regeln und
/// prüft bestehende (manuelle) Anordnungen auf Verstöße.
class AutoAssigner {
  /// Zwei Plätze gelten als Nachbarn, wenn ihr Abstand <= [neighborThreshold].
  static const double neighborThreshold = 1.6;

  final Classroom classroom;
  final Random _rng;

  AutoAssigner(this.classroom, {int? seed}) : _rng = Random(seed);

  SeatingLayout get _layout => classroom.layout;
  List<Seat> get _seats => _layout.seats;

  // ---- Geometrie / Zonen -------------------------------------------------

  bool _areNeighbors(Seat a, Seat b) {
    final d = sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
    return d > 0 && d <= neighborThreshold;
  }

  /// Nähe (0..1) eines Platzes zu einer Raum-Seite. 1 = direkt an der Seite.
  double _proximity(Seat seat, RoomSide side) {
    if (_seats.isEmpty) return 0.5;
    final xs = _seats.map((s) => s.x);
    final ys = _seats.map((s) => s.y);
    final minX = xs.reduce(min), maxX = xs.reduce(max);
    final minY = ys.reduce(min), maxY = ys.reduce(max);

    double norm(double v, double lo, double hi) =>
        (hi - lo).abs() < 1e-9 ? 0.5 : (v - lo) / (hi - lo);

    switch (side) {
      case RoomSide.top:
        return 1 - norm(seat.y, minY, maxY);
      case RoomSide.bottom:
        return norm(seat.y, minY, maxY);
      case RoomSide.left:
        return 1 - norm(seat.x, minX, maxX);
      case RoomSide.right:
        return norm(seat.x, minX, maxX);
    }
  }

  /// Liefert Zonen-Bewertungen (0..1) für einen Platz, abhängig davon,
  /// wo Tafel, Fenster und Ausgang im Raum liegen.
  _ZoneScores _zonesFor(Seat seat) {
    if (_seats.isEmpty) return _ZoneScores(0, 0, 0, 0, 0);
    final front = _proximity(seat, _layout.boardSide); // nah an der Tafel
    final back = 1 - front;
    final window = _proximity(seat, _layout.windowSide);
    final aisle = _proximity(seat, _layout.exitSide); // nah am Ausgang/Tür
    // ruhig = weit weg von Tafel UND Ausgang (wenig Durchgangsverkehr)
    final quiet = (back + (1 - aisle)) / 2;
    return _ZoneScores(front, back, window, aisle, quiet);
  }

  /// Wie gut passt [seat] zu den Vorlieben von [student] (höher = besser)?
  double _preferenceScore(Student student, Seat seat) {
    final z = _zonesFor(seat);
    double score = 0;
    for (final c in student.constraints) {
      switch (c.type) {
        case ConstraintType.preferFront:
          score += z.front * 3;
          break;
        case ConstraintType.preferBack:
          score += z.back * 3;
          break;
        case ConstraintType.preferWindow:
          score += z.window * 3;
          break;
        case ConstraintType.preferAisle:
          score += z.aisle * 3;
          break;
        case ConstraintType.needsQuiet:
          score += z.quiet * 2;
          break;
        case ConstraintType.notNextTo:
          break; // wird als harte Regel bei Nachbarn geprüft
      }
    }
    return score;
  }

  /// IDs der Schüler, neben denen [student] nicht sitzen darf (beidseitig).
  Set<String> _forbiddenNeighbors(Student student) {
    final set = <String>{};
    for (final c in student.constraints) {
      if (c.type == ConstraintType.notNextTo && c.targetStudentId != null) {
        set.add(c.targetStudentId!);
      }
    }
    // auch umgekehrt: wenn ein anderer "nicht neben mir" gesetzt hat
    for (final other in classroom.students) {
      if (other.id == student.id) continue;
      for (final c in other.constraints) {
        if (c.type == ConstraintType.notNextTo &&
            c.targetStudentId == student.id) {
          set.add(other.id);
        }
      }
    }
    return set;
  }

  // ---- Auto-Zuweisung ----------------------------------------------------

  /// Verteilt alle Schüler auf die Plätze. Belegt vorhandene Seats neu.
  /// Gibt die aktualisierte Sitzordnung (mit gesetzten studentId) zurück.
  SeatingLayout assign() {
    // Plätze leeren
    for (final s in _seats) {
      s.studentId = null;
    }
    final seatCount = _seats.length;
    if (seatCount == 0) return _layout;

    // Schüler nach "Schwierigkeit" sortieren: erst die mit harten Regeln,
    // dann die mit Zonen-Wünschen, zuletzt die freien.
    final students = [...classroom.students];
    students.sort((a, b) {
      int score(Student s) {
        var v = 0;
        for (final c in s.constraints) {
          v += c.type == ConstraintType.notNextTo ? 3 : 1;
        }
        return v;
      }

      return score(b).compareTo(score(a));
    });

    final placement = <String, String>{}; // studentId -> seatId
    final occupant = <String, String>{}; // seatId -> studentId

    bool place(Student s) {
      final forbidden = _forbiddenNeighbors(s);
      // Kandidaten-Plätze nach Vorliebe sortieren
      final free = _seats.where((seat) => !occupant.containsKey(seat.id));
      // erst mischen, dann stabil nach Vorliebe sortieren → gleich gute
      // Plätze variieren bei jedem Durchlauf ("neu würfeln").
      final candidates = free.toList()..shuffle(_rng);
      candidates.sort((a, b) =>
          _preferenceScore(s, b).compareTo(_preferenceScore(s, a)));
      for (final seat in candidates) {
        // harte Regel: kein verbotener Nachbar bereits platziert
        final clash = _seats.any((other) =>
            occupant.containsKey(other.id) &&
            forbidden.contains(occupant[other.id]) &&
            _areNeighbors(seat, other));
        if (!clash) {
          placement[s.id] = seat.id;
          occupant[seat.id] = s.id;
          return true;
        }
      }
      return false;
    }

    // Greedy mit begrenztem Backtracking
    final unplaced = <Student>[];
    for (final s in students.take(seatCount)) {
      if (!place(s)) unplaced.add(s);
    }
    // Übriggebliebene auf irgendeinen freien Platz (Regel nicht erfüllbar)
    for (final s in unplaced) {
      final seat = _seats.firstWhere(
        (seat) => !occupant.containsKey(seat.id),
        orElse: () => _seats.first,
      );
      placement[s.id] = seat.id;
      occupant[seat.id] = s.id;
    }

    // Ergebnis in die Seats schreiben
    for (final seat in _seats) {
      seat.studentId = occupant[seat.id];
    }
    return _layout;
  }

  // ---- Validierung bestehender Anordnung ---------------------------------

  /// Prüft die aktuelle Belegung und liefert alle Regel-Verstöße.
  List<Conflict> validate() {
    final conflicts = <Conflict>[];
    final seatByStudent = <String, Seat>{};
    for (final seat in _seats) {
      if (seat.studentId != null) seatByStudent[seat.studentId!] = seat;
    }

    for (final student in classroom.students) {
      final seat = seatByStudent[student.id];
      if (seat == null) continue;
      final z = _zonesFor(seat);
      final fallbackIdx = classroom.students.indexOf(student);
      final name = student.displayName(fallbackIdx);

      for (final c in student.constraints) {
        switch (c.type) {
          case ConstraintType.notNextTo:
            final target = classroom.studentById(c.targetStudentId);
            final tSeat =
                target == null ? null : seatByStudent[target.id];
            if (tSeat != null && _areNeighbors(seat, tSeat)) {
              final tIdx = classroom.students.indexOf(target!);
              conflicts.add(Conflict(student.id,
                  '$name sitzt neben ${target.displayName(tIdx)}'));
            }
            break;
          case ConstraintType.preferFront:
            if (z.front < 0.34) {
              conflicts
                  .add(Conflict(student.id, '$name sitzt nicht vorne'));
            }
            break;
          case ConstraintType.preferBack:
            if (z.back < 0.34) {
              conflicts
                  .add(Conflict(student.id, '$name sitzt nicht hinten'));
            }
            break;
          case ConstraintType.preferWindow:
            if (z.window < 0.34) {
              conflicts.add(
                  Conflict(student.id, '$name sitzt nicht am Fenster'));
            }
            break;
          case ConstraintType.preferAisle:
            if (z.aisle < 0.34) {
              conflicts.add(
                  Conflict(student.id, '$name sitzt nicht am Gang'));
            }
            break;
          case ConstraintType.needsQuiet:
            break; // weicher Wunsch, kein harter Verstoß
        }
      }
    }
    return conflicts;
  }
}

class _ZoneScores {
  final double front, back, window, aisle, quiet;
  _ZoneScores(this.front, this.back, this.window, this.aisle, this.quiet);
}
