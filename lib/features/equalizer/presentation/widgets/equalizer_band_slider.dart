import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/settings_provider.dart';
import '../data/services/equalizer_services.dart';

class EqualizerBandSlider extends StatelessWidget {
  final AndroidEqualizerBand band;
  final AndroidEqualizerParameters params;
  final bool isEnabled;
  final EqualizerService equalizerService;
  final VoidCallback onChanged;
  final Set<String> customPresetNames;
  final String currentPreset;
  final VoidCallback onPresetsReload;

  const EqualizerBandSlider({
    Key? key,
    required this.band,
    required this.params,
    required this.isEnabled,
    required this.equalizerService,
    required this.onChanged,
    required this.customPresetNames,
    required this.currentPreset,
    required this.onPresetsReload,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final accentColor = settingsProvider.accentColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accentColor,
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.white,
                trackHeight: AppDimens.sliderTrackHeight,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: AppDimens.iconXs / 2,
                ),
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius: AppDimens.iconXs,
                ),
              ),
              child: Slider(
                value: band.gain.clamp(params.minDecibels, params.maxDecibels),
                min: params.minDecibels,
                max: params.maxDecibels,
                onChanged: isEnabled
                    ? (value) async {
                        await equalizerService.setBandGain(band.index, value);
                        if (customPresetNames.contains(currentPreset)) {
                          final params = await equalizerService
                              .getEqualizerParameters();
                          final bandGains = params.bands
                              .map((b) => b.gain)
                              .toList();
                          await equalizerService.saveCustomPreset(
                            currentPreset,
                            bandGains,
                          );
                        }
                        onPresetsReload();
                        onChanged();
                      }
                    : null,
              ),
            ),
          ),
        ),
        SizedBox(height: AppDimens.spacingSm),
        Text(
          EqualizerService.getFrequencyText(band.centerFrequency),
          style: AppTextStyles.caption(
            isDarkMode: isDarkMode,
          ).copyWith(color: MainScreenColors.getTextColor(isDarkMode)),
        ),
        SizedBox(height: AppDimens.spacingXxxl),
      ],
    );
  }
}
