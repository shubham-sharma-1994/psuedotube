import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audioplayers/audioplayers.dart' as audio_players;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/providers/player_provider.dart';
import '../../../../core/providers/settings_provider.dart';

class VolumeBottomSheet extends StatefulWidget {
  const VolumeBottomSheet({super.key});

  @override
  State<VolumeBottomSheet> createState() => _VolumeBottomSheetState();
}

class _VolumeBottomSheetState extends State<VolumeBottomSheet> {
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  just_audio.AudioPlayer? _justAudioPlayer;
  audio_players.AudioPlayer? _audioPlayersPlayer;

  @override
  void initState() {
    super.initState();
    _initVolume();
    _initPlaybackSpeed();
  }

  void _initVolume() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    if (Platform.isAndroid) {
      final p = playerProvider.playerService.justAudioPlayer;
      _justAudioPlayer = p;
    } else {
      final p = playerProvider.playerService.audioPlayer;
      _audioPlayersPlayer = p;
    }
    _volume = settingsProvider.volumeLevel;
  }

  void _initPlaybackSpeed() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    _playbackSpeed = playerProvider.playerService.getPlaybackSpeed();
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
      if (Platform.isAndroid) {
        _justAudioPlayer?.setVolume(value);
      } else {
        _audioPlayersPlayer?.setVolume(value);
      }
      Provider.of<SettingsProvider>(context, listen: false).volumeLevel = value;
    });
  }

  void _setPlaybackSpeed(double value) {
    setState(() {
      _playbackSpeed = value;
      final playerProvider = Provider.of<PlayerProvider>(
        context,
        listen: false,
      );
      playerProvider.playerService.setPlaybackSpeed(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final accentColor =
        settingsProvider.accentColor ?? Theme.of(context).colorScheme.secondary;
    final isDarkMode =
        settingsProvider.theme == 'Dark' ||
        (settingsProvider.theme == 'System Default' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      decoration: BoxDecoration(
        color: MainScreenColors.getSurfaceColor(isDarkMode),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppDimens.dragHandleWidth,
            height: AppDimens.dragHandleHeight,
            margin: const EdgeInsets.only(bottom: AppDimens.spacingLg),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(AppDimens.radiusXxs),
            ),
          ),
          Text(
            'volume'.tr(),
            style: AppTextStyles.headingLg(
              isDarkMode: isDarkMode,
            ).copyWith(color: MainScreenColors.getTextColor(isDarkMode)),
          ),
          const SizedBox(height: AppDimens.spacingXxl),
          Row(
            children: [
              Icon(Icons.volume_down, color: accentColor),
              Expanded(
                child: Slider(
                  value: _volume,
                  onChanged: _setVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  label: '${(_volume * 100).toInt()}%',
                  activeColor: accentColor,
                  inactiveColor: accentColor.withOpacity(0.3),
                  year2023: false,
                ),
              ),
              Icon(Icons.volume_up, color: accentColor),
            ],
          ),
          const SizedBox(height: AppDimens.spacingLg),
          Text(
            '${'current_volume'.tr()}: ${(_volume * 100).toInt()}%',
            style: AppTextStyles.caption(isDarkMode: isDarkMode).copyWith(
              color: MainScreenColors.getTextColor(isDarkMode).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppDimens.spacingLg),
          Row(
            children: [
              Icon(Icons.speed, color: accentColor),
              Expanded(
                child: Slider(
                  value: _playbackSpeed,
                  onChanged: _setPlaybackSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${_playbackSpeed.toStringAsFixed(1)}x',
                  activeColor: accentColor,
                  inactiveColor: accentColor.withOpacity(0.3),
                  year2023: false,
                ),
              ),
              Text(
                '${_playbackSpeed.toStringAsFixed(1)}x',
                style: AppTextStyles.caption(isDarkMode: isDarkMode).copyWith(
                  color: MainScreenColors.getTextColor(
                    isDarkMode,
                  ).withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Text(
            'playback_speed'.tr(),
            style: AppTextStyles.subtitle(isDarkMode: isDarkMode).copyWith(
              fontWeight: AppTextStyles.weightSemiBold,
              color: MainScreenColors.getTextColor(isDarkMode),
            ),
          ),
          const SizedBox(height: AppDimens.spacingXxl),
          const SizedBox(height: AppDimens.spacingLg),
        ],
      ),
    );
  }
}
