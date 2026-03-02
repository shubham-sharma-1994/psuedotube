import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../../features/search/data/search_screen_services.dart';

class SettingsProvider with ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const String _audioQualityKey = 'audioQuality';
  static const String _headsetControlsKey = 'headsetControls';
  static const String _themeKey = 'theme';
  static const String _notificationsKey = 'notifications';
  static const String _languageKey = 'language';
  static const String _accentColorKey = 'accentColor';
  static const String _lyricsProviderKey = 'lyricsProvider';
  static const String _geminiApiKey = 'geminiApiKey';
  static const String _openAiApiKey = 'openAiApiKey';
  static const String _aiProviderKey = 'aiProvider';
  static const String _progressBarStyleKey = 'progressBarStyle';

  static const String _animationTypeKey = 'animationType';
  static const String _selectedCountryPlaylistIdKey =
      'selectedCountryPlaylistId';
  static const String _isGridViewKey = 'isGridView';
  static const String _sleepTimerFadeKey = 'sleepTimerFade';
  static const String _maxConcurrentDownloadsKey = 'maxConcurrentDownloads';

  static const String _includedFoldersKey = 'includedFolders';
  static const String _excludedFoldersKey = 'excludedFolders';
  static const String _minSongDurationKey = 'minSongDuration';
  static const String _includedExtensionsKey = 'includedExtensions';
  static const String _excludedExtensionsKey = 'excludedExtensions';

  static const String _adaptiveColorKey = 'adaptiveColor';
  static const String _backupAccentColorKey = 'backupAccentColor';
  static const String _updateChannelKey = 'updateChannel';

  static const String _jioSaavnEnabledKey = 'jioSaavnEnabled';

  static const String _loggingOnStartupKey = 'loggingOnStartup';
  static const String _volumeLevelKey = 'volumeLevel';

  String _streamingQuality = 'High';
  String _downloadingQuality = 'High';
  bool _playbackHistoryEnabled = true;
  bool _searchHistoryEnabled = true;

  bool _jioSaavnEnabled = true;

  String _lyricsProvider = 'LRCLib';
  String? _geminiApiKeyValue;
  String? _openAiApiKeyValue;
  String _aiProvider = 'Gemini';

  String _audioQuality = 'High';
  bool _headsetControlsEnabled = true;
  String _theme = 'Dark';
  bool _notificationsEnabled = true;
  String _language = 'English';
  Color _accentColor = MainScreenColors.skyBlue; // default accent
  String _progressBarStyle = 'Default';

  String _animationType = 'Animation 1';
  bool _isGridView = true;

  String? _selectedCountryPlaylistId;
  bool _adaptiveColorEnabled = false;
  int? _backupAccentColorValue;

  bool _sleepTimerFadeEnabled = false;
  int _maxConcurrentDownloads = 1;
  String _updateChannel = 'stable';

  bool _loggingOnStartup = true;
  double _volumeLevel = 1.0;

  List<String> _includedFolders = [];
  List<String> _excludedFolders = [];
  int _minSongDuration = 0;
  List<String> _includedExtensions = ['.mp3', '.m4a', '.wav', '.flac', '.ogg'];
  List<String> _excludedExtensions = [];
  String get audioQuality => _audioQuality;
  bool get sleepTimerFadeEnabled => _sleepTimerFadeEnabled;
  bool get headsetControlsEnabled => _headsetControlsEnabled;
  String get theme => _theme;
  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;
  Color get accentColor => _accentColor;
  bool get isGridView => _isGridView;

  List<String> get includedFolders => _includedFolders;
  List<String> get excludedFolders => _excludedFolders;
  int get minSongDuration => _minSongDuration;
  List<String> get includedExtensions => _includedExtensions;
  List<String> get excludedExtensions => _excludedExtensions;

  bool get adaptiveColorEnabled => _adaptiveColorEnabled;

  String? get selectedCountryPlaylistId => _selectedCountryPlaylistId;

  String get streamingQuality => _streamingQuality;
  String get downloadingQuality => _downloadingQuality;
  bool get playbackHistoryEnabled => _playbackHistoryEnabled;
  bool get searchHistoryEnabled => _searchHistoryEnabled;
  bool get jioSaavnEnabled => _jioSaavnEnabled;
  String get lyricsProvider => _lyricsProvider;
  String get progressBarStyle => _progressBarStyle;

  String get animationType => _animationType;
  String? get geminiApiKeyValue => _geminiApiKeyValue;
  String? get openAiApiKeyValue => _openAiApiKeyValue;
  String get aiProvider => _aiProvider;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  String get updateChannel => _updateChannel;

  bool get loggingOnStartup => _loggingOnStartup;
  double get volumeLevel => _volumeLevel;

  ThemeMode get themeMode {
    switch (_theme) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      case 'System Default':
        final brightness = WidgetsBinding.instance.window.platformBrightness;
        return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  set audioQuality(String value) {
    _audioQuality = value;
    _saveToPrefs(_audioQualityKey, value);
    notifyListeners();
  }

  set headsetControlsEnabled(bool value) {
    _headsetControlsEnabled = value;
    _saveToPrefs(_headsetControlsKey, value);
    notifyListeners();
  }

  set theme(String value) {
    _theme = value;
    _saveToPrefs(_themeKey, value);
    notifyListeners();
  }

  set notificationsEnabled(bool value) {
    _notificationsEnabled = value;
    _saveToPrefs(_notificationsKey, value);
    notifyListeners();
  }

  set streamingQuality(String value) {
    _streamingQuality = value;
    _saveToPrefs('streamingQuality', value);
    notifyListeners();
  }

  set downloadingQuality(String value) {
    _downloadingQuality = value;
    _saveToPrefs('downloadingQuality', value);
    notifyListeners();
  }

  set playbackHistoryEnabled(bool value) {
    _playbackHistoryEnabled = value;
    _saveToPrefs('playbackHistoryEnabled', value);
    notifyListeners();
  }

  set searchHistoryEnabled(bool value) {
    _searchHistoryEnabled = value;
    _saveToPrefs('searchHistoryEnabled', value);
    notifyListeners();
  }

  set jioSaavnEnabled(bool value) {
    _jioSaavnEnabled = value;
    _saveToPrefs(_jioSaavnEnabledKey, value);
    notifyListeners();
  }

  set lyricsProvider(String value) {
    _lyricsProvider = value;
    _saveToPrefs(_lyricsProviderKey, value);
    notifyListeners();
  }

  set progressBarStyle(String value) {
    _progressBarStyle = value;
    _saveToPrefs(_progressBarStyleKey, value);
    notifyListeners();
  }

  set animationType(String value) {
    _animationType = value;
    _saveToPrefs(_animationTypeKey, value);
    notifyListeners();
  }

  set geminiApiKeyValue(String? value) {
    _geminiApiKeyValue = value;
    _saveToPrefs(_geminiApiKey, value);
    notifyListeners();
  }

  set openAiApiKeyValue(String? value) {
    _openAiApiKeyValue = value;
    _saveToPrefs(_openAiApiKey, value);
    notifyListeners();
  }

  set aiProvider(String value) {
    _aiProvider = value;
    _saveToPrefs(_aiProviderKey, value);
    notifyListeners();
  }

  set isGridView(bool value) {
    _isGridView = value;
    _saveToPrefs(_isGridViewKey, value);
    notifyListeners();
  }

  set sleepTimerFadeEnabled(bool value) {
    _sleepTimerFadeEnabled = value;
    _saveToPrefs(_sleepTimerFadeKey, value);
    notifyListeners();
  }

  set maxConcurrentDownloads(int value) {
    _maxConcurrentDownloads = value;
    _saveToPrefs(_maxConcurrentDownloadsKey, value);
    notifyListeners();
  }

  set updateChannel(String value) {
    _updateChannel = value;
    _saveToPrefs(_updateChannelKey, value);
    notifyListeners();
  }

  set loggingOnStartup(bool value) {
    _loggingOnStartup = value;
    _saveToPrefs(_loggingOnStartupKey, value);
    notifyListeners();
  }

  set volumeLevel(double value) {
    _volumeLevel = value;
    _saveToPrefs(_volumeLevelKey, value);
    notifyListeners();
  }

  set includedFolders(List<String> value) {
    _includedFolders = value;
    _saveToPrefs(_includedFoldersKey, value);
    notifyListeners();
  }

  set excludedFolders(List<String> value) {
    _excludedFolders = value;
    _saveToPrefs(_excludedFoldersKey, value);
    notifyListeners();
  }

  set minSongDuration(int value) {
    _minSongDuration = value;
    _saveToPrefs(_minSongDurationKey, value);
    notifyListeners();
  }

  set includedExtensions(List<String> value) {
    _includedExtensions = value;
    _saveToPrefs(_includedExtensionsKey, value);
    notifyListeners();
  }

  set excludedExtensions(List<String> value) {
    _excludedExtensions = value;
    _saveToPrefs(_excludedExtensionsKey, value);
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SearchScreenServices.SEARCH_HISTORY_KEY);
    notifyListeners();
  }

  set language(String value) {
    _language = value;
    _saveToPrefs(_languageKey, value);

    final locale = _getLocaleFromLanguage(value);
    EasyLocalization.of(navigatorKey.currentContext!)?.setLocale(locale);

    notifyListeners();
  }

  Locale _getLocaleFromLanguage(String language) {
    switch (language) {
      case 'Hindi':
        return const Locale('hi');
      case 'Spanish':
        return const Locale('es');
      case 'French':
        return const Locale('fr');
      case 'German':
        return const Locale('de');
      case 'Russian':
        return const Locale('ru');
      case 'Ukrainian':
        return const Locale('uk');
      case 'Bengali':
        return const Locale('bn');
      case 'Japanese':
        return const Locale('ja');
      case 'Chinese':
        return const Locale('zh');
      case 'Urdu':
        return const Locale('ur');
      case 'Telugu':
        return const Locale('te');
      case 'Tamil':
        return const Locale('ta');
      case 'Marathi':
        return const Locale('mr');
      case 'English':
      default:
        return const Locale('en');
    }
  }

  set accentColor(Color value) {
    _accentColor = value;
    _saveToPrefs(_accentColorKey, value.value);
    notifyListeners();
  }

  Future<void> setAdaptiveColorEnabled(
    bool value, {
    Color? dynamicColor,
  }) async {
    _adaptiveColorEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adaptiveColorKey, value);

    if (value) {
      _backupAccentColorValue = _accentColor.value;
      await prefs.setInt(_backupAccentColorKey, _backupAccentColorValue!);

      if (dynamicColor != null) {
        _accentColor = dynamicColor;
        await prefs.setInt(_accentColorKey, _accentColor.value);
      }
    } else {
      final backup = prefs.getInt(_backupAccentColorKey);
      if (backup != null) {
        _accentColor = Color(backup);
        await prefs.setInt(_accentColorKey, _accentColor.value);
        _backupAccentColorValue = null;
        await prefs.remove(_backupAccentColorKey);
      }
    }

    notifyListeners();
  }

  Future<void> setSelectedCountryPlaylistId(String value) async {
    _selectedCountryPlaylistId = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCountryPlaylistIdKey, value);
    notifyListeners();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _audioQuality = prefs.getString(_audioQualityKey) ?? 'High';
    _headsetControlsEnabled = prefs.getBool(_headsetControlsKey) ?? true;
    _theme = prefs.getString(_themeKey) ?? 'Dark';
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    _language = prefs.getString(_languageKey) ?? 'English';

    _streamingQuality = prefs.getString('streamingQuality') ?? 'High';
    _downloadingQuality = prefs.getString('downloadingQuality') ?? 'High';
    _playbackHistoryEnabled = prefs.getBool('playbackHistoryEnabled') ?? true;
    _searchHistoryEnabled = prefs.getBool('searchHistoryEnabled') ?? true;
    _jioSaavnEnabled = prefs.getBool(_jioSaavnEnabledKey) ?? true;
    _lyricsProvider = prefs.getString(_lyricsProviderKey) ?? 'LRCLib';
    _progressBarStyle = prefs.getString(_progressBarStyleKey) ?? 'Default';

    _animationType = prefs.getString(_animationTypeKey) ?? 'Animation 1';
    _isGridView = prefs.getBool(_isGridViewKey) ?? true;

    _includedFolders = prefs.getStringList(_includedFoldersKey) ?? [];
    _excludedFolders = prefs.getStringList(_excludedFoldersKey) ?? [];
    _minSongDuration = prefs.getInt(_minSongDurationKey) ?? 0;
    _includedExtensions =
        prefs.getStringList(_includedExtensionsKey) ??
        ['.mp3', '.m4a', '.wav', '.flac', '.ogg'];
    _excludedExtensions = prefs.getStringList(_excludedExtensionsKey) ?? [];

    final accentColorValue = prefs.getInt(_accentColorKey);
    if (accentColorValue != null) {
      _accentColor = Color(accentColorValue);
    } else {
      _accentColor = MainScreenColors.skyBlue;
    }

    _adaptiveColorEnabled = prefs.getBool(_adaptiveColorKey) ?? false;
    _backupAccentColorValue = prefs.getInt(_backupAccentColorKey);

    _selectedCountryPlaylistId = prefs.getString(_selectedCountryPlaylistIdKey);

    _geminiApiKeyValue = prefs.getString(_geminiApiKey);

    _loggingOnStartup = prefs.getBool(_loggingOnStartupKey) ?? true;

    _openAiApiKeyValue = prefs.getString(_openAiApiKey);

    _aiProvider = prefs.getString(_aiProviderKey) ?? 'Gemini';

    _sleepTimerFadeEnabled = prefs.getBool(_sleepTimerFadeKey) ?? false;
    _maxConcurrentDownloads = prefs.getInt(_maxConcurrentDownloadsKey) ?? 1;
    _updateChannel = prefs.getString(_updateChannelKey) ?? 'stable';
    _volumeLevel = prefs.getDouble(_volumeLevelKey) ?? 1.0;

    notifyListeners();
  }

  Future<void> _saveToPrefs<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else if (value == null) {
      await prefs.remove(key);
    }
  }

  void toggleTheme() {
    if (_theme == 'Dark') {
      theme = 'Light';
    } else if (_theme == 'Light') {
      theme = 'Dark';
    } else {
      final currentMode = themeMode;
      theme = currentMode == ThemeMode.dark ? 'Light' : 'Dark';
    }
  }

  void clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
