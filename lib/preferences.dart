import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static final String userToken = "usertoken";
  static final String userTokenExpires = "usertokenexpires";
  static final String userRefreshToken = "userrefreshtoken";
  static final String appToken = "apptoken";
  static final String appTokenExpires = "apptokenexpires";
  static final String appRefreshToken = "apprefreshtoken";
  static final sharedPrefPrefix = 'flutter.';

  Future<bool> resetAppToken() async {
    final appTokenResult = await setAppToken("") ?? true;
    final appRefreshTokenResult = await setAppRefreshToken("") ?? true;
    final appTokenExpirationResult = await setAppTokenExpiration(0) ?? true;
    return appTokenResult && appRefreshTokenResult && appTokenExpirationResult;
  }

  Future<String> getAppToken() async {
    return SharedPreferences.getInstance().then((prefs) => prefs.getString(appToken));
  }

  Future<bool> setAppToken(String token) async {
    return SharedPreferences.getInstance().then((prefs) => prefs.setString(appToken, token));
  }

  Future<bool> setAppTokenExpiration(int expires) async {
    return SharedPreferences.getInstance().then((prefs) {
      return prefs.setInt(appTokenExpires, epochFromExpires(expires));
    });
  }

  Future<bool> isAppTokenExpired() async {
    final token = await getAppToken();
    return SharedPreferences.getInstance().then((prefs) async {
      final expires = await getAppTokenExpiration();
      return token != null && token != "" && isTokenExpired(expires);
    });
  }

  Future<int> getAppTokenExpiration() {
    return SharedPreferences.getInstance().then((prefs) => prefs.getInt(appTokenExpires));
  }

  Future<bool> setAppRefreshToken(String token) async {
    return SharedPreferences.getInstance().then((prefs) => prefs.setString(appRefreshToken, token));
  }

  Future<String> getAppRefreshToken() async {
    return SharedPreferences.getInstance().then((prefs) => prefs.getString(appRefreshToken));
  }

  Future<bool> resetUserToken() async {
    final userTokenResult = await setUserToken("") ?? true;
    final userRefreshTokenResult = await setUserRefreshToken("") ?? true;
    final userTokenExpirationResult = await setUserTokenExpiration(0) ?? true;
    return userTokenResult && userRefreshTokenResult && userTokenExpirationResult;
  }

  Future<String> getUserToken() async {
    return SharedPreferences.getInstance().then((prefs) => prefs.getString(userToken));
  }

  Future<bool> setUserRefreshToken(String token) async {
    return SharedPreferences.getInstance().then((prefs) => prefs.setString(userRefreshToken, token));
  }

  Future<String> getUserRefreshToken() async {
    return SharedPreferences.getInstance().then((prefs) => prefs.getString(userRefreshToken));
  }

  Future<bool> setUserToken(String token) async {
    return SharedPreferences.getInstance().then((prefs) => prefs.setString(userToken, token));
  }

  Future<bool> setUserTokenExpiration(int expires) async {
    return SharedPreferences.getInstance().then((prefs) {
      return prefs.setInt(userTokenExpires, epochFromExpires(expires));
    });
  }

  Future<bool> isUserTokenExpired() async {
    final token = await getUserToken();
    final expires = await getUserTokenExpiration();
    return token != null && token != "" && isTokenExpired(expires);
  }

  Future<int> getUserTokenExpiration() {
    return SharedPreferences.getInstance().then((prefs) => prefs.getInt(userTokenExpires));
  }

  bool isTokenExpired(int millisSinceEpoch) {
    final now = new DateTime.now();
    final expiration = DateTime.fromMillisecondsSinceEpoch(millisSinceEpoch);
    return now.isAfter(expiration);
  }

  static int epochFromExpires(int expires) => DateTime.now().add(Duration(milliseconds: expires)).microsecondsSinceEpoch;
}
