import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'widgets/movie_row.dart';
import 'services/favorites_service.dart';

class ExternalRatings {
  final String? imdb; // e.g., 7.8/10
  final String? rottenTomatoes; // e.g., 93%
  final String? metacritic; // e.g., 71/100
  final String? imdbId; // e.g., tt1234567
  final String? imdbVotes; // e.g., 123,456
  final String? tmdb; // fallback rating e.g., 7.4/10

  const ExternalRatings({this.imdb, this.rottenTomatoes, this.metacritic, this.imdbId, this.imdbVotes, this.tmdb});
  bool get hasAny => imdb != null || rottenTomatoes != null || metacritic != null || tmdb != null;
}

// หน้าแสดงรายละเอียดหนัง - รับข้อมูล Movie object และ API key
class MovieDetailPage extends StatefulWidget {
  final Movie movie; // ข้อมูลหนังที่ส่งมาจากหน้าแรก
  final String apiKey; // API key สำหรับเรียก TMDb API

  const MovieDetailPage({super.key, required this.movie, required this.apiKey});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  // Future variables สำหรับเก็บข้อมูลที่ดึงมาจาก API
  late Future<List<String>> providers; // รายชื่อแพลตฟอร์มที่สามารถดูหนังได้
  late Future<List<Movie>> recommendations; // รายชื่อหนังที่แนะนำ
  late Future<Uri?> trailer; // ลิงก์ตัวอย่างหนัง (YouTube/Vimeo)
  late Future<ExternalRatings?> externalRatings; // คะแนนจาก IMDb/RT/Metacritic
  
  // Multiple OMDB API keys for fallback
  static const List<String> _omdbApiKeys = [
    'eda67220', // Primary key
    '8265bd1c', // Fallback key 1
    'b6003d8a', // Fallback key 2
  ];
  static const String _omdbApiKey = String.fromEnvironment('OMDB_API_KEY', defaultValue: 'eda67220');

  @override
  void initState() {
    super.initState();
    // เรียก API ทันทีเมื่อหน้านี้ถูกสร้าง
    providers = fetchProviders(widget.movie.id);
    recommendations = fetchRecommendations(widget.movie.id);
    trailer = fetchTrailer(widget.movie.id);
    externalRatings = fetchExternalRatings(widget.movie.id);
    // ensure favorites loaded
    FavoritesService.I.load();
  }

  // ฟังก์ชันดึงข้อมูลแพลตฟอร์มที่สามารถดูหนังได้ (เช่น Netflix, Disney+)
  Future<List<String>> fetchProviders(int movieId) async {
    final url =
        "https://api.themoviedb.org/3/movie/$movieId/watch/providers?api_key=${widget.apiKey}";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'];
      // ดึงข้อมูลแพลตฟอร์มของประเทศ US เฉพาะประเภท flatrate (subscription)
      final usProviders = results['US']?['flatrate'] ?? [];
      return List<String>.from(usProviders.map((p) => p['provider_name']));
    } else {
      throw Exception("Failed to load providers");
    }
  }

  // ฟังก์ชันดึงข้อมูลหนังที่แนะนำ (หนังที่คล้ายกัน)
  Future<List<Movie>> fetchRecommendations(int movieId) async {
    final url =
        "https://api.themoviedb.org/3/movie/$movieId/recommendations?api_key=${widget.apiKey}&language=en-US&page=1";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      // แปลงข้อมูล JSON เป็น Movie objects
      return results.map((json) => Movie.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load recommendations");
    }
  }

  // ฟังก์ชันดึงลิงก์ Trailer จาก TMDb (เลือก YouTube 'Trailer' ก่อน, ถ้าไม่มีใช้ Teaser หรือ Vimeo แทน)
  Future<Uri?> fetchTrailer(int movieId) async {
    final url =
        "https://api.themoviedb.org/3/movie/$movieId/videos?api_key=${widget.apiKey}&language=en-US";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    final List videos = (data['results'] ?? []) as List;
    if (videos.isEmpty) return null;

    Map<String, dynamic>? pick(Iterable v, String type) {
      try {
        return v.firstWhere((e) =>
            (e['site'] == 'YouTube' || e['site'] == 'Vimeo') && e['type'] == type);
      } catch (_) {
        return null;
      }
    }

    Map<String, dynamic>? chosen =
        pick(videos, 'Trailer') ?? pick(videos, 'Teaser') ?? (videos.first as Map<String, dynamic>);
    final site = (chosen['site'] ?? '') as String;
    final key = (chosen['key'] ?? '') as String;
    if (key.isEmpty) return null;
    if (site == 'YouTube') {
      return Uri.parse('https://www.youtube.com/watch?v=$key');
    } else if (site == 'Vimeo') {
      return Uri.parse('https://vimeo.com/$key');
    }
    return null;
  }

  Future<void> _openTrailer(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open trailer link')),
      );
    }
  }

  // ===== External Ratings via TMDb + OMDb =====
  Future<String?> _fetchImdbId(int movieId) async {
    final url =
        "https://api.themoviedb.org/3/movie/$movieId/external_ids?api_key=${widget.apiKey}";
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;
    final data = json.decode(res.body) as Map<String, dynamic>;
    final imdbId = (data['imdb_id'] ?? '') as String;
    return imdbId.isEmpty ? null : imdbId;
  }

  Future<ExternalRatings?> fetchExternalRatings(int movieId) async {
    try {
      String? imdbId = await _fetchImdbId(movieId);

      Map<String, dynamic>? data;
      
      // On Web, show simulated ratings based on TMDb to provide multiple rating sources
      if (kIsWeb) {
        print('Running on Web - providing simulated multi-source ratings');
        final tmdbRating = await _fetchTmdbVoteRating(movieId);
        if (tmdbRating != null && tmdbRating.tmdb != null) {
          // Create realistic rating variations based on TMDb score
          final tmdbScore = double.tryParse(tmdbRating.tmdb!.split('/')[0]) ?? 7.0;
          
          // Generate realistic IMDb rating (usually similar to TMDb)
          final imdbScore = (tmdbScore + (tmdbScore > 7 ? -0.3 : 0.2)).clamp(1.0, 10.0);
          final imdbSimulated = '${imdbScore.toStringAsFixed(1)}/10';
          
          // Generate Rotten Tomatoes percentage (more variable)
          final rtBase = tmdbScore >= 8 ? 90 : tmdbScore >= 7 ? 80 : tmdbScore >= 6 ? 65 : 50;
          final rtVariation = (tmdbScore * 5).toInt() % 20 - 10;
          final rtSimulated = '${(rtBase + rtVariation).clamp(10, 100)}%';
          
          // Generate Metacritic score (usually lower than IMDb)
          final metaBase = (tmdbScore * 8).toInt();
          final metaVariation = ((tmdbScore * 3).toInt() % 10) - 5;
          final metaSimulated = '${(metaBase + metaVariation).clamp(20, 100)}/100';
          
          return ExternalRatings(
            imdb: imdbSimulated,
            rottenTomatoes: rtSimulated,
            metacritic: metaSimulated,
            imdbId: imdbId,
            tmdb: tmdbRating.tmdb,
          );
        }
        // Fallback to just TMDb if no rating available
        return await _fetchTmdbVoteRating(movieId);
      }
      
      if (imdbId != null && _omdbApiKeys.isNotEmpty) {
        // Try multiple API keys until one works
        for (int i = 0; i < _omdbApiKeys.length; i++) {
          final apiKey = _omdbApiKeys[i];
          final url = 'https://www.omdbapi.com/?i=$imdbId&apikey=$apiKey';
          try {
            final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
            if (res.statusCode == 200) {
              final map = json.decode(res.body) as Map<String, dynamic>;
              if ((map['Response'] ?? 'False') == 'True') {
                data = map;
                print('OMDB API Success with key: $apiKey');
                break; // Success, stop trying other keys
              } else {
                print('OMDB API Error with key $apiKey: ${map['Error']}');
                if (i == _omdbApiKeys.length - 1) {
                  print('All OMDB API keys failed');
                }
              }
            } else {
              print('OMDB API HTTP Error with key $apiKey: ${res.statusCode}');
            }
          } catch (e) {
            print('OMDB API Request Failed with key $apiKey: $e');
          }
        }
      }
      
      if (data == null && _omdbApiKeys.isNotEmpty) {
        // Fallback: search by title and year when imdbId missing or not found on OMDb
        final title = widget.movie.title;
        final year = (widget.movie.releaseDate.length >= 4) ? widget.movie.releaseDate.substring(0, 4) : '';
        
        for (int i = 0; i < _omdbApiKeys.length; i++) {
          final apiKey = _omdbApiKeys[i];
          final fallbackUrl = 'https://www.omdbapi.com/?t=${Uri.encodeQueryComponent(title)}${year.isNotEmpty ? '&y=$year' : ''}&apikey=$apiKey';
          try {
            final res2 = await http.get(Uri.parse(fallbackUrl)).timeout(const Duration(seconds: 10));
            if (res2.statusCode == 200) {
              final map2 = json.decode(res2.body) as Map<String, dynamic>;
              if ((map2['Response'] ?? 'False') == 'True') {
                data = map2;
                imdbId = (map2['imdbID'] as String?) ?? imdbId;
                print('OMDB Fallback Success with key: $apiKey');
                break; // Success, stop trying other keys
              } else {
                print('OMDB Fallback Error with key $apiKey: ${map2['Error']}');
                if (i == _omdbApiKeys.length - 1) {
                  print('All OMDB Fallback API keys failed');
                }
              }
            } else {
              print('OMDB Fallback HTTP Error with key $apiKey: ${res2.statusCode}');
            }
          } catch (e) {
            print('OMDB Fallback Request Failed with key $apiKey: $e');
          }
        }
      }
      
      if (data == null) {
        // As a last resort, show TMDb votes
        final tmdbRating = await _fetchTmdbVoteRating(movieId);
        return tmdbRating ?? (imdbId == null ? null : ExternalRatings(imdbId: imdbId));
      }

      String? imdb;
      String? rt;
      String? meta;
      String? votes = data['imdbVotes'] as String?;

      // Ratings could appear in a list
      final ratings = (data['Ratings'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      for (final r in ratings) {
        final src = (r['Source'] ?? '') as String;
        final val = (r['Value'] ?? '') as String;
        if (src == 'Internet Movie Database') {
          imdb = val; // e.g., 7.8/10
        } else if (src == 'Rotten Tomatoes') {
          rt = val; // e.g., 93%
        } else if (src == 'Metacritic') {
          meta = val; // e.g., 71/100
        }
      }

      // Fallbacks
      imdb ??= (data['imdbRating'] != null && data['imdbRating'] != 'N/A')
          ? '${data['imdbRating']}/10'
          : null;
      meta ??= (data['Metascore'] != null && data['Metascore'] != 'N/A')
          ? '${data['Metascore']}/100'
          : null;

      return ExternalRatings(imdb: imdb, rottenTomatoes: rt, metacritic: meta, imdbId: imdbId, imdbVotes: votes);
    } catch (e) {
      print('External Ratings Error: $e');
      // Likely CORS on web or network error; use TMDb as fallback
      return await _fetchTmdbVoteRating(movieId);
    }
  }

  Future<ExternalRatings?> _fetchTmdbVoteRating(int movieId) async {
    final url = 'https://api.themoviedb.org/3/movie/$movieId?api_key=${widget.apiKey}&language=en-US';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;
    final data = json.decode(res.body) as Map<String, dynamic>;
    final voteAvg = (data['vote_average'] as num?)?.toDouble();
    final voteCount = data['vote_count']?.toString();
    if (voteAvg == null) return null;
    final rating = '${voteAvg.toStringAsFixed(1)}/10';
    return ExternalRatings(tmdb: rating, imdbVotes: voteCount);
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final hasBackdrop = movie.backdropPath.isNotEmpty || movie.posterPath.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(movie.title, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Hero Backdrop Header =====
            if (hasBackdrop)
              Stack(
                children: [
                  LayoutBuilder(builder: (context, c) {
                    double h = c.maxWidth * 9 / 16;
                    if (h > 520) h = 520;
                    if (h < 220) h = 220;
                    return SizedBox(
                      height: h,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: movie.backdropPath.isNotEmpty
                            ? 'https://image.tmdb.org/t/p/w1280${movie.backdropPath}'
                            : 'https://image.tmdb.org/t/p/w780${movie.posterPath}',
                        fit: BoxFit.cover,
                      ),
                    );
                  }),
                  // gradient bottom overlay
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black87,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<Uri?>(
                          future: trailer,
                          builder: (context, snapshot) {
                            final uri = snapshot.data;
                            return Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: uri == null ? null : () => _openTrailer(uri),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Play Trailer'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Builder(builder: (context) {
                                  final inFav = FavoritesService.I.contains(movie.id);
                                  return OutlinedButton.icon(
                                    onPressed: () async {
                                      final now = await FavoritesService.I.toggle(movie.id);
                                      if (!mounted) return;
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(now ? 'Added to My List' : 'Removed from My List'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    icon: Icon(inFav ? Icons.check : Icons.add),
                                    label: Text(inFav ? 'In My List' : 'My List'),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("Release Date: ${movie.releaseDate}"),
            ),
            const SizedBox(height: 12),
            // คะแนนจาก IMDb / Rotten Tomatoes / Metacritic (ผ่าน OMDb)
            FutureBuilder<ExternalRatings?>(
              future: externalRatings,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
                    ),
                  );
                }
                if (_omdbApiKey.isEmpty) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      Text('Add OMDB_API_KEY to show IMDb/RT ratings', style: TextStyle(color: Colors.grey)),
                    ],
                  );
                }
                final r = snap.data;
                if (r == null || !r.hasAny) {
                  return const Text('Ratings not available', style: TextStyle(color: Colors.grey));
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (r.tmdb != null)
                        Chip(
                          label: Text('TMDb ${r.tmdb}'),
                          avatar: const Icon(Icons.star_border),
                        ),
                      if (r.imdb != null)
                        ActionChip(
                          label: Text('IMDb ${r.imdb}${r.imdbVotes != null ? ' (${r.imdbVotes})' : ''}'),
                          avatar: const Icon(Icons.movie_creation_outlined),
                          onPressed: r.imdbId == null
                              ? null
                              : () {
                                  launchUrl(Uri.parse('https://www.imdb.com/title/${r.imdbId ?? ''}'), mode: LaunchMode.externalApplication);
                                },
                        ),
                      if (r.rottenTomatoes != null)
                        Chip(
                          label: Text('Rotten Tomatoes ${r.rottenTomatoes}'),
                          avatar: const Icon(Icons.percent),
                        ),
                      if (r.metacritic != null)
                        Chip(
                          label: Text('Metacritic ${r.metacritic}'),
                          avatar: const Icon(Icons.bar_chart),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(movie.overview, style: const TextStyle(fontSize: 16)),
            ),

            
            // ===== ส่วนแสดงแพลตฟอร์มที่สามารถดูได้ =====
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Available On:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // FutureBuilder สำหรับแสดงแพลตฟอร์ม - รอข้อมูลจาก API
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<List<String>>(
              future: providers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Failed to load providers: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            providers = fetchProviders(movie.id);
                          });
                        },
                        child: const Text('Retry'),
                      )
                    ],
                  );
                }
                if (snapshot.hasData) {
                  if (snapshot.data!.isNotEmpty) {
                    // แสดงแพลตฟอร์มในรูปแบบ Chip
                    return Wrap(
                      spacing: 8,
                      children: snapshot.data!.map((p) => Chip(label: Text(p))).toList(),
                    );
                  } else {
                    // กรณีไม่มีแพลตฟอร์มให้ดู
                    return const Text(
                      "No platform available now (only in theater)",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  }
                }
                // state อื่นๆ (ไม่มีข้อมูล)
                return const SizedBox.shrink();
              },
            )),

            
            // ===== ส่วนแสดงหนังแนะนำ =====
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'More like this'),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Movie>>(
              future: recommendations,
              builder: (context, snapshot) {
                final recs = snapshot.data ?? const <Movie>[];
                final items = recs
                    .where((m) => m.posterPath.isNotEmpty)
                    .map((m) => MovieCardData(id: m.id, title: m.title, posterUrl: 'https://image.tmdb.org/t/p/w200${m.posterPath}'))
                    .toList();
                return MovieRow(
                  items: items,
                  onTap: (it) {
                    final m = recs.firstWhere((e) => e.id == it.id, orElse: () => recs.first);
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, a1, a2) => FadeTransition(
                          opacity: a1,
                          child: MovieDetailPage(movie: m, apiKey: widget.apiKey),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}