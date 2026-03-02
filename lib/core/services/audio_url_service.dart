import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song_model.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/connectivity_provider.dart';
import 'player_service.dart';
import 'audio_url_isolate.dart';

class AudioUrlService {
  final YoutubeExplode _yt = GetIt.I<YoutubeExplode>();
  final DownloadProvider _downloadProvider;

  AudioUrlService(this._downloadProvider);

  Box<String> get audioCacheBox => Hive.box<String>('audio_url_cache');

  ConnectivityProvider? get connectivityProvider {
    try {
      return GetIt.I<ConnectivityProvider>();
    } catch (e) {
      return null;
    }
  }

  int? parseExpiryFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final expireParam = uri.queryParameters['expire'];
      if (expireParam != null) {
        return int.tryParse(expireParam);
      }
    } catch (_) {}
    return null;
  }

  bool isCachedUrlValid(String videoId, {int bufferSeconds = 30}) {
    final jsonStr = audioCacheBox.get(videoId);
    if (jsonStr == null) return false;
    try {
      final Map<String, dynamic> data =
          json.decode(jsonStr) as Map<String, dynamic>;
      final url = data['url'] as String?;
      final expiry = data['expiry'] as int?;
      if (url == null) return false;
      if (expiry == null) return true;
      final nowEpoch = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      return (expiry - bufferSeconds) > nowEpoch;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getAudioUrl(
    SongInfo song, {
    bool isPreloading = false,
    int maxRetries = 1,
    Duration initialDelay = const Duration(seconds: 1),
    Completer<bool>? completer,
  }) async {
    if (completer != null && completer.isCompleted) {
      throw CanceledException('Audio URL fetch cancelled before start');
    }

    final cachedJson = audioCacheBox.get(song.videoId);
    if (cachedJson != null) {
      try {
        final Map<String, dynamic> data =
            json.decode(cachedJson) as Map<String, dynamic>;
        final cachedUrl = data['url'] as String?;
        final expiry = data['expiry'] as int?;
        final cachedDuration = data['duration'] as int?;
        if (cachedUrl != null &&
            (expiry == null || isCachedUrlValid(song.videoId))) {
          debugPrint('Using cached URL for ${song.name} - ${song.videoId}');
          return {'url': cachedUrl, 'duration': cachedDuration};
        } else {
          await audioCacheBox.delete(song.videoId);
        }
      } catch (_) {
        await audioCacheBox.delete(song.videoId);
      }
    }

    if (!(connectivityProvider?.canPerformNetworkOperations() ?? false)) {
      debugPrint(
        'No internet connection - cannot fetch audio URL for ${song.videoId}',
      );
      return null;
    }

    final settingsProvider = GetIt.I<SettingsProvider>();
    final streamingQuality = settingsProvider.streamingQuality;

    debugPrint(
      'Fetching stream URL in isolate for ${song.name} - ${song.videoId} (preloading: $isPreloading)',
    );

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      if (completer != null && completer.isCompleted) {
        throw CanceledException('Audio URL fetch cancelled during retry');
      }

      try {
        final settingsProvider = GetIt.I<SettingsProvider>();
        final result = await AudioUrlIsolate.fetchStreamUrl(
          videoId: song.videoId,
          streamingQuality: streamingQuality,
          timeout: Duration(seconds: isPreloading ? 20 : 20),
          allowCancellation: true,
          title: song.name,
          artist: song.artists.map((a) => a.name).join(', '),
          jioSaavnEnabled: settingsProvider.jioSaavnEnabled,
        );

        if (result['success'] == true) {
          final audioUrl = result['url'] as String;
          final expiry = result['expiry'] as int?;
          final duration = result['duration'] as int?;

          final Map<String, dynamic> storeData = {'url': audioUrl};
          if (expiry != null) storeData['expiry'] = expiry;
          if (duration != null) storeData['duration'] = duration;
          await audioCacheBox.put(song.videoId, json.encode(storeData));

          debugPrint(
            'Successfully fetched stream URL for ${song.name} - ${song.videoId}',
          );
          return {'url': audioUrl, 'duration': duration};
        } else {
          final error = result['error'] as String?;
          throw Exception(error ?? 'Unknown error from isolate');
        }
      } catch (e) {
        debugPrint(
          'Error getting audio URL for ${song.videoId} (attempt ${attempt + 1}): $e',
        );

        if (e is! CanceledException) {
          AudioUrlIsolate.cancelRequest(song.videoId).catchError((_) {});
        }

        if (attempt < maxRetries - 1) {
          final delay = initialDelay * (1 << attempt);
          await Future.delayed(delay);
        }
      }
    }

    debugPrint('All retries failed for ${song.videoId}');
    return null;
  }

  Future<AudioSource?> createAudioSource(
    SongInfo song, {
    bool isPreloading = false,
    Completer<bool>? completer,
  }) async {
    if (completer != null && completer.isCompleted) {
      throw CanceledException('Audio source creation cancelled before start');
    }

    final downloadedPath = await _downloadProvider.getDownloadedSongPath(
      song.videoId,
    );

    if (downloadedPath != null) {
      debugPrint('Creating audio source from downloaded file for ${song.name}');
      return AudioSource.uri(
        Uri.file(downloadedPath),
        tag: MediaItem(
          id: song.videoId,
          album: 'Noize',
          title: song.name,
          artist: song.artists.map((a) => a.name).join(', '),
          artUri: Uri.parse(
            song.thumbnails.isNotEmpty
                ? song.thumbnails.last.url
                : 'https://img.youtube.com/vi/${song.videoId}/mqdefault.jpg',
          ),
          duration: song.duration,
        ),
      );
    }

    final audioData = await getAudioUrl(
      song,
      isPreloading: isPreloading,
      completer: completer,
    );
    if (audioData == null) return null;

    final audioUrl = audioData['url'] as String;
    final streamDuration = audioData['duration'] as int?;

    if (completer != null && completer.isCompleted) {
      throw CanceledException(
        'Audio source creation cancelled after getting URL',
      );
    }

    final usedDuration = streamDuration != null
        ? Duration(milliseconds: streamDuration)
        : song.duration;

    debugPrint(
      'Creating audio source from stream for ${song.name} - ${song.videoId}- $audioUrl',
    );
    debugPrint(
      'Duration: $usedDuration (from ${streamDuration != null ? 'StreamProvider' : 'song metadata'})',
    );

    return AudioSource.uri(
      Uri.parse(audioUrl),
      tag: MediaItem(
        id: song.videoId,
        album: 'Noize',
        title: song.name,
        artist: song.artists.map((a) => a.name).join(', '),
        artUri: Uri.parse(
          song.thumbnails.isNotEmpty
              ? song.thumbnails.last.url
              : 'https://img.youtube.com/vi/${song.videoId}/mqdefault.jpg',
        ),
        duration: usedDuration,
      ),
    );
  }

  AudioOnlyStreamInfo getStreamQuality(StreamManifest manifest) {
    final settingsProvider = GetIt.I<SettingsProvider>();
    final streamInfos = manifest.audioOnly
        .where((stream) => stream.container == StreamContainer.mp4)
        .sortByBitrate()
        .reversed
        .toList();

    switch (settingsProvider.streamingQuality.toLowerCase()) {
      case 'low':
        return streamInfos.first;
      case 'medium':
        return streamInfos[streamInfos.length ~/ 2];
      case 'high':
      default:
        return streamInfos.last;
    }
  }
}
