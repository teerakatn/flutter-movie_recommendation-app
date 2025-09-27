import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/favorites_service.dart';
import 'main.dart';
import 'moviedetailpage.dart';

class MyListPage extends StatefulWidget {
  final String apiKey;
  const MyListPage({super.key, required this.apiKey});

  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> {
  late Future<List<Movie>> _movies;

  @override
  void initState() {
    super.initState();
    _movies = _loadFavorites();
  }

  Future<Movie?> _fetchMovieById(int id) async {
    final url = 'https://api.themoviedb.org/3/movie/$id?api_key=${widget.apiKey}&language=en-US';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;
    final map = json.decode(res.body) as Map<String, dynamic>;
    return Movie.fromJson(map);
  }

  Future<List<Movie>> _loadFavorites() async {
    await FavoritesService.I.load();
    final ids = FavoritesService.I.all().toList();
    final List<Movie> result = [];
    for (final id in ids) {
      final m = await _fetchMovieById(id);
      if (m != null) result.add(m);
    }
    return result;
  }

  Future<void> _remove(int id) async {
    await FavoritesService.I.remove(id);
    if (!mounted) return;
    setState(() {
      _movies = _loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My List')),
      body: FutureBuilder<List<Movie>>(
        future: _movies,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final list = snapshot.data ?? const <Movie>[];
          if (list.isEmpty) {
            return const Center(
              child: Text('No items in My List'),
            );
          }
          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              int crossAxisCount = 2;
              if (w >= 1400) {
                crossAxisCount = 8;
              } else if (w >= 1200) {
                crossAxisCount = 7;
              } else if (w >= 1000) {
                crossAxisCount = 6;
              } else if (w >= 800) {
                crossAxisCount = 5;
              } else if (w >= 600) {
                crossAxisCount = 4;
              } else if (w >= 450) {
                crossAxisCount = 3;
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.56,
                ),
                itemBuilder: (context, i) {
                  final m = list[i];
                  return _MyListCard(movie: m, apiKey: widget.apiKey, onRemoved: _remove);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MyListCard extends StatelessWidget {
  final Movie movie;
  final String apiKey;
  final void Function(int id) onRemoved;
  const _MyListCard({required this.movie, required this.apiKey, required this.onRemoved});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, a1, a2) => FadeTransition(
                    opacity: a1,
                    child: MovieDetailPage(movie: movie, apiKey: apiKey),
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 2/3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(topLeft: radius.topLeft, topRight: radius.topRight),
                    child: Image.network(
                      movie.posterPath.isNotEmpty
                        ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}'
                        : 'https://via.placeholder.com/342x513?text=No+Image',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () => onRemoved(movie.id),
            ),
          )
        ],
      ),
    );
  }
}
