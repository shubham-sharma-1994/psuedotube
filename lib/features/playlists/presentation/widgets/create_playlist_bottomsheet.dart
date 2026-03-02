import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../data/providers/playlist_album_library_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/content_details_service.dart';
import '../../../../shared/components/app_snackbar.dart';

class CreatePlaylistBottomSheet extends StatefulWidget {
  const CreatePlaylistBottomSheet({Key? key}) : super(key: key);

  @override
  _CreatePlaylistBottomSheetState createState() =>
      _CreatePlaylistBottomSheetState();
}

class _CreatePlaylistBottomSheetState extends State<CreatePlaylistBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _playlistNameController = TextEditingController();
  final TextEditingController _importLinkController = TextEditingController();
  List<Map<String, dynamic>> _playlists = [];
  final ContentDetailsService _contentDetailsService = ContentDetailsService();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlaylists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _playlistNameController.dispose();
    _importLinkController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    final provider = Provider.of<PlaylistAlbumLibraryProvider>(
      context,
      listen: false,
    );
    await provider.loadCreatedPlaylists();
    setState(() {
      _playlists = provider.createdPlaylists;
    });
  }

  Future<void> _createNewPlaylist() async {
    if (_playlistNameController.text.isEmpty) return;

    final provider = Provider.of<PlaylistAlbumLibraryProvider>(
      context,
      listen: false,
    );
    try {
      await provider.saveCreatedPlaylist(_playlistNameController.text);
    } catch (e) {
      AppSnackBar.showError(
        context,
        'Playlist "${_playlistNameController.text}" already exists!',
      );
      return;
    }

    await provider.loadCreatedPlaylists();

    AppSnackBar.showSuccess(
      context,
      'Playlist "${_playlistNameController.text}" created!',
    );

    _playlistNameController.clear();
    Navigator.pop(context, true);
  }

  Future<void> _importPlaylist() async {
    if (_importLinkController.text.isEmpty) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final String url = _importLinkController.text;
      final String? playlistId = _contentDetailsService.extractPlaylistId(url);

      if (playlistId == null) {
        AppSnackBar.showError(
          context,
          'Invalid YouTube/YouTube Music playlist link.',
        );
        return;
      }

      final playlistData = await _contentDetailsService.getPlaylistDetails(
        playlistId,
      );

      if (playlistData == null) {
        AppSnackBar.showError(context, 'Could not fetch playlist details.');
        return;
      }

      final provider = Provider.of<PlaylistAlbumLibraryProvider>(
        context,
        listen: false,
      );

      if ((playlistData['contentType'] as String?)?.toLowerCase() == 'album') {
        final albumData = {
          'name': playlistData['name'],
          'thumbnail': playlistData['thumbnail'],
          'duration': playlistData['duration'],

          'albumId': playlistData['playlistId'],
          'contentType': 'Album',
          'artist': playlistData['artist'],
        };
        await provider.saveAlbum(albumData);
      } else {
        final playlistSaveData = {
          'name': playlistData['name'],
          'thumbnail': playlistData['thumbnail'],
          'duration': playlistData['duration'],
          'playlistId': playlistData['playlistId'],
          'contentType': 'Playlist',
          'artist': playlistData['artist'],
        };
        await provider.savePlaylist(playlistSaveData);
      }

      final importedType =
          (playlistData['contentType'] as String?) ?? 'Playlist';
      AppSnackBar.showSuccess(
        context,
        '$importedType "${playlistData['name']}" imported!',
      );

      _importLinkController.clear();
      Navigator.pop(context, true);
    } catch (e) {
      AppSnackBar.showError(context, 'Error importing playlist: $e');
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final accentColor = settingsProvider.accentColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: screenHeight * 0.6,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: MainScreenColors.getSurfaceColor(isDarkMode),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: accentColor,
              labelColor: accentColor,
              unselectedLabelColor: MainScreenColors.getTextColor(
                isDarkMode,
              ).withOpacity(0.6),
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'Create Playlist'),
                Tab(text: 'Import Playlist'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      TextField(
                        controller: _playlistNameController,
                        cursorColor: accentColor,
                        decoration: InputDecoration(
                          hintText: 'Enter Playlist Name',
                          filled: true,
                          fillColor: MainScreenColors.getTextColor(
                            isDarkMode,
                          ).withOpacity(0.1),
                          hintStyle: TextStyle(
                            color: MainScreenColors.getTextColor(
                              isDarkMode,
                            ).withOpacity(0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: accentColor,
                            ),
                            onPressed: _createNewPlaylist,
                          ),
                        ),
                        style: TextStyle(
                          color: MainScreenColors.getTextColor(isDarkMode),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = _playlists[index];
                            return Card(
                              elevation: 0,
                              color: MainScreenColors.getTextColor(
                                isDarkMode,
                              ).withOpacity(0.05),
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                title: Text(
                                  playlist['name'],
                                  style: TextStyle(
                                    color: MainScreenColors.getTextColor(
                                      isDarkMode,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  Column(
                    children: [
                      TextField(
                        cursorColor: accentColor,

                        controller: _importLinkController,
                        decoration: InputDecoration(
                          hintText: 'Enter YouTube/YouTube Music Playlist Link',
                          filled: true,
                          fillColor: MainScreenColors.getTextColor(
                            isDarkMode,
                          ).withOpacity(0.1),
                          hintStyle: TextStyle(
                            color: MainScreenColors.getTextColor(
                              isDarkMode,
                            ).withOpacity(0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        style: TextStyle(
                          color: MainScreenColors.getTextColor(isDarkMode),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isImporting ? null : _importPlaylist,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.cloud_download,
                                color: Colors.black,
                              ),
                        label: Text(
                          _isImporting ? 'Importing...' : 'Import Playlist',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
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
    );
  }
}
