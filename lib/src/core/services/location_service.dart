import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult._({this.latitude, this.longitude, this.message});

  const LocationResult.success(double latitude, double longitude)
    : this._(latitude: latitude, longitude: longitude);
  const LocationResult.failure(String message) : this._(message: message);

  final double? latitude;
  final double? longitude;
  final String? message;
  bool get isSuccess => latitude != null && longitude != null;
}

class LocationService {
  static Future<LocationResult> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failure('Location services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult.failure('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(
        'Location permission is permanently denied. Enable it in settings.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition();
      return LocationResult.success(position.latitude, position.longitude);
    } catch (_) {
      return const LocationResult.failure('Current location is unavailable.');
    }
  }
}
