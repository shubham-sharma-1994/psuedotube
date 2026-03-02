import 'dart:io';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audioplayers/audioplayers.dart' as audio_players;
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/queued_provider.dart';
import '../providers/download_provider.dart';
import '../providers/stats_provider.dart';
import '../../features/equalizer/presentation/data/services/equalizer_services.dart';
import 'player_service_internal.dart';
import 'audio_url_isolate.dart';
import 'smtc_service.dart';

class CanceledException implements Exception {
  final String message;
  CanceledException([this.message = 'Operation cancelled']);
  @override
  String toString() => 'CanceledException: $message';
}

class PlayerService with PlayerServiceInternal {
  AudioPlayer? _justAudioPlayer = Platform.isAndroid ? AudioPlayer() : null;
  final audio_players.AudioPlayer? _audioPlayer = Platform.isAndroid
      ? null
      : audio_players.AudioPlayer();

  @override
  final PlayerProvider playerProvider;

  @override
  final QueueProvider queueProvider;

  @override
  final DownloadProvider downloadProvider;

  bool isExplicitlySettingSong = false;

  final StatsProvider statsProvider;

  final YoutubeExplode _yt = GetIt.I<YoutubeExplode>();

  late final AndroidEqualizer _equalizer;
  late final AndroidLoudnessEnhancer _loudnessEnhancer;
  late final EqualizerService equalizerService;

  SmtcService? _smtcService;
  Timer? _smtcPositionTimer;

  SmtcService? get smtcService => _smtcService;

  @override
  final ValueNotifier<Color> backgroundColorNotifier = ValueNotifier<Color>(
    Colors.black,
  );

  @override
  final ValueNotifier<bool> isFetchingStreamUrlNotifier = ValueNotifier<bool>(
    false,
  );

  @override
  Timer? sleepTimer;

  @override
  DateTime? sleepTimerEnd;

  @override
  final ValueNotifier<Duration?> sleepTimerRemaining = ValueNotifier(null);

  bool get isSleepTimerActive => sleepTimerEnd != null;

  @override
  ConcatenatingAudioSource? playlist;

  @override
  final Set<String> currentlyFetching = <String>{};

  @override
  bool isPreloading = false;

  @override
  int playlistStartIndex = 0;

  Completer<bool>? _currentPlaybackCompleter;

  Completer<bool>? _currentPreloadCompleter;

  AudioSession? _audioSession;

  bool _wasPlayingBeforeInterruption = false;

  bool _isHandlingCompletion = false;

  void cancelCurrentPlayback() {
    if (_currentPlaybackCompleter != null &&
        !_currentPlaybackCompleter!.isCompleted) {
      _currentPlaybackCompleter!.completeError(
        CanceledException('Playback interrupted by new request'),
      );
      _currentPlaybackCompleter = null;
    }

    AudioUrlIsolate.cancelAllRequests().catchError((e) {
      debugPrint('Error cancelling isolate requests: $e');
    });
  }

  void cancelCurrentPreloading() {
    if (_currentPreloadCompleter != null &&
        !_currentPreloadCompleter!.isCompleted) {
      _currentPreloadCompleter!.completeError(
        CanceledException('Preloading interrupted by new request'),
      );
      _currentPreloadCompleter = null;
    }
  }

  String? _currentStatsSongId;
  String? _currentStatsSongTitle;
  String? _currentStatsSongArtist;
  int? _currentStatsSessionStartPosition;

  @override
  AudioPlayer? get justAudioPlayer => _justAudioPlayer;

  @override
  audio_players.AudioPlayer? get audioPlayer => _audioPlayer;

  @override
  YoutubeExplode get yt => _yt;

  AudioPlayer? get audioPlayerInstance => _justAudioPlayer;

  PlayerService(
    this.playerProvider,
    this.queueProvider,
    this.downloadProvider,
    this.statsProvider,
  ) {
    initializeAudioUrlService();

    if (Platform.isAndroid) {
      _equalizer = AndroidEqualizer();
      _loudnessEnhancer = AndroidLoudnessEnhancer();

      _justAudioPlayer = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [_equalizer, _loudnessEnhancer],
        ),
      );

      SharedPreferences.getInstance().then((prefs) {
        equalizerService = EqualizerService(
          _equalizer,
          _loudnessEnhancer,
          prefs,
        );
        GetIt.I.registerSingleton<EqualizerService>(equalizerService);
      });
    } else {
      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (state == audio_players.PlayerState.playing) {
          isFetchingStreamUrlNotifier.value = false;
        }
      });

      _initSmtc();
    }

    setupPlaybackCompletion();
    _restoreSleepTimerIfNeeded();
    _setupStatsListeners();
    _initializeAudioSession();
    _restoreSavedVolume();
  }

  Future<void> _restoreSavedVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVolume = prefs.getDouble('volumeLevel') ?? 1.0;
    if (Platform.isAndroid) {
      _justAudioPlayer?.setVolume(savedVolume);
    } else {
      _audioPlayer?.setVolume(savedVolume);
    }
  }

  Future<void> _recordCurrentPlaybackEnd() async {
    if (_currentStatsSongId != null &&
        _currentStatsSessionStartPosition != null) {
      final currentPosition = await getCurrentPosition();
      await statsProvider.recordPlayEnd(
        _currentStatsSongId,
        _currentStatsSongTitle,
        _currentStatsSongArtist,
        currentPosition.inSeconds,
      );
      _currentStatsSongId = null;
      _currentStatsSongTitle = null;
      _currentStatsSongArtist = null;
      _currentStatsSessionStartPosition = null;
    }
  }

  void _setupStatsListeners() {
    if (Platform.isAndroid) {
      _justAudioPlayer!.playerStateStream.listen((state) async {
        if (state.playing && state.processingState == ProcessingState.ready) {
          final currentSong = playerProvider.currentSong;
          if (currentSong != null && playerProvider.currentLocalSong == null) {
            _currentStatsSongId = currentSong.videoId;
            _currentStatsSongTitle = currentSong.name;
            _currentStatsSongArtist = currentSong.artists
                .map((a) => a.name)
                .join(', ');
            _currentStatsSessionStartPosition =
                (await getCurrentPosition()).inSeconds;
            statsProvider.recordPlayStart(
              _currentStatsSongId!,
              _currentStatsSongTitle!,
              _currentStatsSongArtist!,
              _currentStatsSessionStartPosition!,
            );
          }
        } else if (state.processingState == ProcessingState.completed ||
            state.processingState == ProcessingState.idle) {
          await _recordCurrentPlaybackEnd();
        } else if (state.playing == false &&
            state.processingState == ProcessingState.ready) {
          await _recordCurrentPlaybackEnd();
        }
      });

      _justAudioPlayer!.currentIndexStream.listen((index) async {
        if (index != null) {
          final currentSong = playerProvider.currentSong;
          if (currentSong != null &&
              currentSong.videoId != _currentStatsSongId) {
            await _recordCurrentPlaybackEnd();
            if (_justAudioPlayer!.playing &&
                playerProvider.currentLocalSong == null) {
              _currentStatsSongId = currentSong.videoId;
              _currentStatsSongTitle = currentSong.name;
              _currentStatsSongArtist = currentSong.artists
                  .map((a) => a.name)
                  .join(', ');
              _currentStatsSessionStartPosition =
                  (await getCurrentPosition()).inSeconds;
              statsProvider.recordPlayStart(
                _currentStatsSongId!,
                _currentStatsSongTitle!,
                _currentStatsSongArtist!,
                _currentStatsSessionStartPosition!,
              );
            }
          }
        }
      });
    } else {
      _audioPlayer!.onPlayerStateChanged.listen((state) async {
        if (state == audio_players.PlayerState.playing) {
          final currentSong = playerProvider.currentSong;
          if (currentSong != null && playerProvider.currentLocalSong == null) {
            _currentStatsSongId = currentSong.videoId;
            _currentStatsSongTitle = currentSong.name;
            _currentStatsSongArtist = currentSong.artists
                .map((a) => a.name)
                .join(', ');
            _currentStatsSessionStartPosition =
                (await getCurrentPosition()).inSeconds;
            statsProvider.recordPlayStart(
              _currentStatsSongId!,
              _currentStatsSongTitle!,
              _currentStatsSongArtist!,
              _currentStatsSessionStartPosition!,
            );
          }
        } else if (state == audio_players.PlayerState.paused ||
            state == audio_players.PlayerState.stopped ||
            state == audio_players.PlayerState.completed) {
          await _recordCurrentPlaybackEnd();
        }
      });
    }
  }

  dynamic get currentAudioPlayer =>
      Platform.isAndroid ? _justAudioPlayer : _audioPlayer;

  audio_players.AudioPlayer get windowsLinuxAudioPlayer => _audioPlayer!;

  Stream<PlayerState> get playerStateStream => Platform.isAndroid
      ? _justAudioPlayer!.playerStateStream
      : (() async* {
          try {
            final initial = await _audioPlayer!.state;
            yield mapAudioPlayersState(initial);
          } catch (_) {}
          await for (final s in _audioPlayer!.onPlayerStateChanged) {
            yield mapAudioPlayersState(s);
          }
        })();

  Future<Duration> getCurrentPosition() async {
    if (Platform.isAndroid) {
      return _justAudioPlayer?.position ?? Duration.zero;
    } else {
      return await _audioPlayer?.getCurrentPosition() ?? Duration.zero;
    }
  }

  Stream<Duration> get bufferedPositionStream {
    if (Platform.isAndroid) {
      return _justAudioPlayer!.bufferedPositionStream;
    } else {
      return _audioPlayer!.onPositionChanged;
    }
  }

  Stream<Duration> get positionStream {
    if (Platform.isAndroid) {
      return Stream.fromFuture(getCurrentPosition()).asyncExpand((
        initialPosition,
      ) {
        return Stream.value(
          initialPosition,
        ).asyncExpand((_) => _justAudioPlayer!.positionStream);
      });
    } else {
      return (() async* {
        try {
          final initial = await getCurrentPosition();
          yield initial;
        } catch (_) {
          yield Duration.zero;
        }
        await for (final p in _audioPlayer!.onPositionChanged) {
          yield p;
        }
      })();
    }
  }

  Stream<Duration?> get durationStream => Platform.isAndroid
      ? _justAudioPlayer!.durationStream
      : (() async* {
          try {
            final initial = await _audioPlayer!.getDuration();
            yield initial;
          } catch (_) {
            yield null;
          }
          await for (final d in _audioPlayer!.onDurationChanged) {
            yield d;
          }
        })();

  Stream<bool> get playingStream => Platform.isAndroid
      ? _justAudioPlayer!.playingStream
      : (() async* {
          try {
            final initial = await _audioPlayer!.state;
            yield initial == audio_players.PlayerState.playing;
          } catch (_) {
            yield false;
          }
          await for (final s in _audioPlayer!.onPlayerStateChanged) {
            yield s == audio_players.PlayerState.playing;
          }
        })();

  void setupPlaybackCompletion() {
    if (Platform.isAndroid) {
      _justAudioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed &&
            !isExplicitlySettingSong &&
            !_isHandlingCompletion) {
          _handlePlaybackCompletion();
        }
      });

      _justAudioPlayer!.currentIndexStream.listen((index) {
        if (index != null) {
          syncQueueIndex(index);
          maintainPreloadingBuffer(completer: _currentPreloadCompleter);
        }
      });
    } else {
      _audioPlayer!.onPlayerComplete.listen((_) {
        _handlePlaybackCompletion();
      });
    }
  }

  void _handlePlaybackCompletion() async {
    if (_isHandlingCompletion) return;
    _isHandlingCompletion = true;
    try {
      if (queueProvider.repeatMode == RepeatMode.one) {
        return;
      }

      if (Platform.isAndroid) {
        if (_justAudioPlayer?.playerState.processingState !=
            ProcessingState.completed) {
          return;
        }
        if (playlist != null) {
          final currentJustAudioIndex = _justAudioPlayer?.currentIndex ?? 0;

          if (currentJustAudioIndex < (playlist!.children.length - 1)) {
            return;
          }
        }
      }

      if (playerProvider.currentLocalSong != null) {
        playNext();
        return;
      }

      final nextSong = queueProvider.getNextSong();
      if (nextSong != null) {
        final success = await playSong(nextSong, maxRetries: 2);
        if (!success) {
          debugPrint(
            'Failed to play next song after retries. Stopping playback.',
          );
          seek(Duration.zero);
          pause();
        }
      } else {
        seek(Duration.zero);
        pause();
      }
    } finally {
      _isHandlingCompletion = false;
    }
  }

  bool _canGoNext() {
    return queueProvider.hasNext || queueProvider.isRepeatEnabled;
  }

  void playNext({int retryCount = 0}) async {
    if (playerProvider.currentLocalSong != null) {
      if (retryCount >= queueProvider.queue.length) {
        debugPrint('All local songs failed to play. Stopping playback.');
        seek(Duration.zero);
        pause();
        return;
      }
      final nextSong = queueProvider.getNextSong();
      if (nextSong != null) {
        final nextIndex = queueProvider.currentIndex;
        final localSongs =
            playerProvider.currentLocalSong!['queue']
                as List<Map<String, dynamic>>?;
        if (localSongs != null && nextIndex < localSongs.length) {
          final nextLocalSong = localSongs[nextIndex];
          final filePath = nextLocalSong['localPath'];
          if (filePath != null) {
            try {
              await playLocalAudioWithQueue(
                filePath,
                nextLocalSong,
                localSongs,
                nextIndex,
              );
            } catch (e) {
              debugPrint('Failed to play local song, skipping to next: $e');
              playNext(retryCount: retryCount + 1);
            }
          } else {
            playNext(retryCount: retryCount + 1);
          }
        } else {
          playNext(retryCount: retryCount + 1);
        }
      } else {
        seek(Duration.zero);
        pause();
      }
      return;
    }

    if (Platform.isAndroid && playlist != null) {
      final currentIndex = _justAudioPlayer!.currentIndex ?? 0;
      final hasNextInPlaylist = currentIndex < (playlist!.length - 1);

      if (hasNextInPlaylist) {
        await _justAudioPlayer!.seekToNext();
        return;
      }
    }

    final nextSong = queueProvider.getNextSong();
    if (nextSong != null) {
      await playSong(nextSong);
    }
  }

  Future<void> loadSong(SongInfo song) async {
    _updateSmtcMetadata(song);
    if (Platform.isAndroid) {
      await updatePlaylist(song);
    } else {
      isFetchingStreamUrlNotifier.value = true;
      try {
        final downloadedPath = await downloadProvider.getDownloadedSongPath(
          song.videoId,
        );
        if (downloadedPath != null) {
          await _audioPlayer!.setSource(
            audio_players.DeviceFileSource(downloadedPath),
          );
        } else {
          final audioUrl = await getAudioUrl(song);
          if (audioUrl != null) {
            await _audioPlayer!.setSource(audio_players.UrlSource(audioUrl));
          } else {
            throw Exception('Failed to get audio URL');
          }
        }
      } catch (e) {
        debugPrint('Error loading song: $e');
      } finally {
        isFetchingStreamUrlNotifier.value = false;
      }
    }
    updateBackgroundColor(
      song.thumbnails.isNotEmpty ? song.thumbnails.first.url : null,
    );
  }

  Future<bool> playSong(SongInfo song, {int maxRetries = 1}) async {
    isExplicitlySettingSong = true;
    playerProvider.setCurrentSong(song);
    _updateSmtcMetadata(song);
    await _recordCurrentPlaybackEnd();

    stop();

    cancelCurrentPreloading();

    cancelCurrentPlayback();
    _currentPlaybackCompleter = Completer<bool>();

    _currentPreloadCompleter = Completer<bool>();

    try {
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          if (_currentPlaybackCompleter!.isCompleted) {
            throw CanceledException('Playback cancelled during retry attempt');
          }

          if (Platform.isAndroid) {
            final success = await updatePlaylist(
              song,
              completer: _currentPlaybackCompleter,
            );
            if (!success) {
              throw Exception(
                'Failed to update playlist - could not create audio source',
              );
            }
          } else {
            final downloadedPath = await downloadProvider.getDownloadedSongPath(
              song.videoId,
            );
            if (downloadedPath != null) {
              if (_currentPlaybackCompleter != null &&
                  _currentPlaybackCompleter!.isCompleted) {
                throw CanceledException(
                  'Playback cancelled before setting local source',
                );
              }
              await _audioPlayer!.setSource(
                audio_players.DeviceFileSource(downloadedPath),
              );
            } else {
              final audioUrl = await getAudioUrl(
                song,
                completer: _currentPlaybackCompleter,
              );
              if (audioUrl == null) {
                throw Exception('Failed to get audio URL');
              }
              if (_currentPlaybackCompleter!.isCompleted) {
                throw CanceledException('Playbook cancelled after getting URL');
              }
              await _audioPlayer!.setSource(audio_players.UrlSource(audioUrl));
            }
          }

          isExplicitlySettingSong = false;

          if (_currentPlaybackCompleter!.isCompleted) {
            throw CanceledException('Playback cancelled before playing');
          }

          if (Platform.isAndroid) {
            if (!_justAudioPlayer!.playing) {
              await play();
            }
          } else {
            await play();
          }

          final playbackStartedCompleter = Completer<bool>();
          final timer = Timer(const Duration(seconds: 20), () {
            if (!playbackStartedCompleter.isCompleted) {
              playbackStartedCompleter.complete(false);
            }
          });

          final subscription = playingStream.listen((isPlaying) {
            if (isPlaying && !playbackStartedCompleter.isCompleted) {
              playbackStartedCompleter.complete(true);
            }
          });

          final playbackStarted = await Future.any([
            playbackStartedCompleter.future,
            _currentPlaybackCompleter!.future
                .then((_) => false)
                .catchError((_) => false),
          ]);
          timer.cancel();
          subscription.cancel();

          if (playbackStarted) {
            _currentStatsSongId = song.videoId;
            _currentStatsSongTitle = song.name;
            _currentStatsSongArtist = song.artists
                .map((a) => a.name)
                .join(', ');
            _currentStatsSessionStartPosition =
                (await getCurrentPosition()).inSeconds;
            statsProvider.recordPlayStart(
              _currentStatsSongId!,
              _currentStatsSongTitle!,
              _currentStatsSongArtist!,
              _currentStatsSessionStartPosition!,
            );

            if (!_currentPlaybackCompleter!.isCompleted) {
              _currentPlaybackCompleter!.complete(true);
            }
            return true;
          } else {
            if (Platform.isAndroid) {
              if (!_justAudioPlayer!.playing &&
                  _justAudioPlayer!.playerState.processingState !=
                      ProcessingState.loading) {
                if (!_currentPlaybackCompleter!.isCompleted) {
                  _currentPlaybackCompleter!.complete(false);
                }
                return false;
              }
            } else {
              final state = _audioPlayer!.state;
              if (state == audio_players.PlayerState.paused) {
                if (!_currentPlaybackCompleter!.isCompleted) {
                  _currentPlaybackCompleter!.complete(false);
                }
                return false;
              }
            }
            debugPrint(
              'Playback did not start in time for ${song.videoId} (attempt ${attempt + 1})',
            );
          }
        } on CanceledException catch (e) {
          debugPrint('Playback cancelled for ${song.videoId}: $e');
          if (!_currentPlaybackCompleter!.isCompleted) {
            _currentPlaybackCompleter!.completeError(e);
          }
          return false;
        } catch (e) {
          debugPrint(
            'Error playing song ${song.videoId} (attempt ${attempt + 1}): $e',
          );
          if (attempt < maxRetries - 1) {
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
    } finally {
      if (isFetchingStreamUrlNotifier.value) {
        isFetchingStreamUrlNotifier.value = false;
      }
      isExplicitlySettingSong = false;
    }

    await stop();
    if (_currentPlaybackCompleter != null &&
        !_currentPlaybackCompleter!.isCompleted) {
      _currentPlaybackCompleter!.complete(false);
    }
    _currentPlaybackCompleter = null;
    return false;
  }

  Future<void> playLocalAudioWithQueue(
    String filePath,
    Map<String, dynamic> songData,
    List<Map<String, dynamic>> songQueue,
    int currentIndex,
  ) async {
    isExplicitlySettingSong = true;

    try {
      await _recordCurrentPlaybackEnd();
      stop();
      seek(Duration.zero);
      _updateSmtcMetadataFromLocal(songData);

      final isSamePlaylist = _isSameLocalPlaylist(songQueue);

      Uri artworkUri;
      if (songData['thumbnail'] != null) {
        final thumb = songData['thumbnail'].toString();
        if (thumb.startsWith('http://') || thumb.startsWith('https://')) {
          artworkUri = Uri.parse(thumb);
        } else if (thumb.startsWith('file://')) {
          artworkUri = Uri.parse(thumb);
        } else {
          artworkUri = Uri.file(thumb);
        }
      } else {
        artworkUri = await getDefaultArtworkUri();
      }

      if (isSamePlaylist) {
        await playerProvider.updateCurrentLocalSongWithQueue(
          songData,
          songQueue,
          currentIndex,
        );

        if (Platform.isAndroid && playlist != null) {
          await _justAudioPlayer!.seek(Duration.zero, index: currentIndex);
        } else if (!Platform.isAndroid) {
          await _audioPlayer!.setSource(
            audio_players.DeviceFileSource(filePath),
          );
        }
      } else {
        await playerProvider.setCurrentLocalSongWithQueue(
          songData,
          songQueue,
          currentIndex,
        );

        Uri artworkUri;
        if (songData['thumbnail'] != null) {
          final thumb = songData['thumbnail'].toString();
          if (thumb.startsWith('http://') || thumb.startsWith('https://')) {
            artworkUri = Uri.parse(thumb);
          } else {
            artworkUri = Uri.file(thumb);
          }
        } else {
          artworkUri = await getDefaultArtworkUri();
        }

        if (Platform.isAndroid) {
          final List<AudioSource> audioSources = [];

          for (final localSong in songQueue) {
            final localPath = localSong['localPath'];
            if (localPath != null) {
              Uri localArtworkUri;
              if (localSong['thumbnail'] != null) {
                final thumb = localSong['thumbnail'].toString();
                if (thumb.startsWith('http://') ||
                    thumb.startsWith('https://')) {
                  localArtworkUri = Uri.parse(thumb);
                } else if (thumb.startsWith('file://')) {
                  localArtworkUri = Uri.parse(thumb);
                } else {
                  localArtworkUri = Uri.file(thumb);
                }
              } else {
                localArtworkUri = await getDefaultArtworkUri();
              }

              final audioSource = AudioSource.uri(
                Uri.file(localPath),
                tag: MediaItem(
                  id: localSong['id'] ?? '',
                  album: localSong['album'] ?? 'Local Music',
                  title: localSong['title'] ?? 'Unknown',
                  artist: localSong['artist'] ?? 'Unknown Artist',
                  artUri: localArtworkUri,
                  duration: Duration(milliseconds: localSong['duration'] ?? 0),
                ),
              );
              audioSources.add(audioSource);
            }
          }

          if (audioSources.isNotEmpty) {
            playlist = ConcatenatingAudioSource(children: audioSources);
            playlistStartIndex = 0;
            await _justAudioPlayer!.setAudioSource(
              playlist!,
              initialIndex: currentIndex,
            );
          } else {
            final audioSource = AudioSource.uri(
              Uri.file(filePath),
              tag: MediaItem(
                id: songData['id'],
                album: songData['album'] ?? 'Local Music',
                title: songData['title'],
                artist: songData['artist'] ?? 'Unknown Artist',
                artUri: artworkUri,
                duration: Duration(milliseconds: songData['duration'] ?? 0),
              ),
            );
            playlist = null;
            playlistStartIndex = 0;
            await _justAudioPlayer!.setAudioSource(audioSource);
          }
        } else {
          await _audioPlayer!.setSource(
            audio_players.DeviceFileSource(filePath),
          );
        }
      }

      isExplicitlySettingSong = false;

      await play();
      updateBackgroundColor(artworkUri.toString());

      _currentStatsSongId = null;
      _currentStatsSongTitle = null;
      _currentStatsSongArtist = null;
      _currentStatsSessionStartPosition = null;
    } catch (e) {
      isExplicitlySettingSong = false;
      debugPrint('Error in playLocalAudioWithQueue: $e');
      rethrow;
    }
  }

  Future<void> play() async {
    if (Platform.isAndroid) {
      if (_justAudioPlayer!.playerState.processingState ==
          ProcessingState.idle) {
        final currentSong = playerProvider.currentSong;
        if (currentSong != null) {
          debugPrint(
            'Player is idle, retrying to play current song: ${currentSong.name}',
          );
          await playSong(currentSong);
          return;
        }
      }
      await _justAudioPlayer!.play();
    } else {
      await _audioPlayer!.resume();
    }
  }

  Future<void> pause() async {
    await _recordCurrentPlaybackEnd();
    if (Platform.isAndroid) {
      await _justAudioPlayer!.pause();
    } else {
      await _audioPlayer!.pause();
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (Platform.isAndroid) {
      await _justAudioPlayer!.setSpeed(speed);
    } else {
      await _audioPlayer!.setPlaybackRate(speed);
    }
  }

  double getPlaybackSpeed() {
    if (Platform.isAndroid) {
      return _justAudioPlayer!.speed;
    } else {
      return _audioPlayer!.playbackRate;
    }
  }

  Future<void> seek(Duration position) async {
    if (Platform.isAndroid) {
      await _justAudioPlayer!.seek(position);
    } else {
      await _audioPlayer!.seek(position);
    }
  }

  Future<void> stop() async {
    await _recordCurrentPlaybackEnd();
    if (Platform.isAndroid) {
      await _justAudioPlayer!.stop();
    } else {
      await _audioPlayer!.stop();
    }
  }

  void playPrevious({int retryCount = 0}) async {
    if (playerProvider.currentLocalSong != null) {
      if (retryCount >= queueProvider.queue.length) {
        debugPrint('All local songs failed to play. Stopping playback.');
        seek(Duration.zero);
        pause();
        return;
      }
      final previousSong = queueProvider.getPreviousSong();
      if (previousSong != null) {
        final previousIndex = queueProvider.currentIndex;
        final localSongs =
            playerProvider.currentLocalSong!['queue']
                as List<Map<String, dynamic>>?;
        if (localSongs != null &&
            previousIndex >= 0 &&
            previousIndex < localSongs.length) {
          final previousLocalSong = localSongs[previousIndex];
          final filePath = previousLocalSong['localPath'];
          if (filePath != null) {
            try {
              await playLocalAudioWithQueue(
                filePath,
                previousLocalSong,
                localSongs,
                previousIndex,
              );
            } catch (e) {
              debugPrint('Failed to play local song, skipping to previous: $e');
              playPrevious(retryCount: retryCount + 1);
            }
          } else {
            playPrevious(retryCount: retryCount + 1);
          }
        } else {
          playPrevious(retryCount: retryCount + 1);
        }
      } else {
        seek(Duration.zero);
        pause();
      }
      return;
    }

    if (Platform.isAndroid && playlist != null) {
      final currentIndex = _justAudioPlayer!.currentIndex ?? 0;
      final hasPreviousInPlaylist = currentIndex > 0;

      if (hasPreviousInPlaylist) {
        await _justAudioPlayer!.seekToPrevious();
        return;
      }
    }

    final previousSong = queueProvider.getPreviousSong();
    if (previousSong != null) {
      await playSong(previousSong);
    }
  }

  Future<int?> getAudioSessionId() async {
    if (Platform.isAndroid) {
      return await _justAudioPlayer!.androidAudioSessionId;
    }
    return null;
  }

  Future<void> setShuffleMode(bool enabled) async {
    if (Platform.isAndroid && _justAudioPlayer != null) {
      await _justAudioPlayer!.setShuffleModeEnabled(enabled);
    }
    debugPrint('Shuffle mode set to: $enabled');
  }

  Future<void> setLoopMode(RepeatMode repeatMode) async {
    if (Platform.isAndroid && _justAudioPlayer != null) {
      await _justAudioPlayer!.setLoopMode(
        repeatMode == RepeatMode.one ? LoopMode.one : LoopMode.off,
      );
    } else if (!Platform.isAndroid && _audioPlayer != null) {
      final releaseMode = repeatMode == RepeatMode.one
          ? audio_players.ReleaseMode.loop
          : audio_players.ReleaseMode.release;
      await _audioPlayer!.setReleaseMode(releaseMode);
    }
    debugPrint('Loop mode set to: $repeatMode');
  }

  Future<void> startSleepTimer(Duration duration, {bool fade = false}) async {
    await cancelSleepTimer();
    sleepTimerEnd = DateTime.now().add(duration);
    sleepTimerRemaining.value = duration;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'sleep_timer_end',
      sleepTimerEnd!.millisecondsSinceEpoch,
    );
    await prefs.setBool('sleep_timer_fade', fade);

    sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final remaining = sleepTimerEnd!.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        t.cancel();
        sleepTimer = null;
        sleepTimerRemaining.value = null;
        sleepTimerEnd = null;
        await prefs.remove('sleep_timer_end');
        await prefs.remove('sleep_timer_fade');

        if (fade) {
          await fadeAndStop(pauseFunction: pause);
        } else {
          await pause();
        }
      } else {
        sleepTimerRemaining.value = remaining;
      }
    });
  }

  Future<void> startSleepTimerUntilEndOfTrack({bool fade = false}) async {
    final currentDuration = Platform.isAndroid
        ? _justAudioPlayer?.duration
        : await _audioPlayer?.getDuration();
    final currentPosition = Platform.isAndroid
        ? _justAudioPlayer?.position
        : await _audioPlayer?.getCurrentPosition();

    if (currentDuration != null && currentPosition != null) {
      final remaining = currentDuration - currentPosition;
      if (remaining > Duration.zero) {
        await startSleepTimer(remaining, fade: fade);
      } else {
        if (fade) {
          await fadeAndStop(pauseFunction: pause);
        } else {
          await pause();
        }
      }
    } else {
      debugPrint(
        'Could not determine track duration for "end of track" timer.',
      );
    }
  }

  Future<void> cancelSleepTimer() async {
    sleepTimer?.cancel();
    sleepTimer = null;
    sleepTimerEnd = null;
    sleepTimerRemaining.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sleep_timer_end');
    await prefs.remove('sleep_timer_fade');
  }

  Future<void> _restoreSleepTimerIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final endMillis = prefs.getInt('sleep_timer_end');
    final fade = prefs.getBool('sleep_timer_fade') ?? false;
    if (endMillis != null) {
      final end = DateTime.fromMillisecondsSinceEpoch(endMillis);
      final remaining = end.difference(DateTime.now());
      if (remaining > Duration.zero) {
        await startSleepTimer(remaining, fade: fade);
      } else {
        await prefs.remove('sleep_timer_end');
        await prefs.remove('sleep_timer_fade');
      }
    }
  }

  Future<void> _initializeAudioSession() async {
    if (!Platform.isAndroid) return;

    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      _audioSession!.interruptionEventStream.listen((event) {
        if (event.begin) {
          debugPrint('Audio session interrupted');
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (_justAudioPlayer != null) {
                _justAudioPlayer!.setVolume(0.3);
              }
              break;
            case AudioInterruptionType.pause:
              _wasPlayingBeforeInterruption = _justAudioPlayer!.playing;
              pause();
              break;
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          debugPrint('Audio session interruption ended');
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (_justAudioPlayer != null) {
                _justAudioPlayer!.setVolume(1.0);
              }
              break;
            case AudioInterruptionType.pause:
              if (_wasPlayingBeforeInterruption) {
                play();
              }
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      _audioSession!.becomingNoisyEventStream.listen((_) {
        debugPrint('Audio becoming noisy - pausing playback');
        pause();
      });

      debugPrint('Audio session initialized successfully');
    } catch (e) {
      debugPrint('Error initializing audio session: $e');
    }
  }

  void _initSmtc() {
    if (!Platform.isWindows) return;

    _smtcService = SmtcService();
    _smtcService!.initialize(
      onPlay: () => play(),
      onPause: () => pause(),
      onNext: () => playNext(),
      onPrevious: () => playPrevious(),
      onStop: () => stop(),
    );
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      switch (state) {
        case audio_players.PlayerState.playing:
          _smtcService!.setIsPlaying();
          break;
        case audio_players.PlayerState.paused:
          _smtcService!.setIsPaused();
          break;
        case audio_players.PlayerState.stopped:
        case audio_players.PlayerState.completed:
          _smtcService!.setIsStopped();
          break;
        default:
          break;
      }
    });
    _smtcPositionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final position = await getCurrentPosition();
        final duration = await _audioPlayer?.getDuration() ?? Duration.zero;
        if (duration > Duration.zero) {
          _smtcService!.updateTimeline(position: position, duration: duration);
        }
      } catch (_) {}
    });
    queueProvider.addListener(() {
      _smtcService?.updateConfig(
        nextEnabled: queueProvider.hasNext,
        prevEnabled: queueProvider.hasPrevious,
      );
    });
  }

  void _updateSmtcMetadata(SongInfo song) {
    _smtcService?.updateMetadata(song);
  }

  void _updateSmtcMetadataFromLocal(Map<String, dynamic> localSong) {
    _smtcService?.updateMetadataFromLocal(localSong);
  }

  bool _isSameLocalPlaylist(List<Map<String, dynamic>> newSongQueue) {
    final currentLocalSong = playerProvider.currentLocalSong;
    if (currentLocalSong == null) return false;

    final currentQueue =
        currentLocalSong['queue'] as List<Map<String, dynamic>>?;
    if (currentQueue == null) return false;

    if (currentQueue.length != newSongQueue.length) return false;

    for (int i = 0; i < currentQueue.length; i++) {
      if (currentQueue[i]['id'] != newSongQueue[i]['id']) {
        return false;
      }
    }

    return true;
  }

  void dispose() {
    _recordCurrentPlaybackEnd();
    sleepTimer?.cancel();
    _smtcPositionTimer?.cancel();
    _smtcService?.dispose();

    AudioUrlIsolate.cancelAllRequests().catchError((e) {
      debugPrint('Error cancelling isolate requests during dispose: $e');
    });

    if (Platform.isAndroid) {
      _justAudioPlayer!.dispose();
    } else {
      _audioPlayer!.dispose();
    }
  }
}
