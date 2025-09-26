import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'moviedetailpage.dart';
import 'widgets/hero_banner.dart';
import 'widgets/movie_row.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
    final darkScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark);
    return MaterialApp(
      title: 'Movie App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        fontFamily: 'Kanit',
        appBarTheme: const AppBarTheme(centerTitle: true),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        fontFamily: 'Kanit',
        appBarTheme: const AppBarTheme(centerTitle: true),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const MovieListPage(),
    );
  }
}

class Movie {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String releaseDate;
  final bool adult;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.adult,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'] ?? 'No title',
      overview: json['overview'] ?? 'No description',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      releaseDate: json['release_date'] ?? 'N/A',
      adult: (json['adult'] as bool?) ?? false,
    );
  }
}

class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key});

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  final String apiKey = "87d3d5d5af2feb2f5c3bf502695190d2"; 
  late Future<List<Movie>> movies; // for search results
  late Future<List<Movie>> popular;
  late Future<List<Movie>> topRated;
  late Future<List<Movie>> upcoming;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  Future<List<Movie>> _fetchCategory(String path, {int target = 20, int maxPages = 3}) async {
    // Generic paginator for movie categories
    final List<Movie> collected = [];
    for (int page = 1; page <= maxPages && collected.length < target; page++) {
      final url = 'https://api.themoviedb.org/3/$path?api_key=$apiKey&language=en-US&page=$page';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        if (page == 1) throw Exception('Failed to load $path');
        break;
      }
      final map = json.decode(res.body) as Map<String, dynamic>;
      final List results = (map['results'] as List?) ?? const [];
      final batch = results
          .map((j) => Movie.fromJson(j as Map<String, dynamic>))
          .where((m) => !m.adult)
          .toList();
      collected.addAll(batch);
    }
    return collected.take(target).toList();
  }

  Future<List<Movie>> fetchMovies() async {
    // Backward-compatible: use as Popular
    return _fetchCategory('movie/popular', target: 56, maxPages: 5);
  }

  Future<List<Movie>> searchMovies(String query) async {
    if (query.isEmpty) return [];
    
    final url =
        "https://api.themoviedb.org/3/search/movie?api_key=$apiKey&language=en-US&query=${Uri.encodeComponent(query)}&page=1&include_adult=false";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final List results = (data['results'] as List?) ?? const [];
      return results
          .map((json) => Movie.fromJson(json as Map<String, dynamic>))
          .where((m) => !m.adult)
          .toList();
    } else {
      throw Exception("Failed to search movies");
    }
  }

  void _performSearch() {
    if (_searchController.text.trim().isNotEmpty) {
      setState(() {
        _isSearching = true;
        movies = searchMovies(_searchController.text.trim());
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      movies = fetchMovies();
    });
  }

  @override
  void initState() {
    super.initState();
    movies = fetchMovies();
    popular = _fetchCategory('movie/popular', target: 20);
    topRated = _fetchCategory('movie/top_rated', target: 20);
    upcoming = _fetchCategory('movie/upcoming', target: 20);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie App'),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
            )
          else
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
        ],
      ),
      body: _isSearching ? _buildSearchBody(context) : _buildHomeBody(context),
    );
  }

  Widget _buildSearchBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: "Search movies/series...",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _performSearch,
                icon: const Icon(Icons.search),
                label: const Text("Search"),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () async {
              setState(() {
                movies = _isSearching
                    ? searchMovies(_searchController.text.trim())
                    : fetchMovies();
              });
              await movies;
            },
            child: FutureBuilder<List<Movie>>(
              future: movies,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 48),
                        const SizedBox(height: 12),
                        Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              movies = _isSearching
                                  ? searchMovies(_searchController.text.trim())
                                  : fetchMovies();
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final movieList = snapshot.data ?? [];
                if (movieList.isEmpty) {
                  return const Center(child: Text('No movies found', style: TextStyle(fontSize: 18)));
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    int crossAxisCount;
                    if (width >= 1400) {
                      crossAxisCount = 8;
                    } else if (width >= 1200) {
                      crossAxisCount = 7;
                    } else if (width >= 1000) {
                      crossAxisCount = 6;
                    } else if (width >= 800) {
                      crossAxisCount = 5;
                    } else if (width >= 600) {
                      crossAxisCount = 4;
                    } else if (width >= 450) {
                      crossAxisCount = 3;
                    } else {
                      crossAxisCount = 2;
                    }
                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: movieList.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.56,
                      ),
                      itemBuilder: (context, index) {
                        final m = movieList[index];
                        return _MovieGridCard(movie: m, apiKey: apiKey);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeBody(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: () async {
        setState(() {
          popular = _fetchCategory('movie/popular', target: 20);
          topRated = _fetchCategory('movie/top_rated', target: 20);
          upcoming = _fetchCategory('movie/upcoming', target: 20);
        });
        await Future.wait([popular, topRated, upcoming]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Hero Banner from popular movies with backdrops
            FutureBuilder<List<Movie>>(
              future: popular,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  // simple placeholder aspect ratio
                  return AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  );
                }
                final items = snapshot.data!
                    .where((m) => m.backdropPath.isNotEmpty)
                    .take(6)
                    .map((m) => HeroBannerItem(
                          id: m.id,
                          title: m.title,
                          overview: m.overview,
                          backdropUrl: 'https://image.tmdb.org/t/p/w1280${m.backdropPath}',
                        ))
                    .toList();
                return HeroBanner(
                  items: items,
                  onTap: (i) {
                    final movie = snapshot.data!.firstWhere((m) => m.id == i.id, orElse: () => snapshot.data!.first);
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, a1, a2) => FadeTransition(
                          opacity: a1,
                          child: MovieDetailPage(movie: movie, apiKey: apiKey),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'Popular'),
            ),
            FutureBuilder<List<Movie>>(
              future: popular,
              builder: (context, snapshot) {
                final list = snapshot.data ?? const <Movie>[];
                final items = list
                    .where((m) => m.posterPath.isNotEmpty)
                    .map((m) => MovieCardData(id: m.id, title: m.title, posterUrl: 'https://image.tmdb.org/t/p/w300${m.posterPath}'))
                    .toList();
                return MovieRow(
                  items: items,
                  onTap: (it) {
                    final movie = list.firstWhere((m) => m.id == it.id, orElse: () => list.first);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, a1, a2) => FadeTransition(
                          opacity: a1,
                          child: MovieDetailPage(movie: movie, apiKey: apiKey),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'Top Rated'),
            ),
            FutureBuilder<List<Movie>>(
              future: topRated,
              builder: (context, snapshot) {
                final list = snapshot.data ?? const <Movie>[];
                final items = list
                    .where((m) => m.posterPath.isNotEmpty)
                    .map((m) => MovieCardData(id: m.id, title: m.title, posterUrl: 'https://image.tmdb.org/t/p/w300${m.posterPath}'))
                    .toList();
                return MovieRow(
                  items: items,
                  onTap: (it) {
                    final movie = list.firstWhere((m) => m.id == it.id, orElse: () => list.first);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, a1, a2) => FadeTransition(
                          opacity: a1,
                          child: MovieDetailPage(movie: movie, apiKey: apiKey),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'Upcoming'),
            ),
            FutureBuilder<List<Movie>>(
              future: upcoming,
              builder: (context, snapshot) {
                final list = snapshot.data ?? const <Movie>[];
                final items = list
                    .where((m) => m.posterPath.isNotEmpty)
                    .map((m) => MovieCardData(id: m.id, title: m.title, posterUrl: 'https://image.tmdb.org/t/p/w300${m.posterPath}'))
                    .toList();
                return MovieRow(
                  items: items,
                  onTap: (it) {
                    final movie = list.firstWhere((m) => m.id == it.id, orElse: () => list.first);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, a1, a2) => FadeTransition(
                          opacity: a1,
                          child: MovieDetailPage(movie: movie, apiKey: apiKey),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MovieGridCard extends StatelessWidget {
  final Movie movie;
  final String apiKey;
  const _MovieGridCard({required this.movie, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
              aspectRatio: 2 / 3,
              child: movie.posterPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: radius.topLeft,
                        topRight: radius.topRight,
                      ),
                      child: Image.network(
                        "https://image.tmdb.org/t/p/w500${movie.posterPath}",
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}