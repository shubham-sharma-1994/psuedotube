import 'dart:convert';

import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EqualizerService {
  final AndroidEqualizer equalizer;
  final AndroidLoudnessEnhancer loudnessEnhancer;
  final SharedPreferences prefs;

  static const String _equalizerEnabledKey = 'equalizer_enabled';
  static const String _loudnessEnabledKey = 'loudness_enabled';
  static const String _loudnessGainKey = 'loudness_gain';
  static const String _currentPresetKey = 'current_preset';
  static const String _bandGainsKey = 'band_gains';

  static const Map<String, List<double>> builtInPresets = {
    'Noize': [5.5, 3.0, 0.5, 0.0, 0.0, 0.8],

    'Normal': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],

    'Rock': [4.0, 3.0, -2.0, 1.5, 3.0, 4.0],

    'Pop': [3.5, 2.0, 1.0, 1.0, 2.0, 3.5],

    'Jazz': [2.5, 2.0, 1.0, 0.5, 1.5, 2.5],

    'Classical': [2.0, 1.5, 0.5, -0.5, 1.0, 1.8],

    'Bass Boost': [8.0, 5.0, 2.0, -1.0, -2.0, -2.5],
  };

  static const String _loudnessProfileKey = 'loudness_profile';
  static const Map<String, double> loudnessProfiles = {
    'Low': 10.0,
    'Medium': 20.0,
    'High': 30.0,
  };

  static const String _customPresetsKey = 'custom_presets';

  Map<String, List<double>> _customPresets = {};

  EqualizerService(this.equalizer, this.loudnessEnhancer, this.prefs) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final equalizerEnabled = prefs.getBool(_equalizerEnabledKey) ?? false;
    await setEqualizerEnabled(equalizerEnabled);

    final loudnessEnabled = prefs.getBool(_loudnessEnabledKey) ?? false;
    await setLoudnessEnabled(loudnessEnabled);

    final loudnessProfile = prefs.getString(_loudnessProfileKey) ?? 'High';
    final loudnessGain = prefs.getDouble(_loudnessGainKey) ?? 0.0;
    final maxGain =
        loudnessProfiles[loudnessProfile] ?? loudnessProfiles['High']!;
    await setLoudnessGain(loudnessGain.clamp(0.0, maxGain));

    final customPresetsString = prefs.getString(_customPresetsKey);
    if (customPresetsString != null) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(customPresetsString) as Map<String, dynamic>;
        _customPresets = decoded.map((key, value) {
          final list = (value as List)
              .map((e) => (e as num).toDouble())
              .toList();
          return MapEntry(key, list);
        });
      } catch (_) {
        _customPresets = {};
      }
    }

    final currentPreset = prefs.getString(_currentPresetKey) ?? 'Noize';
    await applyPreset(currentPreset);

    final bandGainsString = prefs.getString(_bandGainsKey);
    if (bandGainsString != null) {
      final bandGains = bandGainsString
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .map((e) => double.parse(e))
          .toList();
      final params = await equalizer.parameters;
      for (var i = 0; i < bandGains.length && i < params.bands.length; i++) {
        await params.bands[i].setGain(bandGains[i]);
      }
    }
  }

  Future<void> _saveSettings() async {
    final params = await equalizer.parameters;
    final bandGains = <double>[];

    for (var band in params.bands) {
      bandGains.add(band.gain);
    }

    await prefs.setString(_bandGainsKey, bandGains.join(','));

    _customPresets['Custom'] = bandGains;
    await prefs.setString(_customPresetsKey, jsonEncode(_customPresets));
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    await equalizer.setEnabled(enabled);
    await prefs.setBool(_equalizerEnabledKey, enabled);
  }

  Future<void> setLoudnessEnabled(bool enabled) async {
    await loudnessEnhancer.setEnabled(enabled);
    await prefs.setBool(_loudnessEnabledKey, enabled);
  }

  Future<void> setLoudnessGain(double gain) async {
    await loudnessEnhancer.setTargetGain(gain);
    await prefs.setDouble(_loudnessGainKey, gain);
  }

  String get loudnessProfile => prefs.getString(_loudnessProfileKey) ?? 'High';

  Future<void> setLoudnessProfile(String profile) async {
    await prefs.setString(_loudnessProfileKey, profile);
    final gain = prefs.getDouble(_loudnessGainKey) ?? 0.0;
    final max = loudnessProfiles[profile] ?? loudnessProfiles['High']!;
    final clamped = gain.clamp(0.0, max);
    await setLoudnessGain(clamped);
  }

  Future<AndroidEqualizerParameters> getEqualizerParameters() async {
    return await equalizer.parameters;
  }

  Future<void> setBandGain(int bandIndex, double gain) async {
    final params = await equalizer.parameters;
    final clampedGain = gain.clamp(params.minDecibels, params.maxDecibels);
    await params.bands[bandIndex].setGain(clampedGain);

    await _saveSettings();
  }

  Future<void> applyPreset(String presetName) async {
    List<double>? gains;
    if (builtInPresets.containsKey(presetName)) {
      gains = builtInPresets[presetName];
    } else if (_customPresets.containsKey(presetName)) {
      gains = _customPresets[presetName];
    }

    if (gains != null) {
      final params = await equalizer.parameters;

      for (var i = 0; i < gains.length && i < params.bands.length; i++) {
        final clampedGain = gains[i].clamp(
          params.minDecibels,
          params.maxDecibels,
        );
        await params.bands[i].setGain(clampedGain);
      }

      await prefs.setString(_currentPresetKey, presetName);
      await _saveSettings();
    }
  }

  String get currentPreset => prefs.getString(_currentPresetKey) ?? 'Noize';

  Future<Map<String, List<double>>> getAllPresets() async {
    return {...builtInPresets, ..._customPresets};
  }

  Future<void> saveCustomPreset(String name, List<double> gains) async {
    _customPresets[name] = gains;
    await prefs.setString(_customPresetsKey, jsonEncode(_customPresets));
  }

  Future<bool> renameCustomPreset(String oldName, String newName) async {
    if (!_customPresets.containsKey(oldName)) return false;
    if (_customPresets.containsKey(newName) ||
        builtInPresets.containsKey(newName)) {
      return false;
    }
    final gains = _customPresets.remove(oldName)!;
    _customPresets[newName] = gains;
    await prefs.setString(_customPresetsKey, jsonEncode(_customPresets));

    final current = prefs.getString(_currentPresetKey);
    if (current == oldName) {
      await prefs.setString(_currentPresetKey, newName);
    }
    return true;
  }

  Future<bool> isCustomPreset(String name) async {
    return _customPresets.containsKey(name);
  }

  static String getFrequencyText(double frequency) {
    if (frequency >= 1000) {
      return '${(frequency / 1000).toStringAsFixed(1)}kHz';
    }
    return '${frequency.round()}Hz';
  }
}
