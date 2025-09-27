import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

class MovieRow extends StatefulWidget {
  final List<MovieCardData> items;
  final void Function(MovieCardData) onTap;
  const MovieRow({super.key, required this.items, required this.onTap});

  @override
  State<MovieRow> createState() => _MovieRowState();
}

class _MovieRowState extends State<MovieRow> {
  static const double _itemWidth = 130.0;
  static const double _gap = 10.0;
  final ScrollController _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateButtons);
    // Ensure button state reflects initial scroll metrics
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateButtons());
  }

  void _updateButtons() {
    if (!_controller.hasClients) return;
    final atStart = _controller.offset <= 0.5;
    final atEnd = (_controller.position.maxScrollExtent - _controller.offset) <= 0.5;
    if (atStart != !_canBack || atEnd != !_canForward) {
      setState(() {
        _canBack = !atStart;
        _canForward = !atEnd;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateButtons);
    _controller.dispose();
    super.dispose();
  }

  double _pageStep(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final visible = ((width - 32) / (_itemWidth + _gap)).floor();
    final stepCount = visible > 1 ? visible - 1 : 1; // keep an overlap
    return stepCount * (_itemWidth + _gap);
  }

  Future<void> _scrollBy(BuildContext context, {required bool forward}) async {
    if (!_controller.hasClients) return;
    final delta = _pageStep(context) * (forward ? 1 : -1);
    final target = (_controller.offset + delta).clamp(0.0, _controller.position.maxScrollExtent);
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      // shimmer skeletons
      return SizedBox(
        height: 240,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, __) => SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AspectRatio(aspectRatio: 2 / 3, child: _PosterSkeleton()),
                SizedBox(height: 6),
              ],
            ),
          ),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: 8,
        ),
      );
    }
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          ListView.separated(
            controller: _controller,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => MovieCard(item: widget.items[index], onTap: widget.onTap),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: widget.items.length,
          ),
          // Left overlay button (narrow hit area, won't block list)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_canBack,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _canBack ? 1 : 0,
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Theme.of(context).colorScheme.surface, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              onPressed: _canBack ? () => _scrollBy(context, forward: false) : null,
              icon: const Icon(Icons.chevron_left),
            ),
          ),
          // Right overlay button
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_canForward,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _canForward ? 1 : 0,
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Theme.of(context).colorScheme.surface, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              onPressed: _canForward ? () => _scrollBy(context, forward: true) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}

class MovieCardData {
  final int id;
  final String title;
  final String posterUrl;
  const MovieCardData({required this.id, required this.title, required this.posterUrl});
}

class MovieCard extends StatelessWidget {
  final MovieCardData item;
  final void Function(MovieCardData) onTap;
  const MovieCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: LayoutBuilder(
        builder: (context, c) {
          final maxH = c.maxHeight == double.infinity ? 240.0 : c.maxHeight;
          // Reserve ~36px for text+spacing
          final availableForPoster = (maxH - 36).clamp(140.0, 1000.0);
          final posterH = availableForPoster;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: posterH,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LongPressDraggable<MovieCardData>(
                    data: item,
                    feedback: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        height: posterH * 0.6,
                        width: (posterH * 0.6) / 1.5,
                        child: CachedNetworkImage(
                          imageUrl: item.posterUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    childWhenDragging: const _PosterSkeleton(),
                    child: InkWell(
                      onTap: () => onTap(item),
                      child: CachedNetworkImage(
                        imageUrl: item.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const _PosterSkeleton(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  item.title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PosterSkeleton extends StatelessWidget {
  const _PosterSkeleton();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
