import 'dart:convert';

import 'package:http/http.dart' as http;

import 'delivery.dart';

class CatalogClient {
  CatalogClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<DeliveryRecord>> fetchDeliveries({
    required String baseUrl,
    required String token,
  }) async {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$normalized/v1/deliveries');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer ${token.trim()}'},
    );
    if (response.statusCode != 200) {
      throw CatalogException(
        'Katalog yanıtı başarısız (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?> || decoded['deliveries'] is! List) {
      throw const CatalogException('Katalog yanıt biçimi geçersiz.');
    }
    return (decoded['deliveries']! as List)
        .map((item) => DeliveryRecord.fromJson(item as Map<String, Object?>))
        .toList(growable: false);
  }
}

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}
