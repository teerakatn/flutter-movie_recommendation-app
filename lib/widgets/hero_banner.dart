import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class HeroBanner extends StatelessWidget {
  final List<HeroBannerItem> items;
  final void Function(HeroBannerItem) onTap;
  const HeroBanner({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    // Compute a responsive height capped to prevent oversized banners on ultra-wide screens
    double h = size.width * 9 / 16; // 16:9 baseline
    if (h > 500) h = 500; // upper bound
    if (h < 220) h = 220; // lower bound
    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CarouselSlider.builder(
            itemCount: items.length,
            itemBuilder: (context, index, realIdx) {
              final item = items[index];
              return GestureDetector(
                onTap: () => onTap(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.backdropUrl,
                      fit: BoxFit.cover,
                    ),
                    // gradient overlay
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black87,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.tagline ?? item.overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () => onTap(item),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Play'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => onTap(item),
                                icon: const Icon(Icons.info_outline),
                                label: const Text('More info'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            options: CarouselOptions(
              height: h,
              autoPlay: true,
              viewportFraction: 1,
              enlargeCenterPage: false,
              autoPlayCurve: Curves.easeInOut,
              autoPlayInterval: const Duration(seconds: 5),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroBannerItem {
  final int id;
  final String title;
  final String overview;
  final String backdropUrl;
  final String? tagline;
  const HeroBannerItem({
    required this.id,
    required this.title,
    required this.overview,
    required this.backdropUrl,
    this.tagline,
  });
}
