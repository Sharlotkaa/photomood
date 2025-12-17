import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationWeatherService {
  static Future<Map<String, String>> getCurrentLocation() async {
    try {
      // Проверяем разрешения
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {'error': 'Геолокация отключена'};
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'error': 'Нет разрешения на геолокацию'};
        }
      }

      // Получаем позицию
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Получаем адрес
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String location = '${place.locality ?? ''}';
        
        if (place.administrativeArea != null) {
          location += ', ${place.administrativeArea}';
        }

        return {
          'location': location,
          'lat': position.latitude.toString(),
          'lon': position.longitude.toString(),
        };
      }

      return {'location': 'Местоположение не определено'};
    } catch (e) {
      print('Ошибка получения местоположения: $e');
      return {'error': 'Ошибка получения местоположения'};
    }
  }

  static Future<String> getWeather(double lat, double lon) async {
    try {
      // (нужен бесплатный API ключ)
      const apiKey = '....'; 
      
      final response = await http.get(
        Uri.parse('...'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['main']['temp'].round();
        final description = data['weather'][0]['description'];
        final icon = _getWeatherIcon(data['weather'][0]['main']);
        
        return '$icon $temp°C, ${description}';
      }
      
      return '🌡️ Погода не доступна';
    } catch (e) {
      print('Ошибка получения погоды: $e');
      return '🌡️ Погода не доступна';
    }
  }

  static String _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear': return '☀️';
      case 'clouds': return '☁️';
      case 'rain': return '🌧️';
      case 'snow': return '❄️';
      case 'thunderstorm': return '⛈️';
      case 'drizzle': return '🌦️';
      case 'mist':
      case 'fog':
      case 'haze': return '🌫️';
      default: return '🌡️';
    }
  }
}