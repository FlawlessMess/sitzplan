import 'dart:html' as html;
import 'local_store.dart';

LocalStore createStore() => _WebStore();

/// Speicherung im Browser-localStorage (Web-Vorschau).
class _WebStore implements LocalStore {
  static const _key = 'sitzplan_classrooms';

  @override
  Future<String?> read() async => html.window.localStorage[_key];

  @override
  Future<void> write(String data) async {
    html.window.localStorage[_key] = data;
  }
}
