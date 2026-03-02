import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataManagementService {
  Future<void> clearCache() async {
    final cacheDir = await getTemporaryDirectory();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  Future<void> _clearBox(String boxName) async {
    if (await Hive.boxExists(boxName)) {
      final box = await Hive.openBox<String>(boxName);
      await box.clear();
    }
  }

  Future<void> clearCreatedPlaylists() async =>
      await _clearBox('created_playlists');
  Future<void> clearSavedAlbums() async => await _clearBox('saved_albums');
  Future<void> clearSavedPlaylists() async =>
      await _clearBox('saved_playlists');
  Future<void> clearFavoriteArtists() async =>
      await _clearBox('favorite_artists');
  Future<void> clearLikedSongs() async => await _clearBox('liked_songs');
  Future<void> clearLastPlayed() async => await _clearBox('last_played');
  Future<void> clearQueue() async => await _clearBox('queue_storage');
  Future<void> clearPlaybackStats() async {
    await _clearBox('playback_stats');
    await _clearBox('playback_stats_daily');
    await _clearBox('playback_stats_daily_artist');
  }

  Future<void> clearPlaylistSongs() async => await _clearBox('playlist_songs');
  Future<void> clearAudioUrlCache() async => await _clearBox('audio_url_cache');
  Future<void> clearVideoInfoCache() async =>
      await _clearBox('video_info_cache');

  Future<void> clearRecentplaylists() async =>
      await _clearBox('recent_playlists');

  Future<void> clearRecentPlaylists() async => await clearRecentplaylists();

  Future<void> _clearSharedPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> clearSearchHistory() async =>
      await _clearSharedPreference('search_history');

  Future<void> clearAllHiveData() async {
    await clearCreatedPlaylists();
    await clearSavedAlbums();
    await clearSavedPlaylists();
    await clearFavoriteArtists();
    await clearLikedSongs();
    await clearLastPlayed();
    await clearPlaylistSongs();
    await clearRecentplaylists();
    await clearQueue();
    await clearPlaybackStats();
    await clearAudioUrlCache();
    await clearVideoInfoCache();
  }

  Future<void> clearAllAppData() async {
    await clearAllHiveData();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await clearCache();

    final appDir = await getApplicationSupportDirectory();
    if (await appDir.exists()) {
      await appDir.delete(recursive: true);
    }
  }
}
