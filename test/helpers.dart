import 'package:flutter_test/flutter_test.dart';
import 'package:gigantier_sdk/gigantier.dart';

void productsValidations(Map<String, dynamic> result, String productName) {
  expect(result['total'] as int, equals(1));
  expect(result['ok'] as bool, equals(true));
  expect(result['products'] as List, hasLength(1));
  
  final product = (result['products'] as List).first;
  expect(product['id'] as int, equals(1));
  expect(product['name'] as String, equals(productName));
}

void userDetailValidations(Map<String, dynamic> result, String userName) {
  expect(result['id'] as int, equals(1));
  expect(result['ok'] as bool, equals(true));
  expect(result['name'] as String, equals(userName));
}

String invalidGrantResponse(String invalidGrantError) {
  return """ {
    "error": "$invalidGrantError",
    "error_description": "Invalid username and password combination",
    "ok": false
  } """;
}

String invalidAccessTokenResponse() {
  return """ {
    "ok": false,
    "error": "Access token inválido."
  } """;
}

String productsResponse(String productName) {
  return """ {
    "products": [ { "id": 1, "name": "$productName" } ],
    "total": 1,
    "ok": true
  } """;
}

String userDetailResponse(String name) {
  return """ {
    "id": 1,
    "name": "$name",
    "ok": true
  } """;
}

String appTokenResponse(String randomAppToken, int expires, String scope) {
  return """ {
    "access_token": "$randomAppToken",
    "expires_in": $expires,
    "token_type": "Bearer",
    "scope": "$scope",
    "ok": true
  } """;
}

Map<String, String> appTokenRequest(String clientId, String clientSecret, String scope) {
  return {
    'grant_type': Gigantier.grantTypeApp, 
    'client_id': clientId,
    'client_secret': clientSecret,
    'scope': scope
  };
}

Map<String, String> refreshTokenRequest(String clientId, String clientSecret, String scope, String refreshToken) {
  return {
    'grant_type': Gigantier.grantTypeUser, 
    'client_id': clientId,
    'client_secret': clientSecret,
    'scope': scope,
    'refresh_token': refreshToken
  };
}

String userTokenResponse(String randomUserToken, int expires, String scope, String randomRefreshToken) {
  return """ {
    "access_token": "$randomUserToken",
    "expires_in": $expires,
    "token_type": "Bearer",
    "scope": "$scope",
    "refresh_token": "$randomRefreshToken",
    "ok": true
  } """;
}

Map<String, String> userTokenRequest(String clientId, String clientSecret, String scope, String username, String userPwd) {
  return {
    'grant_type': Gigantier.grantTypeUser, 
    'client_id': clientId,
    'client_secret': clientSecret,
    'scope': scope,
    'username': username,
    'password': userPwd
  };
}