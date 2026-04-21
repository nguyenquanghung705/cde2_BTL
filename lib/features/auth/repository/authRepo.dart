// ignore_for_file: file_names, invalid_return_type_for_catch_error

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:financy_ui/app/services/Server/dio_client.dart';
import 'package:financy_ui/features/Users/models/userModels.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:financy_ui/app/services/Local/settings_service.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class Authrepo {
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in aborted by user');
    }
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> loginWithGoogle(String tokenID) async {
    // fetch token
    final data = {"idToken": tokenID};
    final res = await ApiService()
        .post('/auth/login', data: data)
        .catchError(
          (e) => {throw Exception('Login with Google failed: ${e.toString()}')},
        );
    if (res.statusCode != 200) {
      throw Exception('Login with Google failed: ${res.statusMessage}');
    }

    // Get tokens and user data from response
    final accessToken = res.data['accessToken'];
    final refreshToken = res.data['refreshToken'];
    final userData = res.data['user']; // User data is now in the login response

    //save tokens to local storage
    Hive.box('jwt').put('accessToken', accessToken);
    Hive.box('jwt').put('refreshToken', refreshToken);
    ApiService().setToken(accessToken);

    // Nếu user có picture là link, tải về app data và lưu path local
    String? localPicturePath;
    if (userData['picture'] != null &&
        userData['picture'].toString().startsWith('http')) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final fileName =
            'google_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savePath = '${dir.path}/$fileName';
        await Dio().download(userData['picture'], savePath);
        localPicturePath = savePath;
      } catch (e) {
        localPicturePath = null;
      }
    }

    // Lưu user vào Hive, thay picture = local path nếu có
    final userJson = Map<String, dynamic>.from(userData);
    if (localPicturePath != null) {
      userJson['photo'] = localPicturePath;
    }
    await Hive.box<UserModel>(
      'userBox',
    ).put('currentUser', UserModel.fromJson(userJson));
    await SettingsService.setAppState(true);
    await SettingsService.setAuthMode('google');
  }

  //get user data from local storage
  Future<UserModel?> getCurrentUser() async {
    final boxUser = Hive.box<UserModel>('userBox').get('currentUser');
    // Nếu picture là local path, trả về luôn, nếu là link thì không cần tải lại
    return boxUser;
  }

  // ---- Email/password (local) ----
  // NOTE: credentials are stored locally in Hive box 'authCredentials' and
  // hashed with SHA-256. This is adequate for an offline demo. A real backend
  // must validate/hash server-side; do not ship plain-text local auth in prod.

  String _hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final creds = Hive.box('authCredentials');
    if (creds.containsKey(normalized)) {
      throw Exception('Email đã được đăng ký');
    }

    final now = DateTime.now();
    final userId = 'local_${now.millisecondsSinceEpoch}';
    final user = UserModel(
      id: userId,
      uid: userId,
      name: name.trim(),
      email: normalized,
      picture: '',
      dateOfBirth: now,
      createdAt: now,
    );

    await creds.put(normalized, {
      'passwordHash': _hashPassword(password),
      'userId': userId,
      'name': user.name,
    });
    await Hive.box<UserModel>('userBox').put('currentUser', user);
    await SettingsService.setAppState(true);
    await SettingsService.setAuthMode('email');
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final creds = Hive.box('authCredentials');
    final record = creds.get(normalized);
    if (record == null) {
      throw Exception('Tài khoản không tồn tại');
    }
    if (record['passwordHash'] != _hashPassword(password)) {
      throw Exception('Mật khẩu không đúng');
    }

    final userBox = Hive.box<UserModel>('userBox');
    var user = userBox.get('currentUser');
    if (user == null || user.email != normalized) {
      user = UserModel(
        id: record['userId'] ?? 'local_${DateTime.now().millisecondsSinceEpoch}',
        uid: record['userId'] ?? '',
        name: record['name'] ?? '',
        email: normalized,
        picture: '',
        dateOfBirth: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await userBox.put('currentUser', user);
    }
    await SettingsService.setAppState(true);
    await SettingsService.setAuthMode('email');
  }

  //login with no account (guest mode)
  Future<void> loginWithNoAccount() async {
    await SettingsService.setAppState(true);
    await SettingsService.setAuthMode('guest');
  }

  // Logout — clears auth state and returns user to the login screen.
  // Works for any auth mode (google / email / guest). Local user data (the
  // UserModel in 'userBox' and transactions) is preserved so signing back
  // in picks up where the user left off.
  Future<void> logout() async {
    // Sign out from Firebase/Google if applicable. These can throw when
    // Firebase isn't configured (stub options) — swallow errors.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    // Clear JWT tokens.
    final jwtBox = Hive.box('jwt');
    await jwtBox.delete('accessToken');
    await jwtBox.delete('refreshToken');

    // Flip app state to logged-out so MainApp routes to Login.
    await SettingsService.setAppState(false);
    await SettingsService.setAuthMode('guest');
    await SettingsService.setJustLoggedOut(true);
  }
}
