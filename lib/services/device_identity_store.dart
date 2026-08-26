import 'package:shared_preferences/shared_preferences.dart';

import '../utils/offline_ids.dart';

class DeviceIdentityStore {
  static const _key = 'offline_sync.device_id';

  Future<String> readOrCreate() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = newUuid();
    await preferences.setString(_key, created);
    return created;
  }
}
