import 'package:shared_preferences/shared_preferences.dart';

import 'package:avatar/state.dart';

/// The persisted [AvatarSelectionStore], backed by platform preferences.
///
/// Created once in `main` after the binding is ready, so the synchronous
/// [load] below never touches a platform channel: the instance is already
/// hydrated and reads from its in-memory cache.
class SharedPreferencesAvatarSelectionStore implements AvatarSelectionStore {
  SharedPreferencesAvatarSelectionStore(this._prefs);

  static const String key = 'selected_avatar';

  final SharedPreferences _prefs;

  @override
  AvatarType? load() {
    final id = _prefs.getString(key);
    if (id == null) return null;
    return AvatarType.fromId(id);
  }

  @override
  Future<void> save(AvatarType type) => _prefs.setString(key, type.id);
}
