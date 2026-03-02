import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';

import 'package:just_audio/just_audio.dart';
import 'package:audioplayers/audioplayers.dart' as audio_players;
import '../models/song_model.dart';
import '../providers/queued_provider.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../providers/favorite_song_provider.dart';
import 'player_service.dart';
import 'package:flutter/foundation.dart';

class CustomAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final PlayerService _playerService;
  final QueueProvider _queueProvider;
  final PlayerProvider _playerProvider;
  final DownloadProvider _downloadProvider;
  final FavoriteSongProvider _favoriteSongProvider;

  StreamSubscription? _queueSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playingSubscription;
  StreamSubscription? _playerProviderSubscription;
  StreamSubscription? _favoriteSongSubscription;
  Timer? _positionTimer;

  CustomAudioHandler(
    this._playerService,
    this._queueProvider,
    this._playerProvider,
    this._downloadProvider,
    this._favoriteSongProvider,
  ) {
    _init();
  }

  PlayerService get player => _playerService;

  void _init() {
    _playerStateSubscription = _playerService.playerStateStream.listen(
      (state) => _broadcastState(),
    );

    _durationSubscription = _playerService.durationStream.listen((duration) {
      if (mediaItem.value != null && duration != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });

    _playingSubscription = _playerService.playingStream.listen((playing) {
      _broadcastState();
    });

    _queueProvider.addListener(_updateFromQueueProvider);

    _playerProvider.addListener(_updateFromPlayerProvider);

    _favoriteSongProvider.addListener(_broadcastState);

    _playerService.isFetchingStreamUrlNotifier.addListener(_broadcastState);

    _startPositionTimer();

    _updateFromPlayerProvider();
    _updateFromQueueProvider();
  }

  void _startPositionTimer() {
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _broadcastState();
    });
  }

  void _updateFromQueueProvider() {
    final newQueue = _queueProvider.queue.map(_createMediaItem).toList();
    queue.add(newQueue);
    _broadcastState();
  }

  void _updateFromPlayerProvider() {
    if (_playerProvider.currentSong != null) {
      _updateMediaItem(_playerProvider.currentSong!);
      _favoriteSongProvider.setCurrentSong(_playerProvider.currentSong!);
    } else if (_playerProvider.currentLocalSong != null) {
      _updateMediaItemFromLocal(_playerProvider.currentLocalSong!);
      _favoriteSongProvider.setCurrentSong(null);
    } else {
      mediaItem.add(null);
      _favoriteSongProvider.setCurrentSong(null);
    }
    _broadcastState();
  }

  String _normalizeThumbnail(String? thumb) {
    if (thumb == null || thumb.isEmpty) return '';
    if (thumb.startsWith('http://') || thumb.startsWith('https://')) {
      return thumb;
    }
    if (thumb.startsWith('file://')) {
      return thumb;
    }
    return Uri.file(thumb).toString();
  }

  MediaItem _createMediaItem(SongInfo song) {
    return MediaItem(
      id: song.videoId,
      album: 'Noize',
      title: song.name,
      artist: song.artists.map((artist) => artist.name).join(', '),
      artUri: Uri.parse(_normalizeThumbnail(song.thumbnails.last.url)),
      // Uri.parse(
      //   'https://img.youtube.com/vi/${song.videoId}/hqdefault.jpg',
      // ),
      duration: song.duration,
    );
  }

  void _updateMediaItem(SongInfo song) {
    mediaItem.add(_createMediaItem(song));
  }

  void _updateMediaItemFromLocal(Map<String, dynamic> localSong) {
    String? thumb = localSong['thumbnail'] as String?;
    if (thumb != null &&
        !thumb.startsWith('http') &&
        !thumb.startsWith('file://')) {
      thumb = Uri.file(thumb).toString();
    }

    mediaItem.add(
      MediaItem(
        id: localSong['id'] ?? 'local_${localSong.hashCode}',
        album: localSong['album'] ?? 'Local Music',
        title: localSong['title'] ?? 'Unknown',
        artist: localSong['artist'] ?? 'Unknown Artist',
        artUri: thumb != null && thumb.isNotEmpty ? Uri.parse(thumb) : null,
        duration: Duration(milliseconds: localSong['duration'] ?? 0),
      ),
    );
  }

  void _broadcastState() async {
    try {
      final playing = await _isCurrentlyPlaying();
      final position = await _playerService.getCurrentPosition();
      final bufferedPosition = await _getBufferedPosition();
      final speed = _playerService.getPlaybackSpeed();
      final queueIndex = _queueProvider.currentIndex;
      final processingState = await _getProcessingState();

      final isOnlineSong = _playerProvider.currentSong != null;

      List<MediaControl> controls = [];
      if (_queueProvider.hasPrevious) {
        controls.add(MediaControl.skipToPrevious);
      }
      if (isOnlineSong) {
        controls.add(
          MediaControl.custom(
            androidIcon: _favoriteSongProvider.isCurrentSongLiked
                ? 'drawable/ic_like'
                : 'drawable/ic_like_outline',
            label: _favoriteSongProvider.isCurrentSongLiked ? 'Unlike' : 'Like',
            name: 'toggleLike',
          ),
        );
      }
      controls.add(playing ? MediaControl.pause : MediaControl.play);
      controls.add(
        MediaControl.custom(
          androidIcon: _queueProvider.repeatMode == RepeatMode.one
              ? 'drawable/ic_repeat_one'
              : 'drawable/ic_repeat',
          label: 'Repeat',
          name: 'toggleRepeat',
        ),
      );
      if (_queueProvider.hasNext) {
        controls.add(MediaControl.skipToNext);
      }

      int prevIndex = controls.indexWhere(
        (c) => c == MediaControl.skipToPrevious,
      );
      int playIndex = controls.indexWhere(
        (c) => c == MediaControl.pause || c == MediaControl.play,
      );
      int nextIndex = controls.indexWhere((c) => c == MediaControl.skipToNext);

      final compactIndices = [
        if (prevIndex != -1) prevIndex,
        playIndex,
        if (nextIndex != -1) nextIndex,
      ];

      playbackState.add(
        PlaybackState(
          controls: controls,
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.custom,
          },
          androidCompactActionIndices: compactIndices,
          processingState: processingState,
          playing: playing,
          updatePosition: position,
          bufferedPosition: bufferedPosition,
          speed: speed,
          queueIndex:
              queueIndex >= 0 && queueIndex < _queueProvider.queue.length
              ? queueIndex
              : null,
        ),
      );
    } catch (e) {
      debugPrint('Error broadcasting state: $e');
    }
  }

  Future<bool> _isCurrentlyPlaying() async {
    try {
      if (Platform.isAndroid) {
        return _playerService.justAudioPlayer?.playing ?? false;
      } else {
        final state = await _playerService.windowsLinuxAudioPlayer.state;
        return state == audio_players.PlayerState.playing;
      }
    } catch (e) {
      return false;
    }
  }

  Future<Duration> _getBufferedPosition() async {
    try {
      if (Platform.isAndroid) {
        return _playerService.justAudioPlayer?.bufferedPosition ??
            Duration.zero;
      } else {
        return await _playerService.getCurrentPosition();
      }
    } catch (e) {
      return Duration.zero;
    }
  }

  Future<AudioProcessingState> _getProcessingState() async {
    try {
      if (_playerService.isFetchingStreamUrlNotifier.value) {
        return AudioProcessingState.loading;
      }

      if (Platform.isAndroid) {
        final state =
            _playerService.justAudioPlayer?.processingState ??
            ProcessingState.idle;
        return const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[state]!;
      } else {
        final state = await _playerService.windowsLinuxAudioPlayer.state;
        return {
              audio_players.PlayerState.playing: AudioProcessingState.ready,
              audio_players.PlayerState.paused: AudioProcessingState.ready,
              audio_players.PlayerState.stopped: AudioProcessingState.idle,
              audio_players.PlayerState.completed:
                  AudioProcessingState.completed,
            }[state] ??
            AudioProcessingState.idle;
      }
    } catch (e) {
      return AudioProcessingState.idle;
    }
  }

  @override
  Future<void> play() async {
    await _playerService.play();
  }

  @override
  Future<void> pause() async {
    await _playerService.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _playerService.seek(position);
  }

  @override
  Future<void> stop() async {
    await _playerService.stop();
  }

  @override
  Future<void> skipToNext() async {
    _playerService.playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    _playerService.playPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queueProvider.queue.length) {
      final song = _queueProvider.queue[index];
      await _playerService.playSong(song);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final bool enableShuffle = shuffleMode != AudioServiceShuffleMode.none;
    if (_queueProvider.isShuffleEnabled != enableShuffle) {
      _queueProvider.toggleShuffle();
      await _playerService.setShuffleMode(enableShuffle);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final RepeatMode newMode = switch (repeatMode) {
      AudioServiceRepeatMode.one => RepeatMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => RepeatMode.all,
      _ => RepeatMode.off,
    };
    _queueProvider.setRepeatMode(newMode);
  }

  Future<void> playSong(SongInfo song) async {
    await _playerService.playSong(song);
  }

  Future<void> setQueue(
    List<SongInfo> songs, {
    int currentIndex = 0,
    String? playlistId,
    String? playlistName,
  }) async {
    _queueProvider.setQueue(
      songs,
      currentIndex: currentIndex,
      playlistId: playlistId,
      playlistName: playlistName,
    );
  }

  Future<void> addToQueue(SongInfo song) async {
    _queueProvider.addToQueue(song);
  }

  Future<void> removeFromQueue(int index) async {
    _queueProvider.removeFromQueue(index);
  }

  void toggleShuffle() {
    _queueProvider.toggleShuffle();
    _playerService.setShuffleMode(_queueProvider.isShuffleEnabled);
  }

  void toggleRepeat() {
    _queueProvider.toggleRepeat();
    _playerService.setLoopMode(_queueProvider.repeatMode);
  }

  Future<bool> get isPlaying async => await _isCurrentlyPlaying();
  Future<Duration> get position async =>
      await _playerService.getCurrentPosition();
  Stream<Duration> get positionStream => _playerService.positionStream;
  Stream<Duration?> get durationStream => _playerService.durationStream;
  Stream<PlayerState> get playerStateStream => _playerService.playerStateStream;
  Stream<bool> get playingStream => _playerService.playingStream;

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'toggleShuffle':
        toggleShuffle();
        break;
      case 'toggleRepeat':
        toggleRepeat();
        break;
      case 'toggleLike':
        await _favoriteSongProvider.toggleLike();
        break;
      default:
        super.customAction(name, extras);
    }
  }

  Future<void> dispose() async {
    await _queueSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _playerProviderSubscription?.cancel();
    await _favoriteSongSubscription?.cancel();
    _playerService.isFetchingStreamUrlNotifier.removeListener(_broadcastState);
    _favoriteSongProvider.removeListener(_broadcastState);
    _positionTimer?.cancel();
  }
}
