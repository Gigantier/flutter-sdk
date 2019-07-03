library gigantier_sdk;

import 'dart:convert';

import 'package:gigantier_sdk/auth/credential.dart';
import 'package:gigantier_sdk/exceptions.dart';
import 'package:gigantier_sdk/preferences.dart';
import 'package:http/http.dart' as http;

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

  final prefs = Preferences();
  
  Gigantier(
    this.hostname, 
    this.clientId, 
    this.clientSecret, 
    this.scope,
    this.appName,
    { this.protocol = 'https', this.apiVersion = 'v1', this.client }
  );

  get _baseUrl => '$protocol://$hostname/api${apiVersion != '' ? '/$apiVersion' : ''}';

  static Future<Map<String, String>> baseHeaders(appName) async {    
    final headers = Map<String, String>();
    headers['X-GIGANTIER-SDK-LANGUAGE'] = 'Flutter';
    headers['X-GIGANTIER-SDK-VERSION'] = '1.0.1'; // TODO: obtain version from pubspec.yaml
    headers['X-GIGANTIER-APPLICATION'] = appName;
    return Future.value(headers);
  }

  Future<Credential> authenticate(String identifier, String password) async {
    final body = { 'username': identifier, 'password': password };
    final credential = await _retrieveToken(grantTypeUser, body);
    await _onCredential(credential);
    return credential;
  }

  Future<Map<String, dynamic>> call(String uri, { Map<String, dynamic> body }) async {
    final appToken = await getAppToken();
    final Map<String, dynamic> requestBody = body != null ? body : {};
    requestBody['access_token'] = appToken;
    return _execPost(uri, false, retries, body: requestBody);
  }

  Future<Map<String, dynamic>> authenticatedCall(String uri, { Map<String, dynamic> body }) async {
    final userToken = await _getUserToken();
    final Map<String, dynamic> requestBody = body != null ? body : {};
    requestBody['access_token'] = userToken;
    return _execPost(uri, true, retries, body: requestBody);
  }

  Future<Map<String, dynamic>> _execPost(String uri, bool isUserApi, int retries, { Map<String, dynamic> body }) async {
    final headers = await baseHeaders(appName);
    return client.post('$_baseUrl$uri', headers: headers, body: body).then((response) async {
      final code = response.statusCode;
      final responseBody = Map<String, dynamic>.from(json.decode(response.body));

      if (code == 401 && retries > 0 && isUserApi) {
        final String userToken = await _getUserToken(renew: true);
        body['access_token'] = userToken;
        return _execPost(uri, isUserApi, retries + 1, body: body);
      }
      else if (code == 401 && retries > 0) {
        final String appToken = await getAppToken(renew: true);
        body['access_token'] = appToken;
        return _execPost(uri, isUserApi, retries - 1, body: body);
      }
      else if (code >= 400) throw _buildApiError(responseBody);

      return responseBody;
    });
  }

  Future<String> getAppToken({ bool renew = false }) async {
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
 
  Future<String> _getUserToken({ bool renew = false }) async {
    final storedUserToken = await prefs.getUserToken();
    final isUserTokenExpired = await prefs.isUserTokenExpired();
    final notEmptyUserToken = storedUserToken != null && storedUserToken != "";

    if (!renew && notEmptyUserToken && !isUserTokenExpired) {
      return storedUserToken;
    } else {
      final refreshToken = await prefs.getUserRefreshToken();
      if (refreshToken == null) throw _buildApiError({ 
        'error': 'missing_credentials', 
        'error_description': 'Missing autenticate() call before authenticatedCall()' 
      });
      final body = { 'refresh_token': refreshToken };
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

  Future<Credential> _retrieveToken(String grantType, Map<String, dynamic> extraBody) async {
    final Map<String, dynamic> requestBody = {
      'grant_type': grantTypeUser, 
      'client_id': clientId,
      'client_secret': clientSecret,
      'scope': scope,
    };
    requestBody.addAll(extraBody);

    final headers = await baseHeaders(appName);
    final response = await client.post('$_baseUrl$oauthPath', headers: headers, body: requestBody);

    final body = Map<String, dynamic>.from(json.decode(response.body));
    final ok = body['ok'] as bool;

    if (!ok) throw _buildApiError(body);

    return Credential(
      accessToken: body['access_token'] as String, 
      refreshToken: body['refresh_token'] as String,
      expires: body['expires_in'] as int
    );
  }

  _buildApiError(Map<String, dynamic> body) {
    return ApiErrorException(body['error'] as String, body['error_description'] as String);
  }

}
