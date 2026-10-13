import 'package:shared_preferences/shared_preferences.dart';
import 'settings_model.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();
  factory SettingsService() => instance;

  static const String _storageKey = 'smart_sos_app_settings_v1';
  SettingsModel _currentSettings = const SettingsModel();

  SettingsModel get settings => _currentSettings;

  // Load settings with fallback to default configuration
  Future<SettingsModel> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        final defaultSettings = SettingsModel.defaults();
        await saveSettings(defaultSettings);
        _currentSettings = defaultSettings;
        return defaultSettings;
      }
      _currentSettings = SettingsModel.decodeJson(jsonString);
      return _currentSettings;
    } catch (e) {
      _currentSettings = SettingsModel.defaults();
      return _currentSettings;
    }
  }

  // Save full settings object
  Future<bool> saveSettings(SettingsModel settings) async {
    try {
      _currentSettings = settings;
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_storageKey, settings.encodeJson());
    } catch (e) {
      return false;
    }
  }

  // Reset all settings to factory default values without affecting user login or history
  Future<SettingsModel> resetSettings() async {
    final defaultSettings = SettingsModel.defaults();
    await saveSettings(defaultSettings);
    _currentSettings = defaultSettings;
    return defaultSettings;
  }
}
