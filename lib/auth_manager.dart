// Singleton class to store authentication details for current user.
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'instance_manager.dart';
import 'package:google_sign_in/google_sign_in.dart';

class NotFoundException implements Exception {}

enum AuthState {
  init,               // Startup - request for login name or identifier.
  password,           // Login request for password only.
  passwordTOTP,       // Login request for password + 2FA.
  forgot,             // Forgot password request.
  complete,           // Logged in and authenticated.
  error,              // Error message display.
  guest,              // Logged in as guest only.
  register,           // Requesting to register as new user.
}
class AuthManager {
  static AuthManager? _instance;
  factory AuthManager() => _instance ??= new AuthManager._singleton();
  AuthManager._singleton();       // Empty singleton constructor

  AuthState state = AuthState.init;       // State the Auth Manager is in, used to render UI or check logged-in status.
  Map<String, dynamic> loginUser = {};    // Login details for this user sent back by login request.
  bool isTestUser = false;                // If this is a test user or not
  String _apiToken = '';                  // API token for this login session.
  Map<String, String> get authTokenHeaders => _apiToken == '' ? {} : { 'Authorization': 'Bearer ' + _apiToken };

  Future<void> runLogin(String email, String password) async {
    try {
      // Exchange email/password for API token and details.
      final apiLogin = await InstanceManager().apiRequest("users/login", {
        'email': email,
        'password': password,
        'device_name': 'GeoApp',
      }, 'POST');
      if (!apiLogin.success(APIResponseJSON.map)) {
        if (apiLogin.response.statusCode == 422) {
          final Map<String, dynamic> jsonErrorBody = jsonDecode(utf8.decode(apiLogin.response.bodyBytes));
          final String jsonErrorCode = jsonErrorBody?['errors']?['_ERR']?[0] ?? '';
          if (jsonErrorCode == 'CRED') {
            throw NotFoundException();
          }
        }
        throw Exception("${apiLogin.response.statusCode}: ${apiLogin.response.reasonPhrase ?? 'Unknown error'}");
      }
      loginUser = apiLogin.result['user'];
      _apiToken = apiLogin.result['token'];
      isTestUser = (loginUser?['role'] ?? 0) == 2;    // ROLE_TEST
      state = AuthState.complete;
    } on NotFoundException {
      rethrow;
    } catch (ex) {
      rethrow;
    }
  }

  void loginAsGuest() {
    loginUser = {};
    _apiToken = '';
    state = AuthState.guest;
  }

  void requestRegistration() {
    if (state != AuthState.init) {
      return;
    }
    state = AuthState.register;
  }

  void abortRegistration() {
    if (state != AuthState.register) {
      return;
    }
    state = AuthState.init;
  }

  void forgotPassword() {
    if (state != AuthState.init) {
      return;
    }
    state = AuthState.init;
  }

  GoogleSignIn? _googleSignIn;
  Future<void> loginAsGoogle() async {
  final googleSignIn = GoogleSignIn.instance;

  try {
    // 1. Initialize without scopes (they are now requested during authentication)
    await googleSignIn.initialize(
      clientId: 'YOUR_CLIENT_ID.apps.googleusercontent.com', // Required for Web
    );

    // 2. Use 'scopeHint' to request specific permissions like email
    final googleAccount = await googleSignIn.authenticate(
      scopeHint: ['email', 'openid', 'profile'], 
    );

    if (googleAccount == null) return;

    // 3. To actually get the Access Token for those scopes:
    final authorization = await googleAccount.authorizationClient.authorizeScopes(['email']);
    final String? accessToken = authorization.accessToken;

    debugPrint("Logged in: ${googleAccount.displayName}");
    debugPrint("Access Token: $accessToken");

  } catch (error) {
    debugPrint("Sign in error: $error");
  }
}

  Future<void> rememberLoginTokens() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('api_token', _apiToken);
    prefs.setString('login_user', json.encode(loginUser));
  }

  Future<bool> recallLoginTokens() async {
    final prefs = await SharedPreferences.getInstance();
    String newApiToken = prefs.containsKey('api_token') ? (prefs.getString('api_token') ?? '') : '';
    String newLoginUser = prefs.containsKey('login_user') ? (prefs.getString('login_user') ?? '') : '';
    if (newApiToken == '' || newLoginUser == '') {
      return false;
    }
    try {
      final dynamic newLoginUserMap = jsonDecode(newLoginUser);
      loginUser = newLoginUserMap;
      _apiToken = newApiToken;
      return true;
    } catch (ex) {
      return false;
    }
  }
}