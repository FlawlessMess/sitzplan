import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'local_store.dart';

LocalStore createStore() => _IoStore();

/// Speicherung als JSON-Datei im App-Dokumentenordner (iOS, Android, Desktop).
class _IoStore implements LocalStore {
  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/classrooms.json');
  }

  @override
  Future<String?> read() async {
    final file = await _file;
    if (await file.exists()) return file.readAsString();
    return null;
  }

  @override
  Future<void> write(String data) async {
    final file = await _file;
    await file.writeAsString(data);
  }
}
