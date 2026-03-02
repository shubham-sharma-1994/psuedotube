import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/player_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../data/services/equalizer_services.dart';
import '../widgets/volume_circular_slider.dart';
import '../widgets/speech_circular_slider.dart';
import '../widgets/equalizer_band_slider.dart';
import '../../../../shared/components/app_snackbar.dart';

class EqualizerScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final bool openedFromPlayer;

  const EqualizerScreen({
    Key? key,
    required this.audioPlayer,
    this.openedFromPlayer = false,
  }) : super(key: key);

  @override
  _EqualizerScreenState createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen>
    with SingleTickerProviderStateMixin {
  late EqualizerService _equalizerService;
  bool _serviceReady = false;
  late Future<AndroidEqualizerParameters> _paramsFuture;
  late AnimationController _animationController;
  bool _isEnabled = false;
  double _loudnessGain = 0.0;
  String _currentPreset = 'Noize';
  bool _isLoading = false;

  static const Map<String, double> _loudnessProfiles = {
    'Low': 10.0,
    'Medium': 20.0,
    'High': 30.0,
  };
  String _loudnessProfile = 'High';

  Map<String, List<double>> _presets = {};
  Set<String> _customPresetNames = {};

  final ScrollController _presetScrollController = ScrollController();
  Map<String, GlobalKey> _presetKeys = {};

  Future<void> _loadPresets() async {
    final all = await _equalizerService.getAllPresets();
    setState(() {
      _presets = all;
      _customPresetNames = all.keys
          .where((k) => !EqualizerService.builtInPresets.containsKey(k))
          .toSet();

      final existing = _presetKeys;
      _presetKeys = {for (var k in all.keys) k: existing[k] ?? GlobalKey()};
    });

    _ensureCurrentPresetVisible();
  }

  Future<void> _saveCurrentAsPresetPrompt() async {
    final params = await _equalizerService.getEqualizerParameters();
    final bandGains = params.bands.map((b) => b.gain).toList();

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final settingsProvider = Provider.of<SettingsProvider>(context);
        final accentColor = settingsProvider.accentColor;
        return AlertDialog(
          backgroundColor: MainScreenColors.getSurfaceColor(isDarkMode),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          ),
          title: Text(
            'save_preset'.tr(),
            style: TextStyle(color: MainScreenColors.getTextColor(isDarkMode)),
          ),
          content: TextField(
            controller: controller,
            cursorColor: accentColor,
            decoration: InputDecoration(
              hintText: 'preset_name'.tr(),
              hintStyle: TextStyle(color: Colors.grey[500]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: accentColor),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
            ),
            style: TextStyle(color: MainScreenColors.getTextColor(isDarkMode)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr(), style: TextStyle(color: accentColor)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('save'.tr(), style: TextStyle(color: accentColor)),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      await _equalizerService.saveCustomPreset(name, bandGains);
      await _loadPresets();
      setState(() => _currentPreset = name);
      _ensureCurrentPresetVisible();
    }
  }

  Future<void> _renamePresetPrompt(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final settingsProvider = Provider.of<SettingsProvider>(context);
        final accentColor = settingsProvider.accentColor;
        return AlertDialog(
          backgroundColor: MainScreenColors.getSurfaceColor(isDarkMode),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          ),
          title: Text(
            'rename_preset'.tr(),
            style: TextStyle(color: MainScreenColors.getTextColor(isDarkMode)),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'new_name'.tr(),
              hintStyle: TextStyle(color: Colors.grey[500]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: accentColor),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
            ),
            style: TextStyle(color: MainScreenColors.getTextColor(isDarkMode)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr(), style: TextStyle(color: accentColor)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('rename'.tr(), style: TextStyle(color: accentColor)),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final ok = await _equalizerService.renameCustomPreset(oldName, newName);
      if (ok) {
        await _loadPresets();
        setState(() => _currentPreset = newName);
        _ensureCurrentPresetVisible();
      } else {
        AppSnackBar.showError(context, 'name_already_exists'.tr());
      }
    }
  }

  final Map<String, String> _presetDescriptions = {
    'Noize': 'Preset from creator of Noize',
    'Normal': 'Balanced sound across all frequencies',
    'Classical': 'Enhanced mids and highs for orchestral clarity',
    'Dance': 'Boosted bass and treble for electronic music',
    'Folk': 'Warm mids with slight bass reduction',
    'Heavy Metal': 'Enhanced low end and high end for power',
    'Hip Hop': 'Deep bass boost with enhanced low mids',
    'Jazz': 'Balanced mids with subtle bass and treble',
    'Pop': 'Slight boost to bass and higher frequencies',
    'Rock': 'Enhanced low mids and high end for energy',
    'Bass Boost': 'Enhanced low frequencies for powerful bass',
  };

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    if (GetIt.I.isRegistered<EqualizerService>()) {
      _equalizerService = GetIt.I<EqualizerService>();
      _initializeAudioControls();
    } else {
      Future.microtask(() async {
        while (!GetIt.I.isRegistered<EqualizerService>()) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        if (!mounted) return;
        _equalizerService = GetIt.I<EqualizerService>();
        _initializeAudioControls();
      });
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _presetScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAudioControls() async {
    setState(() => _isLoading = true);

    try {
      _paramsFuture = _equalizerService.getEqualizerParameters();
      final params = await _paramsFuture;

      _isEnabled = await _equalizerService.equalizer.enabled;
      _loudnessProfile = _equalizerService.loudnessProfile;
      _loudnessGain = await _equalizerService.loudnessEnhancer.targetGain;
      final maxGain =
          _loudnessProfiles[_loudnessProfile] ?? _loudnessProfiles['High']!;
      if (_loudnessGain > maxGain) {
        _loudnessGain = maxGain;
        await _equalizerService.setLoudnessGain(_loudnessGain);
      }

      _currentPreset = _equalizerService.currentPreset;

      await _loadPresets();
    } catch (e) {
      debugPrint('Error initializing audio controls: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _serviceReady = true;
      });
    }
  }

  void _setLoudness(double value) async {
    setState(() => _loudnessGain = value);
    await _equalizerService.setLoudnessGain(value);
    await _equalizerService.setLoudnessEnabled(value > 0);
  }

  void _toggleEqualizer(bool value) async {
    await _equalizerService.setEqualizerEnabled(value);
    setState(() => _isEnabled = value);
  }

  void _applyPreset(String preset) async {
    try {
      setState(() => _isLoading = true);
      await _equalizerService.applyPreset(preset);
      setState(() {
        _currentPreset = preset;
        _isLoading = false;
      });

      _ensureCurrentPresetVisible();
    } catch (e) {
      setState(() => _isLoading = false);
      AppSnackBar.showError(context, 'error_applying_preset'.tr());
    }
  }

  void _ensureCurrentPresetVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _presetKeys[_currentPreset];
      if (key != null && key.currentContext != null) {
        try {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
            curve: Curves.easeInOut,
          );
        } catch (e) {}
      } else {
        final keysList = _presets.keys.toList();
        final idx = keysList.indexOf(_currentPreset);
        if (idx >= 0 && _presetScrollController.hasClients) {
          final approxItemWidth = AppDimens.headerImageSm;
          final targetOffset = (idx * (approxItemWidth + AppDimens.spacingSm))
              .clamp(0.0, _presetScrollController.position.maxScrollExtent);
          _presetScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final accentColor = settingsProvider.accentColor;

    return SafeArea(
      top: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: MainScreenColors.getBackgroundColor(isDarkMode),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.openedFromPlayer
              ? IconButton(
                  icon: const Icon(Icons.keyboard_double_arrow_down),
                  color: MainScreenColors.getTextColor(isDarkMode),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: Text(
            'Equalizer',
            style: AppTextStyles.appBarTitle(isDarkMode: isDarkMode),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              color: accentColor,
              onPressed: _isEnabled ? _saveCurrentAsPresetPrompt : null,
              tooltip: 'save_preset'.tr(),
            ),
            Switch.adaptive(
              value: _isEnabled,
              onChanged: _toggleEqualizer,
              activeColor: accentColor,
            ),
          ],
        ),
        body: Consumer<PlayerProvider>(
          builder: (context, playerProvider, _) {
            return Stack(
              children: [
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.easeOut,
                        ),
                      ),
                  child: FadeTransition(
                    opacity: _animationController,
                    child: Column(
                      children: [
                        AnimatedOpacity(
                          opacity: _isEnabled ? 1.0 : 0.3,
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            children: [
                              Container(
                                height: AppDimens.buttonSizeDefault,
                                margin: EdgeInsets.symmetric(
                                  vertical: AppDimens.spacingLg,
                                ),
                                child: ListView.builder(
                                  controller: _presetScrollController,
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppDimens.paddingLg,
                                  ),
                                  itemCount: _presets.length,
                                  itemBuilder: (context, index) {
                                    final preset = _presets.keys.elementAt(
                                      index,
                                    );
                                    final isCustom = _customPresetNames
                                        .contains(preset);

                                    final presetKey = _presetKeys.putIfAbsent(
                                      preset,
                                      () => GlobalKey(),
                                    );

                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: AppDimens.spacingSm,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _isEnabled
                                              ? () => _applyPreset(preset)
                                              : null,
                                          onLongPress: isCustom
                                              ? () =>
                                                    _renamePresetPrompt(preset)
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusXxl,
                                          ),
                                          child: Container(
                                            key: presetKey,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: AppDimens.paddingLg,
                                              vertical: AppDimens.spacingS,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppDimens.radiusXxl,
                                                  ),
                                              border: Border.all(
                                                color: _currentPreset == preset
                                                    ? accentColor
                                                    : Colors.grey[700]!,
                                                width: 1.5,
                                              ),
                                              color: _currentPreset == preset
                                                  ? accentColor.withOpacity(0.2)
                                                  : Colors.transparent,
                                            ),
                                            child: Center(
                                              child: Text(
                                                preset,
                                                style:
                                                    AppTextStyles.caption(
                                                      isDarkMode: isDarkMode,
                                                    ).copyWith(
                                                      color:
                                                          _currentPreset ==
                                                              preset
                                                          ? accentColor
                                                          : MainScreenColors.getTextColor(
                                                              isDarkMode,
                                                            ),
                                                      fontWeight: AppTextStyles
                                                          .weightBold,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppDimens.paddingLg,
                                  ),
                                  child: Text(
                                    _presetDescriptions[_currentPreset] ?? '',
                                    key: ValueKey(_currentPreset),
                                    style: AppTextStyles.bodyMd(
                                      isDarkMode: isDarkMode,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppDimens.spacing5Xl),

                        Expanded(
                          child: AnimatedOpacity(
                            opacity: _isEnabled ? 1.0 : 0.3,
                            duration: const Duration(milliseconds: 200),
                            child: FutureBuilder(
                              future: _paramsFuture,
                              builder:
                                  (
                                    context,
                                    AsyncSnapshot<AndroidEqualizerParameters>
                                    snapshot,
                                  ) {
                                    if (!snapshot.hasData) {
                                      return Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                accentColor,
                                              ),
                                        ),
                                      );
                                    }
                                    final params = snapshot.data!;
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppDimens.paddingLg,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: params.bands.map((band) {
                                          return EqualizerBandSlider(
                                            band: band,
                                            params: params,
                                            isEnabled: _isEnabled,
                                            equalizerService: _equalizerService,
                                            onChanged: () => setState(() {}),
                                            customPresetNames:
                                                _customPresetNames,
                                            currentPreset: _currentPreset,
                                            onPresetsReload: _loadPresets,
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),

                        Container(
                          padding: EdgeInsets.all(AppDimens.paddingXxl),

                          decoration: BoxDecoration(
                            color: MainScreenColors.getSurfaceColor(isDarkMode),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppDimens.radiusFull),
                            ),
                          ),
                          child: Column(
                            children: [
                              SizedBox(height: AppDimens.spacingSm),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final maxChildWidth =
                                      constraints.maxWidth >=
                                          AppDimens.breakpointTabletShort
                                      ? AppDimens.chartHeight
                                      : (constraints.maxWidth -
                                                AppDimens.spacingMd) /
                                            2.0;

                                  return Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: AppDimens.spacingMd,
                                    runSpacing: AppDimens.spacingMd,
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: AppDimens.headerImageSm,
                                          maxWidth: maxChildWidth,
                                        ),
                                        child: SizedBox(
                                          width: maxChildWidth,
                                          child: const VolumeCircularSlider(),
                                        ),
                                      ),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: AppDimens.headerImageSm,
                                          maxWidth: maxChildWidth,
                                        ),
                                        child: SizedBox(
                                          width: maxChildWidth,
                                          child: const SpeechCircularSlider(),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              SizedBox(height: AppDimens.spacingXl),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Loudness',
                                        style: AppTextStyles.bodyMd(
                                          isDarkMode: isDarkMode,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        height: AppDimens.iconSm * 1.6,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppDimens.spacingSm,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusS,
                                          ),
                                          border: Border.all(
                                            color: accentColor.withOpacity(0.4),
                                            width: 1,
                                          ),
                                          color: accentColor.withOpacity(0.08),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _loudnessProfile,
                                            isDense: true,
                                            style:
                                                AppTextStyles.caption(
                                                  isDarkMode: isDarkMode,
                                                ).copyWith(
                                                  color: accentColor,
                                                  fontWeight: AppTextStyles
                                                      .weightSemiBold,
                                                ),
                                            dropdownColor:
                                                MainScreenColors.getSurfaceColor(
                                                  isDarkMode,
                                                ),
                                            icon: Icon(
                                              Icons.arrow_drop_down_rounded,
                                              color: accentColor,
                                              size: AppDimens.iconXs,
                                            ),
                                            items: _loudnessProfiles.keys
                                                .map(
                                                  (profile) => DropdownMenuItem(
                                                    value: profile,
                                                    child: Text(
                                                      profile,
                                                      style:
                                                          AppTextStyles.caption(
                                                            isDarkMode:
                                                                isDarkMode,
                                                          ).copyWith(
                                                            color: accentColor,
                                                            fontWeight:
                                                                AppTextStyles
                                                                    .weightSemiBold,
                                                          ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (value) async {
                                              if (value == null) return;
                                              final newMax =
                                                  _loudnessProfiles[value]!;
                                              setState(() {
                                                _loudnessProfile = value;
                                                if (_loudnessGain > newMax) {
                                                  _loudnessGain = newMax;
                                                }
                                              });
                                              await _equalizerService
                                                  .setLoudnessProfile(value);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: AppDimens.spacingSm),
                                  Container(
                                    height: AppDimens.progressSmall,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusS,
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          MainScreenColors.getPrimaryColor(
                                            isDarkMode,
                                          ),
                                          MainScreenColors.getSecondaryColor(
                                            isDarkMode,
                                          ),
                                        ],
                                      ),
                                    ),
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight:
                                            AppDimens.sliderTrackHeight,
                                        activeTrackColor: Colors.transparent,
                                        inactiveTrackColor: Colors.grey[800],
                                        thumbColor: Colors.white,
                                        overlayColor:
                                            MainScreenColors.getPrimaryColor(
                                              isDarkMode,
                                            ).withOpacity(0.2),
                                        thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius:
                                              AppDimens.iconXs / 2,
                                        ),
                                      ),
                                      child: Slider(
                                        value: _loudnessGain.clamp(
                                          0.0,
                                          _loudnessProfiles[_loudnessProfile]!,
                                        ),
                                        min: 0.0,
                                        max:
                                            _loudnessProfiles[_loudnessProfile]!,
                                        divisions: 50,
                                        onChanged: _setLoudness,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
