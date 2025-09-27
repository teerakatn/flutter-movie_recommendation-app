import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local favorites persistence using SharedPreferences
class FavoritesService {
  static final FavoritesService I = FavoritesService._();
  FavoritesService._();

  static const _key = 'favorites_movie_ids_v1';
  final Set<int> _ids = <int>{};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      try {
        final list = (json.decode(jsonStr) as List).cast<int>();
        _ids..clear()..addAll(list);
      } catch (_) {
        // ignore parse errors
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(_ids.toList()));
  }

  Set<int> all() => Set<int>.from(_ids);

  bool contains(int id) => _ids.contains(id);

  Future<void> add(int id) async {
    await load();
    if (_ids.add(id)) {
      await _save();
    }
  }

  Future<void> remove(int id) async {
    await load();
    if (_ids.remove(id)) {
      await _save();
    }
  }

  Future<bool> toggle(int id) async {
    await load();
    bool now;
    if (_ids.contains(id)) {
      _ids.remove(id);
      now = false;
    } else {
      _ids.add(id);
      now = true;
    }
    await _save();
    return now;
  }
}
