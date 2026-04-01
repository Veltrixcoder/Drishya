import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/game.dart';
import '../models/api_models.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── APP CONFIG ──────────────────────────────────────────────────────────
  static const String appVersion = 'v1.8';
  static const String websiteUrl = 'https://drishya.vercel.app';

  // ── LOGGING ─────────────────────────────────────────────────────────────
  void _logReq(String url) => print('🚀 [API REQ] $url');
  void _logRes(String url, int code) => print('${code == 200 ? '✅' : '❌'} [API RES] $code: $url');
  void _logErr(String url, dynamic e) => print('💥 [API ERR] $e: $url');


  // ── DYNAMIC BASE URL ────────────────────────────────────────────────────
  String _apiBase = ''; // Loaded from SharedPreferences

  String get _tmdbBase => '$_apiBase/tmdb';
  String get _gamesUrl => '$_apiBase/games';
  String get _streamingBase => '$_apiBase/media';
  
  // IPTV base - now empty by default
  static const String _iptvBase = ''; 

  // ── UPDATE CONFIG ────────────────────────────────────────────────────────
  static const String _repoOwner = 'Shashwat-CODING';
  static const String _repoName = 'Drishya';
  static const String _updateUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBase = prefs.getString('api_base_url') ?? '';
  }

  Future<bool> validateBaseUrl(String url) async {
    try {
      String formatted = url.trim();
      if (formatted.endsWith('/')) formatted = formatted.substring(0, formatted.length - 1);
      if (!formatted.contains('/api')) formatted = '$formatted/api';
      
      final uri = Uri.parse('$formatted/tmdb/movie/popular'); // Test endpoint
      _logReq(uri.toString());
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      _logRes(uri.toString(), res.statusCode);
      return res.statusCode == 200 || res.statusCode == 401; // 401 is okay, it means server is there but needs key
    } catch (e) {
      _logErr(url, e);
      return false;
    }
  }

  Future<void> setBaseUrl(String url) async {
    String formatted = url.trim();
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    // If user provided root but not /api, add it
    if (!formatted.contains('/api')) {
      formatted = '$formatted/api';
    }
    
    _apiBase = formatted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', formatted);
  }

  bool get isConfigured => _apiBase.isNotEmpty;

  // ── TMDB METHODS ─────────────────────────────────────────────────────────

  Future<List<MediaItem>> _fetchTmdbMovies(
    String endpoint, {
    Map<String, String>? extra,
  }) async {
    if (!isConfigured) return [];
    final uri = Uri.parse('$_tmdbBase$endpoint').replace(queryParameters: extra);
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .map((j) => MediaItem.fromMovieJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return [];
  }

  Future<List<MediaItem>> _fetchTmdbTv(
    String endpoint, {
    Map<String, String>? extra,
  }) async {
    if (!isConfigured) return [];
    final uri = Uri.parse('$_tmdbBase$endpoint').replace(queryParameters: extra);
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .map((j) => MediaItem.fromTvJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return [];
  }

  Future<List<MediaItem>> getTrendingMovies() =>
      _fetchTmdbMovies('/trending/movie/week');
  Future<List<MediaItem>> getPopularMovies() =>
      _fetchTmdbMovies('/movie/popular');
  Future<List<MediaItem>> getTopRatedMovies() =>
      _fetchTmdbMovies('/movie/top_rated');
  Future<List<MediaItem>> getUpcomingMovies() =>
      _fetchTmdbMovies('/movie/upcoming');
  Future<List<MediaItem>> getNowPlayingMovies() =>
      _fetchTmdbMovies('/movie/now_playing');

  Future<List<MediaItem>> getPopularTvShows() => _fetchTmdbTv('/tv/popular');
  Future<List<MediaItem>> getTopRatedTvShows() => _fetchTmdbTv('/tv/top_rated');
  Future<List<MediaItem>> getTrendingTv() => _fetchTmdbTv('/trending/tv/week');
  Future<List<MediaItem>> getAiringTodayTv() => _fetchTmdbTv('/tv/airing_today');

  Future<List<MediaItem>> getAnimeMovies() => _fetchTmdbMovies(
        '/discover/movie',
        extra: {'with_genres': '16', 'sort_by': 'popularity.desc'},
      );
  Future<List<MediaItem>> getAnimeTv() => _fetchTmdbTv(
        '/discover/tv',
        extra: {'with_genres': '16', 'sort_by': 'popularity.desc'},
      );

  Future<List<MediaItem>> search(String query) async {
    if (!isConfigured || query.trim().isEmpty) return [];
    final uri = Uri.parse('$_tmdbBase/search/multi').replace(queryParameters: {'query': query});
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .where((j) => j['media_type'] != 'person')
            .map((j) => MediaItem.fromSearchJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return [];
  }

  Future<MediaDetail?> getMovieDetail(int id) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_tmdbBase/movie/$id').replace(
      queryParameters: {'append_to_response': 'credits'},
    );
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        return MediaDetail.fromMovieDetailJson(jsonDecode(res.body));
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return null;
  }

  Future<MediaDetail?> getTvDetail(int id) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_tmdbBase/tv/$id').replace(
      queryParameters: {'append_to_response': 'credits'},
    );
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        return MediaDetail.fromTvDetailJson(jsonDecode(res.body));
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return null;
  }

  Future<TvSeason?> getTvSeasonDetail(int tvId, int seasonNumber) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_tmdbBase/tv/$tvId/season/$seasonNumber');
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        return TvSeason.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return null;
  }

  Future<TvEpisode?> getTvEpisodeDetail(int tvId, int season, int episode) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_tmdbBase/tv/$tvId/season/$season/episode/$episode');
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        return TvEpisode.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return null;
  }

  Future<List<MediaItem>> getSimilarMovies(int id) =>
      _fetchTmdbMovies('/movie/$id/similar');
  Future<List<MediaItem>> getSimilarTv(int id) => _fetchTmdbTv('/tv/$id/similar');

  // ── STREAMING METHODS ─────────────────────────────────────────────────────

  Stream<List<StreamSource>> getSources(String mediaType, int tmdbId, {int? season, int? episode}) async* {
    if (!isConfigured) {
      yield [];
      return;
    }
    print('🔍 [STREAM] Finding sources for $mediaType ($tmdbId)...');
    final query = (mediaType == 'tv' && season != null && episode != null)
        ? '&season=$season&episode=$episode'
        : '';

    // Primary Servers (excluding 5)
    final List<(int, String, Duration)> primaryConfigs = [
      (6, '$_streamingBase/6/$mediaType?id=$tmdbId$query', const Duration(seconds: 50)),
      (1, '$_streamingBase/1/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (3, '$_streamingBase/3/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (4, '$_streamingBase/4/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (9, '$_streamingBase/9/$mediaType?id=$tmdbId$query', const Duration(seconds: 60)),
      (10,'$_streamingBase/10/$mediaType?id=$tmdbId$query', const Duration(seconds: 60)),
      (11,'$_streamingBase/11/$mediaType?id=$tmdbId$query', const Duration(seconds: 40)),
    ];

    final client = http.Client();
    final controller = StreamController<List<StreamSource>>();
    int totalSourcesFound = 0;
    int pending = primaryConfigs.length;

    try {
      for (final c in primaryConfigs) {
        _fetchSources(client, c.$2, c.$1, timeout: c.$3).then((sources) {
          if (sources.isNotEmpty) {
            totalSourcesFound += sources.length;
            controller.add(sources);
          }
        }).catchError((_) {}).whenComplete(() async {
          pending--;
          if (pending == 0) {
            // All primary servers finished. Check if we need Server 5 (Last Resort).
            if (totalSourcesFound == 0) {
              print('⚠️ [STREAM] No sources found. Trying Server 5 (Last Resort)...');
              final s5Url = '$_streamingBase/5/$mediaType?id=$tmdbId$query';
              try {
                final s5Sources = await _fetchSources(client, s5Url, 5, timeout: const Duration(seconds: 35));
                if (s5Sources.isNotEmpty) {
                  controller.add(s5Sources);
                }
              } catch (_) {}
            }
            controller.close();
            client.close();
          }
        });
      }
      yield* controller.stream;
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  Future<List<StreamSource>> _fetchSources(http.Client client, String url, int serverId, {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      _logReq(url);
      final res = await client.get(Uri.parse(url)).timeout(timeout);
      _logRes(url, res.statusCode);
      if (res.statusCode != 200) return [];
      final Map<String, dynamic> data = jsonDecode(res.body);

      if (serverId == 6) {
        final d = data['data'];
        final streams = data['streams'];
        if (d is Map<String, dynamic> && d['stream_url'] != null) {
          final h = d['headers'] as Map<String, dynamic>?;
          return [StreamSource(
            quality: 'Auto', url: d['stream_url'], source: (d['source'] ?? 'Mapple').toString().toUpperCase(),
            serverId: 6, referer: (h?['Referer'] ?? h?['referer'])?.toString(),
            origin: (h?['Origin'] ?? h?['origin'])?.toString(),
          )];
        } else if (streams is List) {
          return streams.map((s) => StreamSource(
            quality: s['quality'] ?? 'Auto', url: s['url'] ?? '',
            source: (s['server'] ?? s['provider'] ?? 'Mapple').toString().toUpperCase(),
            serverId: 6, referer: (s['headers']?['Referer'])?.toString(),
            origin: (s['headers']?['Origin'])?.toString(),
          )).where((s) => s.url.isNotEmpty).toList();
        }
      }
      if (serverId == 1 || serverId == 3) {
        final List? raw = data['data']?['sources'];
        if (raw == null) return [];
        return raw.map((i) => StreamSource(
          quality: i['quality'] is num ? '${i['quality']}p' : (i['quality'] ?? 'Auto').toString(),
          url: i['url'] ?? '', source: i['source'] ?? 'Unknown', serverId: serverId,
          size: i['size']?.toString(),
        )).where((s) => s.url.isNotEmpty).toList();
      }
      if (serverId == 4) {
        final List? raw = data['data']?['sources'];
        if (raw == null) return [];
        return raw.map((i) => StreamSource(
          quality: i['quality'] ?? 'HLS', url: i['url'] ?? '', source: i['source'] ?? 'Guru',
          serverId: 4, priority: i['priority'] ?? 1,
        )).where((s) => s.url.isNotEmpty).toList();
      }
      if (serverId == 5 || serverId == 9) {
        if (data['success'] == false) return [];
        final List? streams = data['streams'];
        if (streams == null) return [];
        final subs = (data['subtitles'] as List?)?.map((s) => Subtitle.fromJson(s)).toList() ?? [];

        return streams.map((i) {
          final url = i['url']?.toString() ?? '';
          if (url.isEmpty) return null;

          final name = i['name']?.toString() ?? '';
          final title = i['title']?.toString() ?? '';
          final combined = '$name $title';

          // Quality extraction
          String q = i['quality']?.toString() ?? 'Auto';
          if (q == 'Auto' || q.isEmpty) {
            final qMatch = RegExp(r'(\d{3,4}p)').firstMatch(combined);
            if (qMatch != null) q = qMatch.group(1)!;
          }

          // Source / Server extraction
          String srv = i['server']?.toString() ?? '';
          if (srv.isEmpty) {
             final srvMatch = RegExp(r'🔗\s*([^\n\r]+)').firstMatch(title);
             if (srvMatch != null) {
               srv = srvMatch.group(1)!.trim();
             } else if (name.contains('|')) {
               srv = name.split('|').first.trim();
             } else {
               srv = serverId == 5 ? 'Server 5' : 'Server 9';
             }
          }

          // Size extraction
          String? sz;
          final szMatch = RegExp(r'💾\s*([\d\.]+\s*[GM]B)').firstMatch(title);
          if (szMatch != null) sz = szMatch.group(1)!.trim();

          // Headers
          final Map<String, String> headers = (i['headers'] as Map?)?.cast<String, String>() ?? {};
          final bh = i['behaviorHints'] as Map<String, dynamic>?;
          if (bh != null && bh['proxyHeaders']?['request'] != null) {
             final ph = bh['proxyHeaders']['request'] as Map<String, dynamic>;
             ph.forEach((k, v) => headers[k] = v.toString());
          }

          // Prioritization
          int priority = 10;
          if (q.contains('720')) priority = 20;
          if (combined.toUpperCase().contains('SAMPLE')) priority = 1;

          return StreamSource(
            quality: q,
            url: url,
            source: srv,
            serverId: serverId,
            referer: headers['Referer'] ?? headers['referer'],
            origin: headers['Origin'] ?? headers['origin'],
            headers: headers.isEmpty ? null : headers,
            subtitles: subs,
            size: sz,
            priority: priority,
          );
        }).whereType<StreamSource>().toList();
      }
      if (serverId == 10) {
        final List? streams = data['streams'];
        if (streams == null) return [];
        return streams.map((i) {
          final h = i['headers'] as Map<String, dynamic>? ?? {};
          return StreamSource(
            quality: i['quality'] ?? 'Auto', url: i['url'] ?? '',
            source: (i['server'] ?? i['provider'] ?? 'Nxsha').toString().toUpperCase(),
            serverId: 10, headers: h.cast<String, String>(),
            referer: h['Referer'] ?? h['referer'], origin: h['Origin'] ?? h['origin'],
          );
        }).where((s) => s.url.isNotEmpty).toList();
      }
      if (serverId == 11) {
        if (data['success'] == true) {
          final List? streams = data['streams'];
          if (streams == null || streams.isEmpty) return [];
          final subs = (data['subtitles'] as List?)?.map((s) => Subtitle.fromJson(s)).toList() ?? [];
          return streams.map((s) => StreamSource(
            quality: s['quality'] ?? 'Auto', url: s['url'] ?? '', source: 'Drishya 11',
            serverId: 11, headers: (s['headers'] as Map?)?.cast<String, String>(),
            subtitles: subs,
          )).toList();
        }
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<Subtitle>> fetchSubtitles(String mediaType, int tmdbId, {int? season, int? episode}) async {
    if (!isConfigured) return [];
    final query = (mediaType == 'tv' && season != null && episode != null) ? '&s=$season&e=$episode' : '';
    final url = '$_streamingBase/11/$mediaType?id=$tmdbId$query';
    _logReq(url);
    try {
      final res = await http.get(Uri.parse(url));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['subtitles'] != null) {
          return (data['subtitles'] as List).map((j) => Subtitle.fromJson(j)).toList();
        }
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  // ── IPTV METHODS ──────────────────────────────────────────────────────────

  Future<List<CountryEntry>> fetchCountries() async {
    final url = '$_iptvBase/countries';
    _logReq(url);
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => CountryEntry.fromJson(item)).toList()..sort((a,b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<RegionEntry>> fetchRegions() async {
    final url = '$_iptvBase/regions';
    _logReq(url);
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => RegionEntry.fromJson(item)).toList()..sort((a,b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<CategoryEntry>> fetchCategories() async {
    final url = '$_iptvBase/categories';
    _logReq(url);
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => CategoryEntry.fromJson(item)).toList()..sort((a,b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<LanguageEntry>> fetchLanguages() async {
    final url = '$_iptvBase/languages';
    _logReq(url);
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => LanguageEntry.fromJson(item)).toList()..sort((a,b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<IptvResponse> fetchChannelsByCountry(String code, {int page = 1, int perPage = 100}) async {
    final url = '$_iptvBase/country/$code?page=$page&per_page=$perPage';
    _logReq(url);
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) return IptvResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      _logErr(url, e);
    }
    return IptvResponse.empty();
  }

  Future<IptvResponse> fetchChannelsByRegion(String code, {int page = 1, int perPage = 100}) async {
    final url = '$_iptvBase/region/$code?page=$page&per_page=$perPage';
    _logReq(url);
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) return IptvResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      _logErr(url, e);
    }
    return IptvResponse.empty();
  }

  Future<IptvResponse> searchChannels(String query, {String? country, String? category, int page = 1, int perPage = 100}) async {
    try {
      var url = '$_iptvBase/search?q=$query&page=$page&per_page=$perPage';
      if (country != null) url += '&country=$country';
      if (category != null) url += '&category=$category';
      _logReq(url);
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) return IptvResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      _logErr(query, e);
    }
    return IptvResponse.empty();
  }

  // ── UPDATE METHODS ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> checkForUpdate() async {
    _logReq(_updateUrl);
    try {
      final response = await http.get(Uri.parse(_updateUrl));
      _logRes(_updateUrl, response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestTag = data['tag_name'] as String;
        final latest = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;
        final current = appVersion.startsWith('v') ? appVersion.substring(1) : appVersion;
        if (_isNewer(latest, current)) {
          return {'version': latestTag, 'changelog': data['body'], 'url': data['html_url']};
        }
      }
    } catch (e) {
      _logErr(_updateUrl, e);
    }
    return null;
  }

  bool _isNewer(String latest, String current) {
    List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < l.length && i < c.length; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
    }
    return l.length > c.length;
  }

  // ── GAMES METHODS ────────────────────────────────────────────────────────

  Future<List<Game>> fetchGames() async {
    if (!isConfigured) return [];
    _logReq(_gamesUrl);
    try {
      final res = await http.get(Uri.parse(_gamesUrl));
      _logRes(_gamesUrl, res.statusCode);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((j) => Game.fromJson(j)).toList();
      }
    } catch (e) {
      _logErr(_gamesUrl, e);
    }
    return [];
  }
}
