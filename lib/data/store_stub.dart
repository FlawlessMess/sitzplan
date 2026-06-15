import 'local_store.dart';

LocalStore createStore() => _MemoryStore();

/// Fallback (kein dart:io / dart:html verfügbar): hält Daten nur im RAM.
class _MemoryStore implements LocalStore {
  String? _data;

  @override
  Future<String?> read() async => _data;

  @override
  Future<void> write(String data) async => _data = data;
}
