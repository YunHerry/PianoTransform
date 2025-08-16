import 'dart:ffi';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

class SettingsManager {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();
  late String _themeColor;
  late double _volume;
  double get volume => _volume;
  late final SharedPreferences sharedPreferences;
    Future<void> init() async {
      sharedPreferences = await SharedPreferences.getInstance();
      _themeColor = sharedPreferences.getString("themeColor") ?? "follow";
      _volume =  sharedPreferences.getDouble("volume") ?? 0;
    }
    void setDouble(String key,double value) {
      sharedPreferences.setDouble(key, value);
      _volume = value;
    }
}