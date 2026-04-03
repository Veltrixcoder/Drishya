import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_models.dart';
import 'api_service.dart';

class StreamingService {
  StreamingService._();
  static final StreamingService instance = StreamingService._();

  void _logReq(String url) => print('🚀 [STREAM REQ] $url');
  void _logRes(String url, int code) => print('${code == 200 ? '✅' : '❌'} [STREAM RES] $code: $url');
  void _logErr(String url, dynamic e) => print('💥 [STREAM ERR] $e: $url');

  Stream<List<StreamSource>> getSources(String mediaType, int tmdbId, {int? season, int? episode}) async* {
    if (!ApiService.instance.isConfigured) {
      yield [];
      return;
    }
    print('🔍 [STREAM] Finding sources for $mediaType ($tmdbId)...');
    final query = (mediaType == 'tv' && season != null && episode != null)
        ? '&season=$season&episode=$episode'
        : '';
    final streamingBase = ApiService.instance.streamingBase;

    // Primary Servers (excluding 10, and 11)
    final List<(int, String, Duration)> primaryConfigs = [
      (6, '$streamingBase/6/$mediaType?id=$tmdbId$query', const Duration(seconds: 50)),
      (1, '$streamingBase/1/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (3, '$streamingBase/3/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (4, '$streamingBase/4/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (5, '$streamingBase/5/$mediaType?id=$tmdbId$query', const Duration(seconds: 35)),
      (9, '$streamingBase/9/$mediaType?id=$tmdbId$query', const Duration(seconds: 60)),
    ];

    final client = http.Client();
    final controller = StreamController<List<StreamSource>>();
    int pending = primaryConfigs.length;

    try {
      for (final c in primaryConfigs) {
        _fetchSources(client, c.$2, c.$1, timeout: c.$3).then((sources) {
          if (sources.isNotEmpty) {
            controller.add(sources);
          }
        }).catchError((_) {}).whenComplete(() async {
          pending--;
          if (pending == 0) {
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

          if (serverId == 5) {
            final lowerCombined = combined.toLowerCase();
            if (lowerCombined.contains('vixsrc')) {
              priority = -1; // Highest preference for Server 5
            } else if (q.contains('720')) {
              priority = -2; // Second preference
            } else {
              priority = -5; // Everything else (1080p, 4k, etc.)
            }
          }

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
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<Subtitle>> fetchSubtitles(String mediaType, int tmdbId, {int? season, int? episode}) async {
    if (!ApiService.instance.isConfigured) return [];
    final query = (mediaType == 'tv' && season != null && episode != null) ? '&s=$season&e=$episode' : '';
    final url = '${ApiService.instance.streamingBase}/11/$mediaType?id=$tmdbId$query';
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
}
