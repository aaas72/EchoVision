import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// GPS location service for blind navigation assistance.
/// Provides current position with reverse geocoding in Turkish.
class LocationService {
  /// Check and request location permissions, then get current position
  /// with a human-readable Turkish address.
  Future<String> getCurrentLocationDescription() async {
    // ── 1. Check if location services are enabled ──
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Location service is disabled. Please enable GPS in settings.';
    }

    // ── 2. Check / request permission ──
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permission denied.';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. Please enable it in app settings.';
    }

    // ── 3. Get current position (high accuracy for GPS) ──
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      return 'Could not determine location. Ensure GPS is active and you are in an open area.';
    }

    // ── 4. Reverse geocode → address ──
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return _buildEnglishAddress(p, position);
      }
    } catch (_) {
      // Reverse geocoding failed — fall back to coordinates
    }

    // ── 5. Fallback: raw coordinates ──
    final lat = position.latitude.toStringAsFixed(5);
    final lng = position.longitude.toStringAsFixed(5);
    return 'Current location: Latitude $lat, Longitude $lng.';
  }

  /// Build a natural English address string from placemark data.
  String _buildEnglishAddress(Placemark p, Position pos) {
    final parts = <String>[];

    // Street
    if (p.street != null && p.street!.isNotEmpty) {
      parts.add(p.street!);
    }
    // Sub-locality (neighborhood / district)
    if (p.subLocality != null && p.subLocality!.isNotEmpty) {
      parts.add(p.subLocality!);
    }
    // Locality (city)
    if (p.locality != null && p.locality!.isNotEmpty) {
      parts.add(p.locality!);
    }
    // Administrative area (state / province)
    if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
      // Only add if different from city
      if (p.administrativeArea != p.locality) {
        parts.add(p.administrativeArea!);
      }
    }
    // Country
    if (p.country != null && p.country!.isNotEmpty) {
      parts.add(p.country!);
    }

    if (parts.isEmpty) {
      final lat = pos.latitude.toStringAsFixed(5);
      final lng = pos.longitude.toStringAsFixed(5);
      return 'Current location: Latitude $lat, Longitude $lng.';
    }

    return 'Current location: ${parts.join(', ')}.';
  }
}
