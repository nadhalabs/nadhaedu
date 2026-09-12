import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/core/networking/api_client.dart';

class CmsOperationsRepository {
  const CmsOperationsRepository(this.client);
  final ApiClient client;

  Future<Result<Map<String, Object?>>> get(
    String path, {
    Map<String, Object?> query = const {},
  }) => client.get(path, query: query);

  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
  }) => client.post(path, body: body);

  Future<Result<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
  }) => client.put(path, body: body);
}
