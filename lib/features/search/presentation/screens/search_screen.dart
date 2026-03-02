import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'dart:async';
import '../../../../core/utils/content_router.dart';
import '../widgets/search_screen_shimmer.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/providers/player_provider.dart';
import '../../../../core/providers/queued_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../data/search_screen_services.dart';

class _YouTubeSongWrapper {
  final dynamic _video;

  _YouTubeSongWrapper(this._video);

  String get videoId => _video.id.value;
  String get name => _video.title;
  dynamic get artist =>
      _YouTubeArtistWrapper(_video.author, _video.channelId.value);
  dynamic get thumbnails => [
    _YouTubeThumbnailWrapper(_video.thumbnails.highResUrl, 1280, 720),
  ];

  int get duration => _video.duration?.inSeconds ?? 0;

  bool get isYouTube => true;
}

class _YouTubeArtistWrapper {
  final String _author;
  final String _channelId;

  _YouTubeArtistWrapper(this._author, this._channelId);

  String get name => _author;
  String get artistId => _channelId;
}

class _YouTubeThumbnailWrapper {
  final String _url;
  final int _width;
  final int _height;

  _YouTubeThumbnailWrapper(this._url, this._width, this._height);

  String get url => _url;
  int get width => _width;
  int get height => _height;
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverTabBarDelegate({required this.child, this.height = 48.0});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SearchScreenServices _services = SearchScreenServices();
  bool _isShowingLoadingDialog = false;
  BuildContext? _loadingDialogContext;
  SearchMode _searchMode = SearchMode.youtubeMusic;

  final ValueNotifier<List<String>> _searchHistoryNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _quickSongsNotifier = ValueNotifier([]);
  final ValueNotifier<Map<String, List<dynamic>>> _categorizedResultsNotifier =
      ValueNotifier({
        'Songs': [],
        'Albums': [],
        'Artists': [],
        'Playlists': [],
        'Videos': [],
      });
  final ValueNotifier<List<String>> _searchSuggestionsNotifier = ValueNotifier(
    [],
  );
  Timer? _debounceTimer;
  final ValueNotifier<bool> _showSuggestionsNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _hasErrorNotifier = ValueNotifier(false);
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _getTabCount(), vsync: this);
    _initializeSearchHistory();
    _focusNode.requestFocus();
    _services.isLoadingRelatedSongsNotifier.addListener(
      _onLoadingRelatedSongsChanged,
    );
  }

  int _getTabCount() {
    return _searchMode == SearchMode.youtube ? 1 : 4;
  }

  Future<void> _initializeSearchHistory() async {
    final history = await _services.loadSearchHistory();
    if (!mounted) return;
    _searchHistoryNotifier.value = history;
  }

  Future<void> _onSearchTextChanged(String value) async {
    _debounceTimer?.cancel();
    _showSuggestionsNotifier.value = true;
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final suggestions = await _services.fetchSearchSuggestions(
        value,
        _searchMode,
      );
      final songs = _searchMode == SearchMode.youtubeMusic
          ? await _services.fetchQuickSongs(value)
          : [];

      if (!mounted) return;
      _searchSuggestionsNotifier.value = suggestions;
      _quickSongsNotifier.value = songs;
    });
  }

  Future<void> _onSearch(String query) async {
    _isLoadingNotifier.value = true;
    _hasErrorNotifier.value = false;
    _errorMessage = '';
    _showSuggestionsNotifier.value = false;

    try {
      final results = await _services.performSearch(query, _searchMode);
      if (!mounted) return;
      _categorizedResultsNotifier.value = results;
      _isLoadingNotifier.value = false;

      final updatedHistory = await _services.addToSearchHistory(
        _searchHistoryNotifier.value,
        query,
      );
      if (!mounted) return;
      _searchHistoryNotifier.value = updatedHistory;
    } catch (e) {
      if (!mounted) return;
      _isLoadingNotifier.value = false;
      _hasErrorNotifier.value = true;
      _errorMessage = 'Failed to fetch results. Please try again.';
      setState(() {});
    }
  }

  Future<void> _onRefresh() async {
    if (_searchController.text.isNotEmpty) {
      await _onSearch(_searchController.text);
    }
    _refreshController.refreshCompleted();
  }

  Future<void> _removeSearchHistoryItem(String query) async {
    final updatedHistory = await _services.removeFromSearchHistory(
      _searchHistoryNotifier.value,
      query,
    );
    if (!mounted) return;
    _searchHistoryNotifier.value = updatedHistory;
  }

  Future<void> _playSong(dynamic song) async {
    _focusNode.unfocus();

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final queueProvider = Provider.of<QueueProvider>(context, listen: false);

    try {
      await _services.playSong(song, playerProvider, queueProvider);
    } catch (e) {
      debugPrint('Failed to play song. Please try again.');
      debugPrint('Error playing song: $e');
    }
  }

  void _openContentDetail(dynamic content, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ContentRouter(content: content)),
    );
  }

  void _onLoadingRelatedSongsChanged() {
    if (_services.isLoadingRelatedSongsNotifier.value &&
        !_isShowingLoadingDialog) {
      _showLoadingDialog();
    } else if (!_services.isLoadingRelatedSongsNotifier.value &&
        _isShowingLoadingDialog) {
      _hideLoadingDialog();
    }
  }

  void _showLoadingDialog() {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final accentColor = settingsProvider.accentColor;
    _isShowingLoadingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _loadingDialogContext = dialogContext;
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: accentColor),
              SizedBox(height: 16),
              Text('adding_songs_to_queue'.tr()),
            ],
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (_isShowingLoadingDialog && _loadingDialogContext != null) {
      Navigator.of(_loadingDialogContext!).pop();
      _isShowingLoadingDialog = false;
      _loadingDialogContext = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final accentColor = settingsProvider.accentColor;

    return Theme(
      data: ThemeData(
        scaffoldBackgroundColor: MainScreenColors.getBackgroundColor(
          isDarkMode,
        ),
        cardColor: MainScreenColors.getSurfaceColor(isDarkMode),
        colorScheme: ColorScheme(
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
          primary: accentColor,
          secondary: MainScreenColors.getSecondaryColor(isDarkMode),
          surface: MainScreenColors.getSurfaceColor(isDarkMode),
          background: MainScreenColors.getBackgroundColor(isDarkMode),
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: MainScreenColors.getTextColor(isDarkMode),
          onBackground: MainScreenColors.getTextColor(isDarkMode),
          onError: Colors.white,
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Consumer<PlayerProvider>(
            builder: (context, playerProvider, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _showSuggestionsNotifier,
                builder: (context, showSuggestions, _) {
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, textValue, __) {
                      final shouldShowTabs =
                          textValue.text.trim().isNotEmpty && !showSuggestions;

                      return SmartRefresher(
                        controller: _refreshController,
                        onRefresh: _onRefresh,
                        child: NestedScrollView(
                          headerSliverBuilder: (context, innerBoxIsScrolled) {
                            final slivers = <Widget>[];

                            slivers.add(
                              SliverToBoxAdapter(
                                child: _buildSearchBar(isDarkMode, accentColor),
                              ),
                            );

                            if (shouldShowTabs) {
                              slivers.add(
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _SliverTabBarDelegate(
                                    child: Container(
                                      color: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                AppDimens.isDesktop(context)
                                                ? AppDimens.maxContentWidth
                                                : double.infinity,
                                          ),
                                          child: TabBar(
                                            controller: _tabController,
                                            tabs:
                                                _searchMode ==
                                                    SearchMode.youtube
                                                ? const [Tab(text: 'Videos')]
                                                : const [
                                                    Tab(text: 'Songs'),
                                                    Tab(text: 'Albums'),
                                                    Tab(text: 'Artists'),
                                                    Tab(text: 'Playlists'),
                                                  ],
                                            labelStyle: AppTextStyles.titleSm(
                                              isDarkMode: isDarkMode,
                                            ),
                                            unselectedLabelStyle:
                                                AppTextStyles.caption(
                                                  isDarkMode: isDarkMode,
                                                ),
                                            indicatorColor: accentColor,
                                            labelColor: accentColor,
                                            unselectedLabelColor:
                                                MainScreenColors.getTextColor(
                                                  isDarkMode,
                                                ).withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                    height: 48.0,
                                  ),
                                ),
                              );
                            }

                            return slivers;
                          },
                          body: _buildContent(isDarkMode, accentColor),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode, Color accentColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = AppDimens.isMobile(context);
    final isDesktop = AppDimens.isDesktop(context);
    final maxWidth = isDesktop ? AppDimens.maxContentWidth : double.infinity;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppDimens.paddingLg : AppDimens.paddingXxl,
        vertical: AppDimens.paddingLg,
      ),
      decoration: BoxDecoration(
        color: MainScreenColors.getBackgroundColor(isDarkMode),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              Row(
                children: [
                  if (isMobile) const SizedBox(width: AppDimens.spacingLg),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      cursorColor: accentColor,
                      style: AppTextStyles.bodyMd(isDarkMode: isDarkMode),
                      decoration: InputDecoration(
                        hintText: _searchMode == SearchMode.youtube
                            ? 'Search YouTube videos...'
                            : 'search_hint'.tr(),
                        hintStyle: AppTextStyles.caption(isDarkMode: isDarkMode)
                            .copyWith(
                              color: MainScreenColors.getTextColor(
                                isDarkMode,
                              ).withOpacity(0.5),
                            ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusMd,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusMd,
                          ),
                          borderSide: BorderSide(
                            color: MainScreenColors.getTextColor(
                              isDarkMode,
                            ).withOpacity(0.04),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusMd,
                          ),
                          borderSide: BorderSide(
                            color: accentColor.withOpacity(0.9),
                          ),
                        ),
                        filled: true,
                        fillColor: MainScreenColors.getSurfaceColor(
                          isDarkMode,
                        ).withOpacity(0.95),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.paddingXl,
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, child) {
                            return value.text.isNotEmpty
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.search,
                                          color: MainScreenColors.getTextColor(
                                            isDarkMode,
                                          ).withOpacity(0.5),
                                        ),
                                        onPressed: () {
                                          _focusNode.unfocus();
                                          _showSuggestionsNotifier.value =
                                              false;
                                          _onSearch(_searchController.text);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: MainScreenColors.getTextColor(
                                            isDarkMode,
                                          ).withOpacity(0.5),
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          _categorizedResultsNotifier.value = {
                                            'Songs': [],
                                            'Albums': [],
                                            'Artists': [],
                                            'Playlists': [],
                                            'Videos': [],
                                          };
                                          _searchSuggestionsNotifier.value = [];
                                          _quickSongsNotifier.value = [];
                                          _showSuggestionsNotifier.value =
                                              false;
                                        },
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                      ),
                      onChanged: _onSearchTextChanged,
                      onSubmitted: (value) {
                        _focusNode.unfocus();
                        _showSuggestionsNotifier.value = false;
                        _onSearch(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spacingMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildModeToggleButton(
                    'YouTube Music',
                    _searchMode == SearchMode.youtubeMusic,
                    isDarkMode,
                    accentColor,
                    () => setState(() => _searchMode = SearchMode.youtubeMusic),
                  ),
                  const SizedBox(width: AppDimens.spacingLg),
                  _buildModeToggleButton(
                    'YouTube',
                    _searchMode == SearchMode.youtube,
                    isDarkMode,
                    accentColor,
                    () => setState(() => _searchMode = SearchMode.youtube),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggleButton(
    String text,
    bool isSelected,
    bool isDarkMode,
    Color accentColor,
    VoidCallback onPressed,
  ) {
    final bool isMobile = AppDimens.isMobile(context);
    final double horizontalPadding = isMobile
        ? AppDimens.paddingSm
        : AppDimens.paddingMd;
    final double verticalPadding = isMobile
        ? AppDimens.spacingXs
        : AppDimens.spacingSm;

    final TextStyle textStyle = AppTextStyles.caption(isDarkMode: isDarkMode)
        .copyWith(
          fontWeight: isSelected
              ? AppTextStyles.weightSemiBold
              : AppTextStyles.weightMedium,
          fontSize: isMobile ? AppTextStyles.fontSizeCaption * 0.9 : null,
        );

    return ElevatedButton(
      onPressed: () {
        onPressed();
        _onModeChanged();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? accentColor
            : MainScreenColors.getSurfaceColor(isDarkMode).withOpacity(0.8),
        foregroundColor: isSelected
            ? Colors.white
            : MainScreenColors.getTextColor(isDarkMode),
        elevation: isSelected ? 2 : 0,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            isMobile ? AppDimens.radiusSm : AppDimens.radiusMd,
          ),
        ),
      ),
      child: Text(text, style: textStyle),
    );
  }

  void _onModeChanged() {
    setState(() {
      _tabController.dispose();
      _tabController = TabController(length: _getTabCount(), vsync: this);
      _categorizedResultsNotifier.value = {
        'Songs': [],
        'Albums': [],
        'Artists': [],
        'Playlists': [],
        'Videos': [],
      };
      _searchSuggestionsNotifier.value = [];
      _quickSongsNotifier.value = [];
    });
  }

  Widget _buildContent(bool isDarkMode, Color accentColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showSuggestionsNotifier,
      builder: (context, showSuggestions, child) {
        if (_searchController.text.trim().isEmpty || showSuggestions) {
          return _buildSuggestionsList(isDarkMode, accentColor);
        }

        return ValueListenableBuilder<bool>(
          valueListenable: _isLoadingNotifier,
          builder: (context, isLoading, child) {
            if (isLoading) {
              return _searchController.text.isEmpty
                  ? SearchShimmer.buildHomeShimmer(isDarkMode)
                  : SearchShimmer.buildSearchListShimmer(isDarkMode);
            }

            return ValueListenableBuilder<bool>(
              valueListenable: _hasErrorNotifier,
              builder: (context, hasError, child) {
                if (hasError) {
                  return _buildErrorView(isDarkMode, accentColor);
                }

                return ValueListenableBuilder<Map<String, List<dynamic>>>(
                  valueListenable: _categorizedResultsNotifier,
                  builder: (context, categorizedResults, child) {
                    if (categorizedResults.values.any(
                      (list) => list.isNotEmpty,
                    )) {
                      return _buildSearchResults(isDarkMode, accentColor);
                    }

                    return Center(
                      child: Text(
                        'search_hint'.tr(),
                        style: AppTextStyles.bodyMd(isDarkMode: isDarkMode)
                            .copyWith(
                              color: MainScreenColors.getTextColor(
                                isDarkMode,
                              ).withOpacity(0.5),
                            ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSuggestionsList(bool isDarkMode, Color accentColor) {
    final isDesktop = AppDimens.isDesktop(context);
    final maxWidth = isDesktop ? AppDimens.maxContentWidth : double.infinity;

    if (_searchController.text.trim().isEmpty) {
      return ValueListenableBuilder<List<String>>(
        valueListenable: _searchHistoryNotifier,
        builder: (context, searchHistory, child) {
          if (searchHistory.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _initializeSearchHistory(),
            );
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Text(
                  'search_hint'.tr(),
                  style: AppTextStyles.bodyMd(isDarkMode: isDarkMode).copyWith(
                    color: MainScreenColors.getTextColor(
                      isDarkMode,
                    ).withOpacity(0.5),
                  ),
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView.builder(
                itemCount: searchHistory.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(
                      Icons.history,
                      color: MainScreenColors.getTextColor(
                        isDarkMode,
                      ).withOpacity(0.5),
                    ),
                    title: Text(
                      searchHistory[index],
                      style: AppTextStyles.bodyMd(isDarkMode: isDarkMode),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: MainScreenColors.getTextColor(
                          isDarkMode,
                        ).withOpacity(0.5),
                      ),
                      onPressed: () =>
                          _removeSearchHistoryItem(searchHistory[index]),
                    ),
                    onTap: () {
                      _focusNode.unfocus();
                      _searchController.text = searchHistory[index];
                      setState(() {});
                      _showSuggestionsNotifier.value = false;
                      _onSearch(searchHistory[index]);
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    }

    return ValueListenableBuilder<List<String>>(
      valueListenable: _searchSuggestionsNotifier,
      builder: (context, searchSuggestions, child) {
        return ValueListenableBuilder<List<dynamic>>(
          valueListenable: _quickSongsNotifier,
          builder: (context, quickSongs, child) {
            if (searchSuggestions.isEmpty && quickSongs.isEmpty) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Text(
                    'search_hint'.tr(),
                    style: AppTextStyles.bodyMd(isDarkMode: isDarkMode)
                        .copyWith(
                          color: MainScreenColors.getTextColor(
                            isDarkMode,
                          ).withOpacity(0.5),
                        ),
                  ),
                ),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  children: [
                    ...searchSuggestions.map(
                      (suggestion) => ListTile(
                        leading: Icon(
                          Icons.search,
                          color: MainScreenColors.getTextColor(
                            isDarkMode,
                          ).withOpacity(0.5),
                        ),
                        title: Text(
                          suggestion,
                          style: AppTextStyles.bodyMd(isDarkMode: isDarkMode),
                        ),
                        onTap: () {
                          _focusNode.unfocus();
                          _searchController.text = suggestion;
                          _showSuggestionsNotifier.value = false;
                          _onSearch(suggestion);
                        },
                      ),
                    ),
                    if (quickSongs.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.paddingLg,
                        ),
                        child: Text(
                          'Quick Results',
                          style: AppTextStyles.subtitle(isDarkMode: isDarkMode)
                              .copyWith(
                                color: MainScreenColors.getTextColor(
                                  isDarkMode,
                                ).withOpacity(0.7),
                                fontWeight: AppTextStyles.weightSemiBold,
                              ),
                        ),
                      ),
                      ...quickSongs.map(
                        (song) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.paddingLg,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: song.thumbnails.first.url,
                              width: AppDimens.shimmerListTile,
                              height: AppDimens.shimmerListTile,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: MainScreenColors.getSurfaceColor(
                                  isDarkMode,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: MainScreenColors.getSurfaceColor(
                                  isDarkMode,
                                ),
                                child: Icon(
                                  Icons.error,
                                  color: MainScreenColors.getTextColor(
                                    isDarkMode,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            song.name,
                            style: AppTextStyles.bodyLg(isDarkMode: isDarkMode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song.artist.name,
                            style: AppTextStyles.body2(isDarkMode: isDarkMode)
                                .copyWith(
                                  color: MainScreenColors.getTextColor(
                                    isDarkMode,
                                  ).withOpacity(0.5),
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            _focusNode.unfocus();
                            _playSong(song);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(bool isDarkMode, Color accentColor) {
    if (_searchMode == SearchMode.youtube) {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildVideosList(
            _categorizedResultsNotifier.value['Videos'] ?? [],
            isDarkMode,
            accentColor,
          ),
        ],
      );
    } else {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildSongsList(
            _categorizedResultsNotifier.value['Songs'] ?? [],
            isDarkMode,
            accentColor,
          ),
          _buildContentList(
            _categorizedResultsNotifier.value['Albums'] ?? [],
            'album',
            isDarkMode,
            accentColor,
          ),
          _buildContentList(
            _categorizedResultsNotifier.value['Artists'] ?? [],
            'artist',
            isDarkMode,
            accentColor,
          ),
          _buildContentList(
            _categorizedResultsNotifier.value['Playlists'] ?? [],
            'playlist',
            isDarkMode,
            accentColor,
          ),
        ],
      );
    }
  }

  Widget _buildSongsList(
    List<dynamic> songs,
    bool isDarkMode,
    Color accentColor,
  ) {
    final isDesktop = AppDimens.isDesktop(context);
    final maxWidth = isDesktop ? AppDimens.maxContentWidth : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppDimens.paddingXxl : 0,
            vertical: AppDimens.spacingSm,
          ),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: 0),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingLg,
                vertical: 0,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: song.thumbnails.first.url,
                  width: AppDimens.shimmerListTile,
                  height: AppDimens.shimmerListTile,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: MainScreenColors.getSurfaceColor(isDarkMode),
                    child: Center(
                      child: CircularProgressIndicator(color: accentColor),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: MainScreenColors.getSurfaceColor(isDarkMode),
                    child: Icon(
                      Icons.error,
                      color: MainScreenColors.getTextColor(isDarkMode),
                    ),
                  ),
                ),
              ),
              title: Text(
                song.name,
                style: AppTextStyles.bodyLg(isDarkMode: isDarkMode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist.name,
                style: AppTextStyles.body2(isDarkMode: isDarkMode).copyWith(
                  color: MainScreenColors.getTextColor(
                    isDarkMode,
                  ).withOpacity(0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _playSong(song),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideosList(
    List<dynamic> videos,
    bool isDarkMode,
    Color accentColor,
  ) {
    final isDesktop = AppDimens.isDesktop(context);
    final maxWidth = isDesktop ? AppDimens.maxContentWidth : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppDimens.paddingXxl : 0,
            vertical: AppDimens.spacingSm,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final songWrapper = _createSongWrapper(video);

            return ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: 0),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingLg,
                vertical: 0,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: video.thumbnails.lowResUrl,
                  width: AppDimens.shimmerListTile,
                  height: AppDimens.shimmerListTile,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: MainScreenColors.getSurfaceColor(isDarkMode),
                    child: Center(
                      child: CircularProgressIndicator(color: accentColor),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: MainScreenColors.getSurfaceColor(isDarkMode),
                    child: Icon(
                      Icons.error,
                      color: MainScreenColors.getTextColor(isDarkMode),
                    ),
                  ),
                ),
              ),
              title: Text(
                video.title,
                style: AppTextStyles.bodyLg(isDarkMode: isDarkMode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                video.author,
                style: AppTextStyles.body2(isDarkMode: isDarkMode).copyWith(
                  color: MainScreenColors.getTextColor(
                    isDarkMode,
                  ).withOpacity(0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _playSong(songWrapper),
            );
          },
        ),
      ),
    );
  }

  dynamic _createSongWrapper(dynamic video) {
    return _YouTubeSongWrapper(video);
  }

  Widget _buildContentList(
    List<dynamic> items,
    String type,
    bool isDarkMode,
    Color accentColor,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = AppDimens.isDesktop(context);
    final isTablet = AppDimens.isTablet(context);
    final isMobile = AppDimens.isMobile(context);
    int crossAxisCount = 1;
    if (isDesktop) {
      crossAxisCount = 3;
    } else if (isTablet && !isMobile) {
      crossAxisCount = 2;
    }

    final maxWidth = isDesktop ? AppDimens.maxContentWidth : double.infinity;
    if (crossAxisCount == 1) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: AppDimens.spacingSm),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildContentListItem(
                items[index],
                type,
                isDarkMode,
                accentColor,
              );
            },
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: GridView.builder(
          padding: EdgeInsets.all(
            isDesktop ? AppDimens.paddingXxl : AppDimens.paddingLg,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppDimens.spacingLg,
            mainAxisSpacing: AppDimens.spacingLg,
            childAspectRatio: 3.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildContentGridItem(
              items[index],
              type,
              isDarkMode,
              accentColor,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContentListItem(
    dynamic item,
    String type,
    bool isDarkMode,
    Color accentColor,
  ) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingLg,
        vertical: 0,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(
          type == 'artist' ? AppDimens.radiusAvatar : AppDimens.radiusSm,
        ),
        child: CachedNetworkImage(
          imageUrl: item.thumbnails.first.url,
          width: AppDimens.shimmerListTile,
          height: AppDimens.shimmerListTile,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: MainScreenColors.getSurfaceColor(isDarkMode),
            child: Center(child: CircularProgressIndicator(color: accentColor)),
          ),
          errorWidget: (context, url, error) => Container(
            color: MainScreenColors.getSurfaceColor(isDarkMode),
            child: Icon(
              Icons.error,
              color: MainScreenColors.getTextColor(isDarkMode),
            ),
          ),
        ),
      ),
      title: Text(
        item.name,
        style: AppTextStyles.bodyLg(isDarkMode: isDarkMode),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        type.toUpperCase(),
        style: AppTextStyles.body2(isDarkMode: isDarkMode).copyWith(
          color: MainScreenColors.getTextColor(isDarkMode).withOpacity(0.5),
        ),
      ),
      onTap: () => _openContentDetail(item, type),
    );
  }

  Widget _buildContentGridItem(
    dynamic item,
    String type,
    bool isDarkMode,
    Color accentColor,
  ) {
    return InkWell(
      onTap: () => _openContentDetail(item, type),
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.paddingSm),
        decoration: BoxDecoration(
          color: MainScreenColors.getSurfaceColor(isDarkMode).withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                type == 'artist' ? AppDimens.radiusAvatar : AppDimens.radiusSm,
              ),
              child: CachedNetworkImage(
                imageUrl: item.thumbnails.first.url,
                width: AppDimens.shimmerListTile,
                height: AppDimens.shimmerListTile,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: MainScreenColors.getSurfaceColor(isDarkMode),
                  child: Center(
                    child: CircularProgressIndicator(color: accentColor),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: MainScreenColors.getSurfaceColor(isDarkMode),
                  child: Icon(
                    Icons.error,
                    color: MainScreenColors.getTextColor(isDarkMode),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.bodyLg(isDarkMode: isDarkMode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimens.spacingXxs),
                  Text(
                    type.toUpperCase(),
                    style: AppTextStyles.body2(isDarkMode: isDarkMode).copyWith(
                      color: MainScreenColors.getTextColor(
                        isDarkMode,
                      ).withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentListOld(
    List<dynamic> items,
    String type,
    bool isDarkMode,
    Color accentColor,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppDimens.spacingSm),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingLg,
            vertical: AppDimens.spacingSm,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(
              type == 'artist' ? AppDimens.radiusAvatar : AppDimens.radiusSm,
            ),
            child: CachedNetworkImage(
              imageUrl: item.thumbnails.first.url,
              width: AppDimens.shimmerListTile,
              height: AppDimens.shimmerListTile,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: MainScreenColors.getSurfaceColor(isDarkMode),
                child: Center(
                  child: CircularProgressIndicator(color: accentColor),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: MainScreenColors.getSurfaceColor(isDarkMode),
                child: Icon(
                  Icons.error,
                  color: MainScreenColors.getTextColor(isDarkMode),
                ),
              ),
            ),
          ),
          title: Text(
            item.name,
            style: AppTextStyles.bodyLg(isDarkMode: isDarkMode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            type.toUpperCase(),
            style: AppTextStyles.body2(isDarkMode: isDarkMode).copyWith(
              color: MainScreenColors.getTextColor(isDarkMode).withOpacity(0.5),
            ),
          ),
          onTap: () => _openContentDetail(item, type),
        );
      },
    );
  }

  Widget _buildErrorView(bool isDarkMode, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: AppTextStyles.subtitle(isDarkMode: isDarkMode),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: MainScreenColors.getTextColor(isDarkMode),
            ),
            onPressed: () => _onSearch(_searchController.text),
            child: Text('Retry', style: AppTextStyles.button()),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _services.isLoadingRelatedSongsNotifier.removeListener(
      _onLoadingRelatedSongsChanged,
    );
    _refreshController.dispose();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _searchHistoryNotifier.dispose();
    _quickSongsNotifier.dispose();
    _categorizedResultsNotifier.dispose();
    _searchSuggestionsNotifier.dispose();
    _showSuggestionsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _hasErrorNotifier.dispose();
    super.dispose();
  }
}
