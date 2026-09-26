import 'package:academia_app/core/storage/session_storage.dart';

class InMemorySessionStorage implements SessionStorage {
  String? token;
  String? organization;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async => this.token = token;

  @override
  Future<String?> readOrganization() async => organization;

  @override
  Future<void> writeOrganization(String slug) async => organization = slug;

  @override
  Future<void> clear() async {
    token = null;
    organization = null;
  }
}
