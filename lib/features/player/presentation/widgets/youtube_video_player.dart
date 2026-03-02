import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../core/constants/app_dimens.dart';
import 'dart:io' show Platform;

class VideoPlayerWidget extends StatefulWidget {
  final String videoId;
  final VoidCallback onReady;
  final bool hideAppBar;
  final VoidCallback onFullScreenChange;

  const VideoPlayerWidget({
    Key? key,
    required this.videoId,
    required this.onReady,
    required this.hideAppBar,
    required this.onFullScreenChange,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late YoutubePlayerController _controller;
  bool _isFullScreen = false;
  late InAppWebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows && !Platform.isLinux) {
      _initializeYoutubePlayer();
    }
  }

  void _initializeYoutubePlayer() {
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
        showLiveFullscreenButton: true,
        hideControls: false,
        disableDragSeek: false,
      ),
    );

    _controller.addListener(() {
      if (_controller.value.isReady) {
        widget.onReady();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isLinux) {
      return Container(
        height: AppDimens.progressCircleLarge,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusXxl),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: AppDimens.elevationHigh,
              offset: const Offset(0, AppDimens.spacingSmMd),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusXxl),
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('https://www.yout-ube.com/watch?v=${widget.videoId}'),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              widget.onReady();
            },
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: _isFullScreen
            ? BorderRadius.zero
            : BorderRadius.circular(AppDimens.radiusXxl),
        boxShadow: _isFullScreen
            ? []
            : [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: AppDimens.elevationHigh,
                  offset: const Offset(0, AppDimens.spacingSmMd),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: _isFullScreen
            ? BorderRadius.zero
            : BorderRadius.circular(AppDimens.radiusXxl),
        child: YoutubePlayerBuilder(
          player: YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.white,
            progressColors: const ProgressBarColors(
              playedColor: Colors.white,
              handleColor: Colors.white,
            ),
            topActions: [
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (_isFullScreen) {
                    _controller.toggleFullScreenMode();
                  }
                },
              ),
            ],
            bottomActions: const [
              CurrentPosition(),
              SizedBox(width: AppDimens.spacingSmMd),
              ProgressBar(
                isExpanded: true,
                colors: ProgressBarColors(
                  playedColor: Colors.white,
                  handleColor: Colors.white,
                  bufferedColor: Colors.white54,
                  backgroundColor: Colors.grey,
                ),
              ),
              SizedBox(width: AppDimens.spacingSmMd),
              RemainingDuration(),
            ],
          ),
          builder: (context, player) {
            return player;
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!Platform.isWindows && !Platform.isLinux) {
      _controller.dispose();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }
}
