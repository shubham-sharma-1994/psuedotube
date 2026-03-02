import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audioplayers/audioplayers.dart' as audio_players;
import 'package:provider/provider.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/player_provider.dart';
import '../../../../core/providers/settings_provider.dart';

class VolumeCircularSlider extends StatefulWidget {
  const VolumeCircularSlider({Key? key}) : super(key: key);

  @override
  State<VolumeCircularSlider> createState() => _VolumeCircularSliderState();
}

class _VolumeCircularSliderState extends State<VolumeCircularSlider> {
  double _volume = 1.0;
  just_audio.AudioPlayer? _justAudioPlayer;
  audio_players.AudioPlayer? _audioPlayersPlayer;

  @override
  void initState() {
    super.initState();
    _initVolume();
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

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final accentColor = settingsProvider.accentColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : AppDimens.headerImageMd;
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final scaledMax = (AppDimens.headerImageMd / textScale).clamp(
          AppDimens.thumbnailLarge * 1.0,
          AppDimens.headerImageMd,
        );
        final sliderSize = (available * 0.75).clamp(
          AppDimens.thumbnailLarge * 1.0,
          scaledMax,
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppDimens.shimmerHorizontalSection,
            ),
            child: Container(
              padding: EdgeInsets.all(AppDimens.paddingMd),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.1),
                    accentColor.withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: accentColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.volume_up_rounded,
                          color: accentColor,
                          size: AppDimens.iconXs,
                        ),
                        SizedBox(width: AppDimens.spacingXs),
                        Text(
                          'Volume',
                          style: AppTextStyles.body2(isDarkMode: isDarkMode)
                              .copyWith(
                                fontWeight: AppTextStyles.weightSemiBold,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppDimens.spacingSm),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull * 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: SleekCircularSlider(
                        appearance: CircularSliderAppearance(
                          customWidths: CustomSliderWidths(
                            trackWidth: AppDimens.progressStroke * 2.5,
                            progressBarWidth: AppDimens.progressStroke * 4,
                            shadowWidth: AppDimens.elevationHigh * 2.5,
                          ),
                          customColors: CustomSliderColors(
                            trackColor: isDarkMode
                                ? Colors.grey[800]!
                                : Colors.grey[300]!,
                            progressBarColors: [
                              accentColor.withOpacity(0.7),
                              accentColor,
                              accentColor.withOpacity(0.9),
                            ],
                            shadowColor: accentColor.withOpacity(0.4),
                            shadowMaxOpacity: 0.6,
                            dotColor: Colors.white,
                          ),
                          infoProperties: InfoProperties(
                            topLabelText: '',
                            bottomLabelText: '',
                            modifier: (double value) => '',
                            mainLabelStyle: AppTextStyles.titleLg(
                              isDarkMode: isDarkMode,
                            ).copyWith(fontWeight: AppTextStyles.weightBold),
                          ),
                          startAngle: 135,
                          angleRange: 270,
                          size: sliderSize,
                          animationEnabled: true,
                        ),
                        innerWidget: (double value) {
                          final percent = (value * 100).toInt();
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$percent',
                                  style:
                                      AppTextStyles.titleLg(
                                        isDarkMode: isDarkMode,
                                      ).copyWith(
                                        fontWeight: AppTextStyles.weightBold,
                                        color: MainScreenColors.getTextColor(
                                          isDarkMode,
                                        ),
                                      ),
                                ),
                                SizedBox(height: AppDimens.spacingXs),
                                Text(
                                  '%',
                                  style:
                                      AppTextStyles.caption(
                                        isDarkMode: isDarkMode,
                                      ).copyWith(
                                        fontWeight: AppTextStyles.weightMedium,
                                        color: accentColor,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                        min: 0.0,
                        max: 1.0,
                        initialValue: _volume,
                        onChange: _setVolume,
                        onChangeStart: (double value) {},
                        onChangeEnd: (double value) {
                          _setVolume(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
