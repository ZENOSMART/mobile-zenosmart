import 'dart:convert';
import 'package:http/http.dart' as http;
import 'product_api_response.dart';
import 'models/device_type_model.dart';
import 'models/device_channel_template.dart';

class ProductApiService {
  static const String _baseUrl = 'https://product.zenosmart.com/api';

  const ProductApiService();

  /// POST isteği gönderir ve yanıtı Map olarak döndürür
  Future<Map<String, dynamic>> post({
    required String endpoint,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');

    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final mergedHeaders = {...defaultHeaders, ...?headers};

    try {
      final response = await http.post(
        url,
        headers: mergedHeaders,
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {};
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ProductApiException(
          statusCode: response.statusCode,
          message: 'API isteği başarısız: ${response.statusCode}',
          responseBody: response.body,
        );
      }
    } catch (e) {
      if (e is ProductApiException) {
        rethrow;
      }
      throw ProductApiException(
        statusCode: null,
        message: 'Bağlantı hatası: $e',
        responseBody: null,
      );
    }
  }

  Future<ProductApiResponse<T>> postWithResponse<T>({
    required String endpoint,
    required Map<String, dynamic> body,
    T Function(dynamic)? dataParser,
    Map<String, String>? headers,
  }) async {
    final response = await post(
      endpoint: endpoint,
      body: body,
      headers: headers,
    );
    return ProductApiResponse.fromJson(response, dataParser);
  }

  Future<ProductApiResponse<PageableData<T>>> postWithPageable<T>({
    required String endpoint,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) contentParser,
    Map<String, String>? headers,
  }) async {
    final response = await post(
      endpoint: endpoint,
      body: body,
      headers: headers,
    );
    return ProductApiResponse.fromJson(
      response,
      (data) =>
          PageableData.fromJson(data as Map<String, dynamic>, contentParser),
    );
  }

  Future<ProductApiResponse<PageableData<DeviceTypeModel>>>
  getByDeviceTypeModelByOrderCode({
    required String orderCode,
    int page = 1,
    int size = 10,
  }) async {
    final body = {
      'filter': {},
      'detailFilter': [
        {
          'condition': 'equals',
          'operator': 'and',
          'columns': {'orderCode': orderCode},
        },
      ],
      'pageable': {
        'page': page,
        'size': size,
        'sort': ['createdAt,desc'],
      },
    };

    return postWithPageable<DeviceTypeModel>(
      endpoint: '/device-type-models/get',
      body: body,
      contentParser: (json) => DeviceTypeModel.fromJson(json),
    );
  }

  Future<ProductApiResponse<PageableData<DeviceChannelTemplate>>>
  getByDeviceChannelTemplatesByTypeModelId({
    required String deviceTypeModelId,
    int page = 1,
    int size = 1000,
  }) async {
    final body = {
      'filter': {
        'deviceTypeModelDto': {'id': deviceTypeModelId},
      },
      'detailFilter': [],
      'selectedColumns': null,
      'pageable': {
        'page': page,
        'size': size,
        'sort': ['createdAt,asc'],
      },
    };

    return postWithPageable<DeviceChannelTemplate>(
      endpoint: '/device-channel-templates/get',
      body: body,
      contentParser: (json) => DeviceChannelTemplate.fromJson(json),
    );
  }
}

class ProductApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? responseBody;

  ProductApiException({
    required this.statusCode,
    required this.message,
    this.responseBody,
  });

  @override
  String toString() {
    return 'ProductApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}
