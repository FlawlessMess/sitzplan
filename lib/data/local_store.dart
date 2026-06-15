import 'store_stub.dart'
    if (dart.library.io) 'store_io.dart'
    if (dart.library.html) 'store_web.dart';

/// Plattformneutrale Schnittstelle zum Lesen/Schreiben des gespeicherten
/// JSON-Strings. Die konkrete Implementierung wird per bedingtem Import
/// gewählt (Datei auf iOS/Android/Desktop, localStorage im Web).
abstract class LocalStore {
  Future<String?> read();
  Future<void> write(String data);

  factory LocalStore() => createStore();
}
