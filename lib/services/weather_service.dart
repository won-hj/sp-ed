import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.precipitationProbabilityPercent,
    required this.locationLabel,
  });

  final double temperatureCelsius;
  final int humidityPercent;
  final int precipitationProbabilityPercent;
  final String locationLabel;

  String get briefing {
    final temperature = temperatureCelsius.toStringAsFixed(1);

    return 'Today, the current temperature is $temperature degrees Celsius. '
        'Humidity is $humidityPercent percent, and the chance of rain is '
        '$precipitationProbabilityPercent percent.';
  }
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  static const double _seoulLatitude = 37.5665;
  static const double _seoulLongitude = 126.9780;

  final http.Client _client;

  Future<WeatherSnapshot> fetchToday() async {
    final location = await _resolveLocation();

    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      <String, String>{
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'current': 'temperature_2m,relative_humidity_2m',
        'daily': 'precipitation_probability_max',
        'forecast_days': '1',
        'timezone': 'auto',
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Weather API returned ${response.statusCode}.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    final daily = json['daily'] as Map<String, dynamic>?;
    final rainValues = daily?['precipitation_probability_max'] as List<dynamic>?;

    final temperature = current?['temperature_2m'] as num?;
    final humidity = current?['relative_humidity_2m'] as num?;
    final rainProbability = rainValues?.isNotEmpty == true
        ? rainValues!.first as num?
        : null;

    if (temperature == null || humidity == null || rainProbability == null) {
      throw const FormatException('Weather response is missing required values.');
    }

    return WeatherSnapshot(
      temperatureCelsius: temperature.toDouble(),
      humidityPercent: humidity.round(),
      precipitationProbabilityPercent: rainProbability.round(),
      locationLabel: location.isFallback ? 'Seoul (default)' : 'Current location',
    );
  }

  Future<_WeatherLocation> _resolveLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const _WeatherLocation.fallback();
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const _WeatherLocation.fallback();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return _WeatherLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        isFallback: false,
      );
    } catch (_) {
      return const _WeatherLocation.fallback();
    }
  }

  void dispose() {
    _client.close();
  }
}

class _WeatherLocation {
  const _WeatherLocation({
    required this.latitude,
    required this.longitude,
    required this.isFallback,
  });

  const _WeatherLocation.fallback()
      : latitude = WeatherService._seoulLatitude,
        longitude = WeatherService._seoulLongitude,
        isFallback = true;

  final double latitude;
  final double longitude;
  final bool isFallback;
}
