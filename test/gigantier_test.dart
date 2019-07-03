import 'package:flutter_test/flutter_test.dart';
import 'package:gigantier_sdk/exceptions.dart';
import 'package:gigantier_sdk/gigantier.dart';
import 'package:gigantier_sdk/preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

class MockClient extends Mock implements http.Client {}

main() {
  final String clientId = 'some_client_id';
  final String clientSecret = 'some_client_secret';
  final String scope = 'Campaign Product';
  final String hostname = 'somestore.com';
  final String appName = 'SomeStore';
  final String protocol = 'https';
  final String apiVersion = 'v1';
  final String baseUrl = '$protocol://$hostname/api/$apiVersion';
  final int expires = 3600;
  final String username = "xxx@xxx.com";
  final String userPwd = "12345678";
  final String userToken = 'some_access_token';
  final String appToken = 'some_app_token';
  final String refreshToken = 'some_refresh_token';
  final String invalidGrantError = 'invalid_grant';
  final String missingCredentialsError = 'missing_credentials';
  final String productsListPath = '/Product/list';
  final String userDetailPath = '/User/me';
  final String productName = 'Some Product';
  final String userName = 'Some User';
  
  _baseHeaders() => Gigantier.baseHeaders(appName);
  _buildGigantier(client) => Gigantier(hostname, clientId, clientSecret, scope, appName, client: client);
  _expirationEpoch() => DateTime.now().add(Duration(seconds: 3600)).millisecondsSinceEpoch;

  test('valid app token', () async {
    final client = MockClient();
    SharedPreferences.setMockInitialValues({});
    SharedPreferences pref = await SharedPreferences.getInstance();

    final randomAppToken = '${appToken}_${DateTime.now().millisecondsSinceEpoch}';

    final request = appTokenRequest(clientId, clientSecret, scope);
    final response = appTokenResponse(randomAppToken, expires, scope);
    
    final headers = await _baseHeaders();
    when(client.post('$baseUrl${Gigantier.oauthPath}', headers: headers, body: request)).thenAnswer(
      (_) => Future.value(http.Response(response, 200))
    );

    final gigantier = _buildGigantier(client);
    final responseAppToken = await gigantier.getAppToken();
    final expiresEpoch = Preferences.epochFromExpires(expires);
    final prefEpoch = pref.getInt(Preferences.appTokenExpires);

    expect(responseAppToken, equals(randomAppToken));
    expect(pref.getString(Preferences.appToken), equals(randomAppToken));
    expect(prefEpoch, greaterThan(expiresEpoch - 10 * 1000));
    expect(prefEpoch, lessThan(expiresEpoch + 10 * 1000));
  });

  test('valid authentication', () async {
    final client = MockClient();
    SharedPreferences.setMockInitialValues({});
    SharedPreferences pref = await SharedPreferences.getInstance();

    final randomUserToken = '${userToken}_${DateTime.now().millisecondsSinceEpoch}';
    final randomRefreshToken = '${refreshToken}_${DateTime.now().millisecondsSinceEpoch}';

    final request = userTokenRequest(clientId, clientSecret, scope, username, userPwd);
    final response = userTokenResponse(randomUserToken, expires, scope, randomRefreshToken);
    
    final headers = await _baseHeaders();
    when(client.post('$baseUrl${Gigantier.oauthPath}', headers: headers, body: request)).thenAnswer(
      (_) => Future.value(http.Response(response, 200))
    );

    final gigantier = _buildGigantier(client);
    final credential = await gigantier.authenticate(username, userPwd);
    final expiresEpoch = Preferences.epochFromExpires(expires);
    final prefEpoch = pref.getInt(Preferences.userTokenExpires);

    expect(credential.accessToken, equals(randomUserToken));
    expect(credential.expires, equals(expires));
    expect(credential.refreshToken, equals(randomRefreshToken));
    expect(pref.getString(Preferences.userToken), equals(randomUserToken));
    expect(pref.getString(Preferences.userRefreshToken), equals(randomRefreshToken));
    expect(prefEpoch, greaterThan(expiresEpoch - 10 * 1000));
    expect(prefEpoch, lessThan(expiresEpoch + 10 * 1000));
  });

  test('invalid authentication', () async {
    final client = MockClient();
    SharedPreferences.setMockInitialValues({});
    SharedPreferences pref = await SharedPreferences.getInstance();

    final request = userTokenRequest(clientId, clientSecret, scope, username, userPwd);
    final response = invalidGrantResponse(invalidGrantError);
    
    final headers = await _baseHeaders();
    when(client.post('$baseUrl${Gigantier.oauthPath}', headers: headers, body: request)).thenAnswer(
      (_) => Future.value(http.Response(response, 404))
    );

    final gigantier = _buildGigantier(client);

    try {
      await gigantier.authenticate(username, userPwd);
      fail("ApiErrorException not thrown");
    } catch (e) {
      expect(e, isInstanceOf<ApiErrorException>());
      expect(e.error, equals(invalidGrantError));
      expect(pref.getString(Preferences.userToken), equals(null));
      expect(pref.getString(Preferences.userRefreshToken), equals(null));
    }
  });

  test('valid api call', () async {
    final client = MockClient();
    SharedPreferences.setMockInitialValues({});

    final randomAppToken = '${appToken}_${DateTime.now().millisecondsSinceEpoch}';

    final tokenRequest = appTokenRequest(clientId, clientSecret, scope);
    final tokenResponse = appTokenResponse(randomAppToken, expires, scope);

    final request = {
      'access_token': randomAppToken
    };
    
    final response = productsResponse(productName);
    final headers = await _baseHeaders();

    when(client.post('$baseUrl${Gigantier.oauthPath}', headers: headers, body: tokenRequest)).thenAnswer(
      (_) => Future.value(http.Response(tokenResponse, 200))
    );

    when(client.post('$baseUrl$productsListPath', headers: headers, body: request)).thenAnswer(
      (_) => Future.value(http.Response(response, 200))
    );

    final gigantier = _buildGigantier(client);
    final result = await gigantier.call(productsListPath);

    productsValidations(result, productName);
  });

  test('api call cached app token', () async {
    final client = MockClient();

    final randomAppToken = '${appToken}_${DateTime.now().millisecondsSinceEpoch}';
    SharedPreferences.setMockInitialValues({
      Preferences.sharedPrefPrefix + Preferences.appToken: randomAppToken,
      Preferences.sharedPrefPrefix + Preferences.appTokenExpires: _expirationEpoch(),
      Preferences.sharedPrefPrefix + Preferences.appRefreshToken: ""
    });

    final request = {
      'access_token': randomAppToken
    };

    final response = productsResponse(productName);
    final headers = await _baseHeaders();

    when(client.post('$baseUrl$productsListPath', headers: headers, body: request)).thenAnswer(
      (_) => Future.value(http.Response(response, 200))
    );

    final gigantier = _buildGigantier(client);
    final result = await gigantier.call(productsListPath);

    productsValidations(result, productName);
  });

  test('api call renew app token', () async {
    final client = MockClient();
    
    final randomAppToken = '${appToken}_${DateTime.now().millisecondsSinceEpoch}';
    SharedPreferences.setMockInitialValues({
      Preferences.sharedPrefPrefix + Preferences.appToken: randomAppToken,
      Preferences.sharedPrefPrefix + Preferences.appTokenExpires: _expirationEpoch(),
      Preferences.sharedPrefPrefix + Preferences.appRefreshToken: ""
    });

    final tokenRequest = appTokenRequest(clientId, clientSecret, scope);
    final tokenResponse = appTokenResponse(randomAppToken, expires, scope);

    final request = {
      'access_token': randomAppToken
    };

    final invalidTokenResponse = invalidAccessTokenResponse();
    
    final response = productsResponse(productName);
    
    final productsAnswers = [
      Future.value(http.Response(invalidTokenResponse, 401)),
      Future.value(http.Response(response, 200))
    ];

    final headers = await _baseHeaders();

    when(client.post('$baseUrl${Gigantier.oauthPath}', headers: headers, body: tokenRequest)).thenAnswer(
      (_) => Future.value(http.Response(tokenResponse, 200))
    );

    when(client.post('$baseUrl$productsListPath', headers: headers, body: request)).thenAnswer((_) => 
      productsAnswers.removeAt(0)
    );

    final gigantier = _buildGigantier(client);
    final result = await gigantier.call(productsListPath);

    productsValidations(result, productName);
  });

  test('valid api authenticated call', () async {
    final client = MockClient();
    SharedPreferences.setMockInitialValues({});

    final randomUserToken = '${userToken}_${DateTime.now().millisecondsSinceEpoch}';
    final randomRefreshToken = '${refreshToken}_${DateTime.now().millisecondsSinceEpoch}';

    final tokenRequest = userTokenRequest(clientId, clientSecret, scope, username, userPwd);
    final tokenResponse = userTokenResponse(randomUserToken, expires, scope, randomRefreshToken);

    final request = {
      'access_token': randomUserToken
    };
    
    final response = userDetailResponse(userName);

    final headers = await _baseHeaders();
    when(client.post('$baseUrl${Gigantier.oauthPath}', headers: headers, body: tokenRequest)).thenAnswer(
      (_) => Future.value(http.Response(tokenResponse, 200))
    );

    when(client.post('$baseUrl$userDetailPath', headers: headers, body: request)).thenAnswer(
      (_) => Future.value(http.Response(response, 200))
    );

    final gigantier = _buildGigantier(client);
    await gigantier.authenticate(username, userPwd);
    final result = await gigantier.authenticatedCall(userDetailPath);

    userDetailValidations(result, userName);
  });

  test('invalid api authenticated call on missing authenticate', () async {
    final client = MockClient();
    SharedPreferences.setMockInitialValues({});
    SharedPreferences pref = await SharedPreferences.getInstance();

    final randomUserToken = '${userToken}_${DateTime.now().millisecondsSinceEpoch}';

    final request = {
      'access_token': randomUserToken
    };
    
    final response = userDetailResponse(userName);

    final headers = await _baseHeaders();
    when(client.post('$baseUrl$userDetailPath', headers: headers, body: request)).thenAnswer(
      (_) => Future.value(http.Response(response, 200))
    );

    final gigantier = _buildGigantier(client);

    try {
      await gigantier.authenticatedCall(userDetailPath);
      fail("ApiErrorException not thrown");
    } catch (e) {
      expect(e, isInstanceOf<ApiErrorException>());
      expect(e.error, equals(missingCredentialsError));
      expect(pref.getString(Preferences.userToken), equals(null));
      expect(pref.getString(Preferences.userRefreshToken), equals(null));
    }
  });

  test('api athenticated call cached user token', () async {
    final client = MockClient();

    final randomUserToken = '${userToken}_${DateTime.now().millisecondsSinceEpoch}';
    final randomRefreshToken = '${refreshToken}_${DateTime.now().millisecondsSinceEpoch}';
    SharedPreferences.setMockInitialValues({
      Preferences.sharedPrefPrefix + Preferences.userToken: randomUserToken,
      Preferences.sharedPrefPrefix + Preferences.userTokenExpires: _expirationEpoch(),
      Preferences.sharedPrefPrefix + Preferences.userRefreshToken: randomRefreshToken
    });

    final request = {
      'access_token': randomUserToken
    };

    final response = userDetailResponse(userName);
    final headers = await _baseHeaders();

    when(client.post('$baseUrl$userDetailPath', headers: headers, body: request)).thenAnswer(
      (_) => Future.value(http.Response(response, 200))
    );

    final gigantier = _buildGigantier(client);
    final result = await gigantier.authenticatedCall(userDetailPath);

    userDetailValidations(result, userName);
  });

  test('api authenticated call renew user token', () async {
    final client = MockClient();
    
    final randomUserToken = '${userToken}_${DateTime.now().millisecondsSinceEpoch}';
    final randomRefreshToken = '${refreshToken}_${DateTime.now().millisecondsSinceEpoch}';
    SharedPreferences.setMockInitialValues({
      Preferences.sharedPrefPrefix + Preferences.userToken: randomUserToken,
      Preferences.sharedPrefPrefix + Preferences.userTokenExpires: _expirationEpoch(),
      Preferences.sharedPrefPrefix + Preferences.userRefreshToken: randomRefreshToken
    });

    final tokenRequest = refreshTokenRequest(clientId, clientSecret, scope, randomRefreshToken);
    final tokenResponse = userTokenResponse(randomUserToken, expires, scope, randomRefreshToken);

    final request = {
      'access_token': randomUserToken
    };

    final invalidTokenResponse = invalidAccessTokenResponse();
    final response = userDetailResponse(userName);
    
    final userDetailAnswer = [
      Future.value(http.Response(invalidTokenResponse, 401)),
      Future.value(http.Response(response, 200))
    ];

    final headers = await _baseHeaders();

    when(client.post('$baseUrl${Gigantier.oauthPath}', headers: headers, body: tokenRequest)).thenAnswer(
      (_) => Future.value(http.Response(tokenResponse, 200))
    );

    when(client.post('$baseUrl$userDetailPath', headers: headers, body: request)).thenAnswer((_) => 
      userDetailAnswer.removeAt(0)
    );

    final gigantier = _buildGigantier(client);
    final result = await gigantier.authenticatedCall(userDetailPath);

    userDetailValidations(result, userName);
  });

}
