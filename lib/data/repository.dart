import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/classroom.dart';
import 'local_store.dart';

/// Hält alle Klassen im Speicher und persistiert sie als JSON-Datei lokal
/// auf dem Gerät (offline, kein Server). [ChangeNotifier], damit die UI
/// automatisch auf Änderungen reagiert.
class ClassroomRepository extends ChangeNotifier {
  ClassroomRepository._();
  static final ClassroomRepository instance = ClassroomRepository._();

  final List<Classroom> _classrooms = [];
  final LocalStore _store = LocalStore();
  bool _loaded = false;

  List<Classroom> get classrooms => List.unmodifiable(_classrooms);
  bool get isLoaded => _loaded;

  /// Lädt die Klassen beim App-Start.
  Future<void> load() async {
    try {
      final content = await _store.read();
      if (content != null && content.isNotEmpty) {
        final List<dynamic> data = jsonDecode(content) as List<dynamic>;
        _classrooms
          ..clear()
          ..addAll(data.map(
              (e) => Classroom.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      debugPrint('Fehler beim Laden: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final data = _classrooms.map((c) => c.toJson()).toList();
      await _store.write(jsonEncode(data));
    } catch (e) {
      debugPrint('Fehler beim Speichern: $e');
    }
  }

  Future<void> addClassroom(Classroom c) async {
    _classrooms.add(c);
    notifyListeners();
    await _persist();
  }

  /// Nach Änderungen an einer (bereits enthaltenen) Klasse aufrufen.
  Future<void> save(Classroom c) async {
    c.updatedAt = DateTime.now();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteClassroom(Classroom c) async {
    _classrooms.removeWhere((e) => e.id == c.id);
    notifyListeners();
    await _persist();
  }
}
