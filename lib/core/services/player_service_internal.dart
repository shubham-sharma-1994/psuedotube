import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audioplayers/audioplayers.dart' as audio_players;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import '../utils/palette_generator.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/queued_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import 'player_service.dart';
import 'audio_url_service.dart';

mixin PlayerServiceInternal {
  final Lock _playlistLock = Lock();

  PlayerProvider get playerProvider;
  QueueProvider get queueProvider;
  DownloadProvider get downloadProvider;
  AudioPlayer? get justAudioPlayer;
  audio_players.AudioPlayer? get audioPlayer;
  YoutubeExplode get yt;
  ValueNotifier<bool> get isFetchingStreamUrlNotifier;
  ValueNotifier<Color> get backgroundColorNotifier;
  ConcatenatingAudioSource? get playlist;
  set playlist(ConcatenatingAudioSource? value);
  int get playlistStartIndex;
  set playlistStartIndex(int value);
  bool get isPreloading;
  set isPreloading(bool value);
  Timer? get sleepTimer;
  set sleepTimer(Timer? value);
  DateTime? get sleepTimerEnd;
  set sleepTimerEnd(DateTime? value);
  ValueNotifier<Duration?> get sleepTimerRemaining;

  bool get isExplicitlySettingSong;
  set isExplicitlySettingSong(bool value);

  late final AudioUrlService _audioUrlService;

  void initializeAudioUrlService() {
    _audioUrlService = AudioUrlService(downloadProvider);
  }

  PlayerState mapAudioPlayersState(audio_players.PlayerState state) {
    switch (state) {
      case audio_players.PlayerState.playing:
        return PlayerState(true, ProcessingState.ready);
      case audio_players.PlayerState.paused:
        return PlayerState(false, ProcessingState.ready);
      case audio_players.PlayerState.completed:
        return PlayerState(false, ProcessingState.completed);
      case audio_players.PlayerState.stopped:
        return PlayerState(false, ProcessingState.idle);
      default:
        return PlayerState(false, ProcessingState.ready);
    }
  }

  Future<String?> getAudioUrl(
    SongInfo song, {
    bool isPreloading = false,
    Completer<bool>? completer,
  }) async {
    if (!isPreloading) {
      isFetchingStreamUrlNotifier.value = true;
    }
    try {
      final result = await _audioUrlService.getAudioUrl(
        song,
        isPreloading: isPreloading,
        completer: completer,
      );
      return result?['url'] as String?;
    } finally {
      if (!isPreloading) {
        isFetchingStreamUrlNotifier.value = false;
      }
    }
  }

  Future<AudioSource?> createAudioSource(
    SongInfo song, {
    bool isPreloading = false,
    Completer<bool>? completer,
  }) async {
    if (!isPreloading) {
      isFetchingStreamUrlNotifier.value = true;
    }
    try {
      return await _audioUrlService.createAudioSource(
        song,
        isPreloading: isPreloading,
        completer: completer,
      );
    } finally {
      if (!isPreloading) {
        isFetchingStreamUrlNotifier.value = false;
      }
    }
  }

  Future<void> preloadNextSong({Completer<bool>? completer}) async {
    if (!Platform.isAndroid || playlist == null) return;

    await _playlistLock.synchronized(() async {
      try {
        final queue = queueProvider.queue;
        final currentQueueIndex = queueProvider.currentIndex;

        final desiredLastQueueIndex = (currentQueueIndex + 1).clamp(
          0,
          queue.length - 1,
        );

        if (playlist == null) return;
        final lastLoadedQueueIndex = playlistStartIndex + playlist!.length - 1;

        if (desiredLastQueueIndex > lastLoadedQueueIndex) {
          for (
            int i = lastLoadedQueueIndex + 1;
            i <= desiredLastQueueIndex;
            i++
          ) {
            if (completer != null && completer.isCompleted) {
              throw CanceledException('Preloading next songs cancelled');
            }

            final currentQueue = queueProvider.queue;
            if (i < 0 || i >= currentQueue.length) {
              debugPrint(
                'Skipping preload next song: index $i out of range (0..${currentQueue.length - 1})',
              );
              break;
            }
            final songToPreload = currentQueue[i];
            final exists =
                playlist?.children.any(
                  (s) => (s as UriAudioSource).tag.id == songToPreload.videoId,
                ) ??
                false;
            if (!exists) {
              final audioSource = await createAudioSource(
                songToPreload,
                isPreloading: true,
                completer: completer,
              );
              if (audioSource != null && playlist != null) {
                await playlist!.add(audioSource);
                debugPrint(
                  'Preloaded next song: ${songToPreload.name} (${i + 1 - currentQueueIndex} ahead)',
                );
              }
            }
          }
        }
      } on CanceledException {
        debugPrint('Preloading next songs was cancelled.');
      } catch (e) {
        debugPrint('Error preloading next songs: $e');
      } finally {
        isPreloading = false;
      }
    });
  }

  Future<void> syncQueueIndex(int playlistIndex) async {
    if (!Platform.isAndroid) return;
    if (isExplicitlySettingSong) return;

    if (queueProvider.playlistId == 'local_music' ||
        playerProvider.currentLocalSong != null) {
      final newQueueIndex = playlistIndex;

      if (newQueueIndex >= 0 && newQueueIndex < queueProvider.queue.length) {
        if (queueProvider.currentIndex != newQueueIndex) {
          debugPrint(
            'Syncing local song queue index from playlist index $playlistIndex to queue index $newQueueIndex',
          );

          final localSongs =
              playerProvider.currentLocalSong?['queue']
                  as List<Map<String, dynamic>>?;
          if (localSongs != null && newQueueIndex < localSongs.length) {
            final newLocalSong = localSongs[newQueueIndex];
            playerProvider.updateCurrentLocalSong(newLocalSong);
            await updateBackgroundColor(newLocalSong['thumbnail'] ?? '');
          }
        }
      }
      return;
    }

    final newQueueIndex = playlistStartIndex + playlistIndex;

    if (newQueueIndex >= 0 && newQueueIndex < queueProvider.queue.length) {
      if (queueProvider.currentIndex != newQueueIndex) {
        debugPrint(
          'Syncing online song queue index from playlist index $playlistIndex to queue index $newQueueIndex',
        );

        final newSong = queueProvider.queue[newQueueIndex];
        playerProvider.setCurrentSong(newSong);
        await updateBackgroundColor(newSong.thumbnails.first.url);
      }
    }
  }

  Future<bool> updatePlaylist(
    SongInfo currentPlayingSong, {
    Completer<bool>? completer,
  }) async {
    return await _playlistLock.synchronized(() async {
      if (!Platform.isAndroid) return false;

      if (completer != null && completer.isCompleted) {
        throw CanceledException('Playlist update cancelled before start');
      }

      final queue = queueProvider.queue;
      if (queue.isEmpty) {
        await justAudioPlayer!.setAudioSource(
          ConcatenatingAudioSource(children: []),
        );
        playlist = null;
        return false;
      }

      if (queue.length == 1) {
        final audioSource = await createAudioSource(
          queue.first,
          isPreloading: false,
          completer: completer,
        );
        if (audioSource != null) {
          await justAudioPlayer!.setAudioSource(audioSource);
          playlist = null;
          return true;
        }
        return false;
      }

      int actualStartIndex = queue.indexWhere(
        (s) => s.videoId == currentPlayingSong.videoId,
      );
      if (actualStartIndex == -1) {
        actualStartIndex = queueProvider.currentIndex;
        if (actualStartIndex == -1) actualStartIndex = 0;
      }

      final currentSongSource = await createAudioSource(
        currentPlayingSong,
        isPreloading: false,
        completer: completer,
      );
      if (currentSongSource == null) {
        debugPrint(
          'Could not create audio source for ${currentPlayingSong.name}',
        );
        return false;
      }

      final List<AudioSource> initialChildren = [currentSongSource];

      if (completer != null && completer.isCompleted) {
        throw CanceledException(
          'Playlist update cancelled before setting audio source',
        );
      }

      playlist = ConcatenatingAudioSource(children: initialChildren);

      playlistStartIndex = actualStartIndex;

      await justAudioPlayer!.setAudioSource(playlist!, initialIndex: 0);

      _startContinuousPreloading(completer: completer);
      return true;
    });
  }

  void _startContinuousPreloading({Completer<bool>? completer}) {
    Future.microtask(() async {
      try {
        await preloadNextSong(completer: completer);
      } catch (e) {
        debugPrint('Error in continuous preloading: $e');
      }
    });
  }

  void maintainPreloadingBuffer({Completer<bool>? completer}) {
    _startContinuousPreloading(completer: completer);
  }

  Future<void> insertSongIntoPlaylist(int queueIndex, SongInfo song) async {
    if (!Platform.isAndroid || playlist == null) return;

    await _playlistLock.synchronized(() async {
      final existingIndex = playlist!.children.indexWhere(
        (s) => (s as UriAudioSource).tag.id == song.videoId,
      );

      if (existingIndex != -1) {
        await playlist!.removeAt(existingIndex);
        if (existingIndex < queueIndex - playlistStartIndex) {
          queueIndex--;
        }
      }

      final playlistInsertIndex = queueIndex - playlistStartIndex;
      final audioSource = await createAudioSource(song, isPreloading: true);

      if (audioSource != null) {
        if (playlistInsertIndex <= playlist!.length) {
          await playlist!.insert(playlistInsertIndex, audioSource);
        } else {
          await playlist!.add(audioSource);
        }
      }
    });
  }

  Future<void> moveSongInPlaylist(int fromQueueIndex, int toQueueIndex) async {
    if (!Platform.isAndroid || playlist == null) return;

    await _playlistLock.synchronized(() async {
      final fromPlaylistIndex = fromQueueIndex - playlistStartIndex;
      final toPlaylistIndex = toQueueIndex - playlistStartIndex;

      if (fromPlaylistIndex >= 0 &&
          fromPlaylistIndex < playlist!.length &&
          toPlaylistIndex >= 0 &&
          toPlaylistIndex <= playlist!.length) {
        final audioSource = playlist!.children[fromPlaylistIndex];
        await playlist!.removeAt(fromPlaylistIndex);
        await playlist!.insert(toPlaylistIndex, audioSource);
      }
    });
  }

  Future<void> removeFromPlaylist(int queueIndex) async {
    if (!Platform.isAndroid || playlist == null) return;

    await _playlistLock.synchronized(() async {
      final playlistIndex = queueIndex - playlistStartIndex;

      if (playlistIndex >= 0 && playlistIndex < playlist!.length) {
        await playlist!.removeAt(playlistIndex);
      }
    });
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

  Future<void> updateBackgroundColor(String? thumbnailUrl) async {
    final color = await ColorPaletteService.generatePalette(thumbnailUrl ?? '');
    backgroundColorNotifier.value = color;
  }

  Future<Uri> getDefaultArtworkUri() async {
    try {
      final byteData = await rootBundle.load('assets/default_artwork.png');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/default_artwork.png');
      if (!await tempFile.exists()) {
        await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      }
      return Uri.file(tempFile.path);
    } catch (e) {
      return Uri.parse(
        'https://dummyimage.com/600x400/ff0000/ffffff&text=Artwork',
      );
    }
  }

  Future<void> fadeAndStop({
    int steps = 8,
    Duration stepDelay = const Duration(milliseconds: 200),
    required Future<void> Function() pauseFunction,
  }) async {
    try {
      double vol = 1.0;
      for (int i = 0; i < steps; i++) {
        vol = (vol * (steps - i - 1) / (steps - i)).clamp(0.0, 1.0);
        if (Platform.isAndroid && justAudioPlayer != null) {
          await justAudioPlayer!.setVolume(vol);
        } else if (audioPlayer != null) {
          await audioPlayer!.setVolume(vol);
        }
        await Future.delayed(stepDelay);
      }
    } catch (_) {}
    await pauseFunction();
    if (Platform.isAndroid && justAudioPlayer != null) {
      await justAudioPlayer!.setVolume(1.0);
    } else if (audioPlayer != null) {
      await audioPlayer!.setVolume(1.0);
    }
  }

  Future<void> restoreSleepTimerIfNeeded({
    required Future<void> Function(Duration duration, {bool fade})
    startSleepTimerFunction,
    required Future<void> Function() pauseFunction,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('sleep_timer_end');
    final fade = prefs.getBool('sleep_timer_fade') ?? false;
    if (ts != null) {
      final end = DateTime.fromMillisecondsSinceEpoch(ts);
      final remaining = end.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        await prefs.remove('sleep_timer_end');
        await prefs.remove('sleep_timer_fade');
        if (fade) {
          await fadeAndStop(pauseFunction: pauseFunction);
        } else {
          await pauseFunction();
        }
      } else {
        await startSleepTimerFunction(remaining, fade: fade);
      }
    }
  }
}
