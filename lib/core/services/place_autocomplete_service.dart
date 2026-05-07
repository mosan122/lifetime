import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:osm_nominatim/osm_nominatim.dart';

import '../models/milestone_location_data.dart';

class PlaceAutocompleteService {
  final Nominatim _nominatim;
  final http.Client _http;

  PlaceAutocompleteService({
    Nominatim? nominatim,
    http.Client? httpClient,
  }) : _nominatim = nominatim ??
            Nominatim(
              // Nominatim usage policy expects a descriptive UA.
              userAgent: 'LifeTime/1.0 (place search; contact: support@lifetime.app)',
            ),
        _http = httpClient ?? http.Client();

  Future<List<MilestoneLocationData>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    final results = await _nominatim.searchByName(
      query: q,
      limit: 6,
      addressDetails: true,
      language: 'es',
    );

    return results.map((p) {
      final addr = p.address;
      final Map<dynamic, dynamic> addrMap = addr ?? const <dynamic, dynamic>{};
      String? addrStr(String key) {
        final v = addrMap[key];
        return v is String ? v : null;
      }

      final city = addr == null
          ? null
          : (addrStr('city') ??
              addrStr('town') ??
              addrStr('village') ??
              addrStr('municipality') ??
              addrStr('county') ??
              addrStr('state'));
      final country = addr == null ? null : addrStr('country');

      double? lat;
      double? lon;
      try {
        lat = p.lat;
        lon = p.lon;
      } catch (_) {
        // ignore parsing failures; keep nulls
      }

      final name = (p.displayName ?? q).trim();
      return MilestoneLocationData(
        name: name.isEmpty ? q : name,
        city: (city?.trim().isEmpty ?? true) ? null : city?.trim(),
        country: (country?.trim().isEmpty ?? true) ? null : country?.trim(),
        latitude: lat,
        longitude: lon,
      );
    }).toList();
  }

  Future<MilestoneLocationData?> reverse({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final p = await _nominatim.reverseSearch(
        lat: latitude,
        lon: longitude,
        addressDetails: true,
        language: 'es',
      );
      return _placeToLocation(p, fallbackLat: latitude, fallbackLon: longitude);
    } on FormatException {
      // Some responses (rate limit / forbidden / captive portal) are HTML/XML.
      return _reverseViaHttp(latitude: latitude, longitude: longitude);
    } catch (_) {
      // Best-effort fallback: try direct call.
      return _reverseViaHttp(latitude: latitude, longitude: longitude);
    }
  }

  Future<MilestoneLocationData?> _reverseViaHttp({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      <String, String>{
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'addressdetails': '1',
        'accept-language': 'es',
      },
    );
    final resp = await _http.get(
      uri,
      headers: const {
        // Force JSON where possible.
        'Accept': 'application/json',
        // User-Agent required by Nominatim.
        'User-Agent': 'LifeTime/1.0 (reverse geocode; contact: support@lifetime.app)',
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final body = resp.body;
    if (body.trimLeft().startsWith('<')) return null;
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) return null;
    if (data['error'] != null) return null;
    return _jsonToLocation(
      data,
      fallbackLat: latitude,
      fallbackLon: longitude,
    );
  }

  MilestoneLocationData? _placeToLocation(
    Place p, {
    required double fallbackLat,
    required double fallbackLon,
  }) {
    final addr = p.address;
    final Map<dynamic, dynamic> addrMap = addr ?? const <dynamic, dynamic>{};
    String? addrStr(String key) {
      final v = addrMap[key];
      return v is String ? v : null;
    }

    final city = addr == null
        ? null
        : (addrStr('city') ??
            addrStr('town') ??
            addrStr('village') ??
            addrStr('municipality') ??
            addrStr('county') ??
            addrStr('state'));
    final country = addr == null ? null : addrStr('country');

    final name = (p.displayName).trim();
    if (name.isEmpty) return null;
    return MilestoneLocationData(
      name: name,
      city: (city?.trim().isEmpty ?? true) ? null : city?.trim(),
      country: (country?.trim().isEmpty ?? true) ? null : country?.trim(),
      latitude: fallbackLat,
      longitude: fallbackLon,
    );
  }

  MilestoneLocationData? _jsonToLocation(
    Map<String, dynamic> json, {
    required double fallbackLat,
    required double fallbackLon,
  }) {
    final name = (json['display_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final addr = json['address'];
    final Map<dynamic, dynamic> addrMap =
        addr is Map ? addr : const <dynamic, dynamic>{};
    String? addrStr(String key) {
      final v = addrMap[key];
      return v is String ? v : null;
    }
    final city = addrStr('city') ??
        addrStr('town') ??
        addrStr('village') ??
        addrStr('municipality') ??
        addrStr('county') ??
        addrStr('state');
    final country = addrStr('country');
    return MilestoneLocationData(
      name: name,
      city: (city?.trim().isEmpty ?? true) ? null : city?.trim(),
      country: (country?.trim().isEmpty ?? true) ? null : country?.trim(),
      latitude: fallbackLat,
      longitude: fallbackLon,
    );
  }
}

