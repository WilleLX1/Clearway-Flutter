import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../models/clearway_models.dart';

abstract interface class ClearwayRepository {
  Future<ClearwayMeta> getMeta();

  Future<List<GeocodeResult>> geocode(String query);

  Future<List<ClearwayRoute>> compare({
    required ClearwayPoint origin,
    required ClearwayPoint destination,
    required String time,
    required int weekday,
  });
}

class ClearwayApiException implements Exception {
  const ClearwayApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ClearwayApi implements ClearwayRepository {
  ClearwayApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Future<dynamic> _json(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
          detail = decoded['detail'].toString();
        }
      } on FormatException {
        // Preserve the original response when it is not JSON.
      }
      throw ClearwayApiException(
        detail.isEmpty ? 'Request failed (${response.statusCode})' : detail,
        statusCode: response.statusCode,
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ClearwayApiException('The server returned invalid data.');
    }
  }

  @override
  Future<ClearwayMeta> getMeta() async {
    final response = await _client.get(_uri('/meta'));
    return ClearwayMeta.fromJson(await _json(response) as Map<String, dynamic>);
  }

  @override
  Future<List<GeocodeResult>> geocode(String query) async {
    final response = await _client.get(
      _uri('/geocode', {'q': query, 'limit': '6'}),
    );
    final values = await _json(response) as List<dynamic>;
    return values
        .map((value) => GeocodeResult.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<ClearwayRoute>> compare({
    required ClearwayPoint origin,
    required ClearwayPoint destination,
    required String time,
    required int weekday,
  }) async {
    final response = await _client.post(
      _uri('/route/compare'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'time': time,
        'weekday': weekday,
      }),
    );
    final decoded = await _json(response) as Map<String, dynamic>;
    return (decoded['routes'] as List<dynamic>)
        .map((value) => ClearwayRoute.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  void close() => _client.close();
}
