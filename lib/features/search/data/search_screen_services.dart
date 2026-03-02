import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Thumbnail;

import '../../../core/models/song_model.dart';
import '../../../core/services/related_song_service.dart';
import '../../../core/services/yt-music-api.dart' as ytApi;

enum SearchMode { youtubeMusic, youtube }

class SearchScreenServices {
  final YTMusic _ytMusic = GetIt.I<YTMusic>();
  final YoutubeExplode _yt = GetIt.I<YoutubeExplode>();
  final RelatedSongService _relatedSongService = RelatedSongService();

  final ValueNotifier<bool> isLoadingRelatedSongsNotifier = ValueNotifier(
    false,
  );

  static const String SEARCH_HISTORY_KEY = 'search_history';
  static const String SEARCH_HISTORY_ENABLED_KEY = 'searchHistoryEnabled';

  Future<List<String>> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(SEARCH_HISTORY_ENABLED_KEY) ?? true;
    if (!isEnabled) return [];
    return prefs.getStringList(SEARCH_HISTORY_KEY) ?? [];
  }

  Future<void> saveSearchHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(SEARCH_HISTORY_ENABLED_KEY) ?? true;
    if (isEnabled) {
      await prefs.setStringList(SEARCH_HISTORY_KEY, history);
    }
  }

  Future<List<String>> addToSearchHistory(
    List<String> history,
    String query,
  ) async {
    if (query.trim().isEmpty) return history;

    final updatedHistory = List<String>.from(history)
      ..remove(query)
      ..insert(0, query);

    if (updatedHistory.length > 10) {
      updatedHistory.removeRange(10, updatedHistory.length);
    }

    await saveSearchHistory(updatedHistory);
    return updatedHistory;
  }

  Future<List<String>> removeFromSearchHistory(
    List<String> history,
    String query,
  ) async {
    final updatedHistory = List<String>.from(history)..remove(query);
    await saveSearchHistory(updatedHistory);
    return updatedHistory;
  }

  Future<List<dynamic>> fetchQuickSongs(String query) async {
    try {
      final songs = await _ytMusic.searchSongs(query);
      return songs.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> fetchSearchSuggestions(
    String query,
    SearchMode mode,
  ) async {
    if (query.trim().isEmpty) return [];

    try {
      if (mode == SearchMode.youtube) {
        if (query.length < 3) return [];
        final suggestions = await _yt.search.getQuerySuggestions(query);
        return suggestions.take(5).toList();
      } else {
        final suggestions = await _ytMusic.getSearchSuggestions(query);
        return suggestions.take(5).toList();
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> fetchYouTubeVideos(String query) async {
    if (query.isEmpty) return [];

    try {
      final results = await _yt.search.search(query, filter: TypeFilters.video);
      return results.take(20).toList();
    } catch (e) {
      print('Error fetching YouTube videos: $e');
      return [];
    }
  }

  Future<Map<String, List<dynamic>>> performSearch(
    String query,
    SearchMode mode,
  ) async {
    if (query.trim().isEmpty) {
      if (mode == SearchMode.youtube) {
        return {'Videos': []};
      } else {
        return {'Songs': [], 'Albums': [], 'Artists': [], 'Playlists': []};
      }
    }

    if (mode == SearchMode.youtube) {
      final videos = await fetchYouTubeVideos(query);
      return {'Videos': videos};
    } else {
      final results = await Future.wait([
        _ytMusic.searchSongs(query),
        _ytMusic.searchAlbums(query),
        _ytMusic.searchArtists(query),
        _ytMusic.searchPlaylists(query),
      ]);

      return {
        'Songs': results[0],
        'Albums': results[1],
        'Artists': results[2],
        'Playlists': results[3],
      };
    }
  }

  Future<void> playSong(
    dynamic song,
    dynamic playerProvider,
    dynamic queueProvider,
  ) async {
    try {
      isLoadingRelatedSongsNotifier.value = true;

      final songInfo = SongInfo(
        videoId: song.videoId,
        name: song.name,
        artists: [
          Artist(name: song.artist.name, id: song.artist.artistId ?? ''),
        ],
        thumbnails: (song.thumbnails as List)
            .map((t) => Thumbnail(url: t.url, width: t.width, height: t.height))
            .toList(),
        duration: Duration(seconds: song.duration ?? 0),
      );

      List<SongInfo> songsList;
      dynamic isYouTube;
      try {
        isYouTube = song.isYouTube;
      } catch (e) {
        isYouTube = false;
      }
      if (isYouTube) {
        // YouTube
        songsList = await _relatedSongService.createSongListWithRelated(
          songInfo,
          song.videoId,
        );
      } else {
        // YouTube Music
        final radioData = await ytApi.getRadioSongs(song.videoId);
        final tracks = radioData['tracks'] as List;
        songsList = tracks.map((track) {
          final trackArtists = track['artists'] as List?;
          final thumbnails = track['thumbnails'] as List?;
          return SongInfo(
            videoId: track['videoId'] ?? '',
            name: track['title'] ?? 'Unknown Title',
            artists:
                trackArtists
                    ?.map(
                      (a) => Artist(
                        name: a['name'] ?? 'Unknown Artist',
                        id: a['id'] ?? '',
                      ),
                    )
                    ?.toList() ??
                [Artist(name: 'Unknown Artist', id: '')],
            thumbnails: [
              Thumbnail(
                url: (thumbnails?.isNotEmpty ?? false)
                    ? (thumbnails!.last['url'] ?? '')
                    : '',
                width: 1280,
                height: 720,
              ),
            ],
            duration: Duration(seconds: track['duration_seconds'] ?? 0),
          );
        }).toList();
      }
      isLoadingRelatedSongsNotifier.value = false;

      final songIndex = songsList.indexWhere((s) => s.videoId == song.videoId);

      queueProvider.setQueue(
        songsList,
        currentIndex: songIndex,
        playlistId: 'search_results',
        playlistName: 'Search Results',
      );
      await playerProvider.playerService.playSong(songInfo);
    } catch (e) {
      throw Exception('Failed to play song: $e');
    }
  }
}
