import '../../settings_model.dart';
import '../../settings_service.dart';

class SettingsRepositoryImpl {
  final SettingsService _service = SettingsService();

  Future<SettingsModel> getSettings() async {
    return await _service.loadSettings();
  }

  Future<bool> saveSettings(SettingsModel settings) async {
    return await _service.saveSettings(settings);
  }

  Future<SettingsModel> resetSettings() async {
    return await _service.resetSettings();
  }
}
