import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_text_styles.dart';

/// Colours and metrics measured from the YouTube Music Android app
/// (dark theme, 360dp-wide reference screenshot).
class YtmColors {
  YtmColors._();

  static const Color background = Color(0xFF000000);

  /// Mini player + bottom navigation bar.
  static const Color bar = Color(0xFF1D1D1D);
  static const Color red = Color(0xFFFF0000);
  static const Color avatar = Color(0xFF7B2FBE);

  static Color text(bool isDark) => isDark ? Colors.white : Colors.black;
  static Color textSecondary(bool isDark) =>
      isDark ? const Color(0xFFAAAAAA) : const Color(0xFF606060);
  static Color chip(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.05);
  static Color chipBorder(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.08);
  static Color placeholder(bool isDark) =>
      isDark ? const Color(0xFF282828) : const Color(0xFFE0E0E0);
}

class YtmDimens {
  YtmDimens._();

  static const double sidePadding = 16;
  static const double songThumb = 56;
  static const double songRowHeight = 72;
  static const int quickPickRows = 4;
  static const double cardSize = 150;
  static const double cardGap = 16;
  static const double chipHeight = 32;
}

/// Red play-button mark + "Music" wordmark used in the top bar.
class YtmLogo extends StatelessWidget {
  final bool isDark;

  const YtmLogo({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: YtmColors.red,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: const Padding(
                padding: EdgeInsets.only(left: 1),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'Music',
          style: AppTextStyles.font(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: YtmColors.text(isDark),
          ),
        ),
      ],
    );
  }
}

/// Circular profile avatar shown in the top bar and next to "Quick picks".
class YtmAvatar extends StatelessWidget {
  final double size;

  const YtmAvatar({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: YtmColors.avatar,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, color: Colors.white, size: size * 0.62),
    );
  }
}

/// Artwork that tolerates network URLs, local files, assets and empty values.
class YtmArtwork extends StatelessWidget {
  final String? url;
  final double size;
  final bool circle;
  final double radius;

  const YtmArtwork({
    super.key,
    required this.url,
    required this.size,
    this.circle = false,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = Container(
      width: size,
      height: size,
      color: YtmColors.placeholder(isDark),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.4,
        color: YtmColors.textSecondary(isDark),
      ),
    );

    final value = url?.trim() ?? '';
    Widget image;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      image = CachedNetworkImage(
        imageUrl: value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      );
    } else if (value.startsWith('file://') || value.startsWith('/')) {
      image = Image.file(
        File(value.startsWith('file://') ? value.substring(7) : value),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      image = placeholder;
    }

    if (circle) return ClipOval(child: image);
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

/// Section title row: optional caption / leading avatar, bold title and an
/// outlined pill action ("More", "Play all") on the right.
class YtmShelfHeader extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? leading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const YtmShelfHeader({
    super.key,
    required this.title,
    this.caption,
    this.leading,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        YtmDimens.sidePadding,
        28,
        YtmDimens.sidePadding,
        16,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (caption != null && caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.font(
                        fontSize: 14,
                        color: YtmColors.textSecondary(isDark),
                      ),
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.font(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: YtmColors.text(isDark),
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: YtmColors.text(isDark),
                  side: BorderSide(
                    color: YtmColors.text(isDark).withValues(alpha: 0.25),
                  ),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  actionLabel!,
                  style: AppTextStyles.font(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One entry in a song list shelf (Quick picks style).
class YtmSongRowData {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  const YtmSongRowData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    this.onMore,
  });
}

class YtmSongRow extends StatelessWidget {
  final YtmSongRowData data;

  const YtmSongRow({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: data.onTap,
      onLongPress: data.onMore,
      child: SizedBox(
        height: YtmDimens.songRowHeight,
        child: Row(
          children: [
            YtmArtwork(url: data.imageUrl, size: YtmDimens.songThumb),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.font(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: YtmColors.text(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.font(
                      fontSize: 14,
                      color: YtmColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            if (data.onMore != null)
              IconButton(
                onPressed: data.onMore,
                icon: Icon(Icons.more_vert, color: YtmColors.text(isDark)),
                splashRadius: 20,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Horizontally paged list of songs, [YtmDimens.quickPickRows] per column,
/// with the next column peeking in from the right (YTM "Quick picks").
class YtmSongGrid extends StatefulWidget {
  final List<YtmSongRowData> items;
  final int rows;

  const YtmSongGrid({
    super.key,
    required this.items,
    this.rows = YtmDimens.quickPickRows,
  });

  @override
  State<YtmSongGrid> createState() => _YtmSongGridState();
}

class _YtmSongGridState extends State<YtmSongGrid> {
  PageController? _controller;
  double _fraction = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Column is (screen - 32) wide so the next one peeks by 16dp.
        final pageWidth = width < 600 ? width - 32 : 420.0;
        final fraction = (pageWidth / width).clamp(0.1, 1.0);
        if (_controller == null || _fraction != fraction) {
          _controller?.dispose();
          _fraction = fraction;
          _controller = PageController(viewportFraction: fraction);
        }

        final rows = widget.items.length < widget.rows
            ? widget.items.length
            : widget.rows;
        final pageCount = (widget.items.length / widget.rows).ceil();

        return SizedBox(
          height: rows * YtmDimens.songRowHeight,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: pageCount,
            itemBuilder: (context, page) {
              final start = page * widget.rows;
              final end = (start + widget.rows).clamp(0, widget.items.length);
              return Padding(
                padding: const EdgeInsets.only(left: YtmDimens.sidePadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (var i = start; i < end; i++)
                      YtmSongRow(data: widget.items[i]),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// One square (or circular, for artists) card in a carousel shelf.
class YtmCardData {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool circle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const YtmCardData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    this.circle = false,
    this.onLongPress,
  });
}

class YtmCard extends StatelessWidget {
  final YtmCardData data;
  final double size;

  const YtmCard({
    super.key,
    required this.data,
    this.size = YtmDimens.cardSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: data.onTap,
      onLongPress: data.onLongPress,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: data.circle
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            YtmArtwork(url: data.imageUrl, size: size, circle: data.circle),
            const SizedBox(height: 8),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: data.circle ? TextAlign.center : TextAlign.start,
              style: AppTextStyles.font(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.25,
                color: YtmColors.text(isDark),
              ),
            ),
            if (data.subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: data.circle ? TextAlign.center : TextAlign.start,
                style: AppTextStyles.font(
                  fontSize: 14,
                  color: YtmColors.textSecondary(isDark),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal carousel of [YtmCard]s, optionally stacked [rows] high
/// (YTM "Listen again" uses two rows of smaller cards).
class YtmCardShelf extends StatelessWidget {
  final List<YtmCardData> items;
  final double cardSize;
  final int rows;

  const YtmCardShelf({
    super.key,
    required this.items,
    this.cardSize = YtmDimens.cardSize,
    this.rows = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    // Artwork + gap + two title lines + subtitle line.
    final cardHeight = cardSize + 8 + (2 * 19 + 2 + 18) * textScale + 4;
    final rowCount = items.length < rows ? items.length : rows;
    const rowGap = 16.0;
    final columns = (items.length / rowCount).ceil();

    return SizedBox(
      height: rowCount * cardHeight + (rowCount - 1) * rowGap,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: YtmDimens.sidePadding),
        physics: const BouncingScrollPhysics(),
        itemCount: columns,
        separatorBuilder: (_, __) => const SizedBox(width: YtmDimens.cardGap),
        itemBuilder: (context, column) {
          if (rowCount == 1) {
            return YtmCard(data: items[column], size: cardSize);
          }
          final start = column * rowCount;
          final end = (start + rowCount).clamp(0, items.length);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = start; i < end; i++) ...[
                if (i > start) const SizedBox(height: rowGap),
                SizedBox(
                  height: cardHeight,
                  child: YtmCard(data: items[i], size: cardSize),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Mood / category chips row under the top bar.
class YtmChipsRow extends StatelessWidget {
  final List<String> labels;
  final ValueChanged<String> onSelected;

  const YtmChipsRow({
    super.key,
    required this.labels,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);

    return SizedBox(
      height: YtmDimens.chipHeight * textScale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: YtmDimens.sidePadding),
        physics: const BouncingScrollPhysics(),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = labels[index];
          return Material(
            color: YtmColors.chip(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: YtmColors.chipBorder(isDark)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(label),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    label,
                    style: AppTextStyles.font(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: YtmColors.text(isDark),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Soft colour wash behind the top of Home, fading into black.
class YtmHomeBackdrop extends StatelessWidget {
  final Color color;
  final double height;

  const YtmHomeBackdrop({super.key, required this.color, this.height = 440});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).scaffoldBackgroundColor;
    final strength = isDark ? 0.55 : 0.25;

    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(color.withValues(alpha: strength), base),
                Color.alphaBlend(color.withValues(alpha: strength * 0.5), base),
                base,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
