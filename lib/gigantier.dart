library gigantier_sdk;

import 'dart:convert';

import 'package:gigantier_sdk/auth/credential.dart';
import 'package:gigantier_sdk/exceptions.dart';
import 'package:gigantier_sdk/preferences.dart';
import 'package:http/http.dart' as http;

enum HttpMethod { post, get, put, delete }

class Gigantier {
  static final String grantTypeApp = 'client_credentials';
  static final String grantTypeUser = 'password';
  static final String grantTypeRefresh = 'refresh_token';
  static final String oauthPath = '/OAuth/token';
  static final int retries = 3;

  final String hostname;
  final String clientId;
  final String clientSecret;
  final String scope;
  final String appName;
  final String protocol;
  final String apiVersion;
  final http.Client client;

  http.Client _apiClient;

  final prefs = Preferences();

  Gigantier(
    this.hostname,
    this.clientId,
    this.clientSecret,
    this.scope,
    this.appName, {
    this.protocol = 'https',
    this.apiVersion = 'v1',
    this.client,
  });

  get _baseUrl =>
      '$protocol://$hostname/api${apiVersion != '' ? '/$apiVersion' : ''}';

  http.Client _getClient() {
    if (_apiClient == null) {
      _apiClient = this.client != null ? this.client : http.Client();
    }
    return _apiClient;
  }

  static Future<Map<String, String>> baseHeaders(appName) async {
    final headers = Map<String, String>();
    headers['X-GIGANTIER-SDK-LANGUAGE'] = 'Flutter';
    headers['X-GIGANTIER-SDK-VERSION'] =
        '1.0.7'; // TODO: obtain version from pubspec.yaml
    headers['X-GIGANTIER-APPLICATION'] = appName;
    return Future.value(headers);
  }

  Future<Credential> authenticate(String identifier, String password) async {
    final body = {'username': identifier, 'password': password};
    final credential = await _retrieveToken(grantTypeUser, body);
    await _onCredential(credential);
    return credential;
  }

  Future<Map<String, dynamic>> call(
    String uri, {
    Map<String, dynamic> body,
    HttpMethod method = HttpMethod.post,
  }) async {
    final appToken = await getAppToken();
    final Map<String, dynamic> requestBody = body != null ? body : {};
    requestBody['access_token'] = appToken;
    return _execMethod(uri, false, retries, method, body: requestBody);
  }

  Future<Map<String, dynamic>> authenticatedCall(
    String uri, {
    Map<String, dynamic> body,
    HttpMethod method = HttpMethod.post,
  }) async {
    final userToken = await _getUserToken();
    final Map<String, dynamic> requestBody = body != null ? body : {};
    requestBody['access_token'] = userToken;
    return _execMethod(uri, true, retries, method, body: requestBody);
  }

  Future<Map<String, dynamic>> _execMethod(
    String uri,
    bool isUserApi,
    int retries,
    HttpMethod method, {
    Map<String, dynamic> body,
  }) async {
    final headers = await baseHeaders(appName);
    final url = '$_baseUrl$uri';
    Future<http.Response> call;

    final _client = _getClient();

    if (method == HttpMethod.post)
      call = _client.post(url, headers: headers, body: body);
    else if (method == HttpMethod.delete)
      call = _client.delete(url, headers: headers);
    else if (method == HttpMethod.get)
      call = _client.get(url, headers: headers);
    else if (method == HttpMethod.put)
      call = _client.put(url, headers: headers, body: body);
    else
      throw Exception('missing http method parameter');

    final response = await call;
    return _onResponse(uri, isUserApi, retries, method, response, body: body);
  }

  Future<Map<String, dynamic>> _onResponse(
    String uri,
    bool isUserApi,
    int retries,
    HttpMethod method,
    http.Response response, {
    Map<String, dynamic> body,
  }) async {
    final code = response.statusCode;
    final responseBody = Map<String, dynamic>.from(json.decode(response.body));

    if (code == 401 && retries > 0 && isUserApi) {
      final String userToken = await _getUserToken(renew: true);
      body['access_token'] = userToken;
      return _execMethod(uri, isUserApi, retries + 1, method, body: body);
    } else if (code == 401 && retries > 0) {
      final String appToken = await getAppToken(renew: true);
      body['access_token'] = appToken;
      return _execMethod(uri, isUserApi, retries - 1, method, body: body);
    } else if (code >= 400) throw _buildApiError(responseBody);

    return Future.value(responseBody);
  }

  Future<String> getAppToken({bool renew = false}) async {
    final storedAppToken = await prefs.getAppToken();
    final isAppTokenExpired = await prefs.isAppTokenExpired();
    final notEmptyAppToken = storedAppToken != null && storedAppToken != "";

    if (!renew && notEmptyAppToken && !isAppTokenExpired) {
      return storedAppToken;
    } else {
      return _retrieveToken(grantTypeApp, {}).then((credential) async {
        await prefs.resetAppToken();
        await prefs.setAppToken(credential.accessToken);
        await prefs.setAppRefreshToken(credential.refreshToken);
        await prefs.setAppTokenExpiration(credential.expires);
        return credential.accessToken;
      });
    }
  }

  Future<String> _getUserToken({bool renew = false}) async {
    final storedUserToken = await prefs.getUserToken();
    final isUserTokenExpired = await prefs.isUserTokenExpired();
    final notEmptyUserToken = storedUserToken != null && storedUserToken != "";

    if (!renew && notEmptyUserToken && !isUserTokenExpired) {
      return storedUserToken;
    } else {
      final refreshToken = await prefs.getUserRefreshToken();
      if (refreshToken == null)
        throw _buildApiError({
          'error': 'missing_credentials',
          'error_description':
              'Missing autenticate() call before authenticatedCall()',
        });
      final body = {'refresh_token': refreshToken};
      final credential = await _retrieveToken(grantTypeRefresh, body);
      await _onCredential(credential);
      return credential.accessToken;
    }
  }

  Future<void> _onCredential(Credential credential) async {
    await prefs.resetUserToken();
    await prefs.setUserToken(credential.accessToken);
    await prefs.setUserRefreshToken(credential.refreshToken);
    await prefs.setUserTokenExpiration(credential.expires);
  }

  Future<Credential> _retrieveToken(
      String grantType, Map<String, dynamic> extraBody) async {
    final Map<String, dynamic> requestBody = {
      'grant_type': grantType,
      'client_id': clientId,
      'client_secret': clientSecret,
      'scope': scope,
    };
    requestBody.addAll(extraBody);

    final headers = await baseHeaders(appName);
    final response = await _getClient().post(
      '$_baseUrl$oauthPath',
      headers: headers,
      body: requestBody,
    );

    final body = Map<String, dynamic>.from(json.decode(response.body));
    final ok = body['ok'] as bool;

    if (!ok) throw _buildApiError(body);

    return Credential(
      accessToken: body['access_token'] as String,
      refreshToken: body['refresh_token'] as String,
      expires: body['expires_in'] as int,
    );
  }

  _buildApiError(Map<String, dynamic> body) {
    return ApiErrorException(
      body['error'] as String,
      body['error_description'] as String,
    );
  }
}
