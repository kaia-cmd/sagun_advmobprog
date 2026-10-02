import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/user.dart';

/// Which back end authenticated the current session. Screens use this to decide
/// which details and actions to show.
enum LoginType { dummyJson, firebase }

class UserService {
  static const _loginTypeKey = 'loginType';
  // Signup details Firebase Auth can't hold (name, age, contact) are kept per
  // uid under this prefix and survive logout so they're there on next sign-in.
  static const _profilePrefix = 'fb_profile_';

  // ---------------------------------------------------------------------------
  // DummyJSON (REST + SharedPreferences)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> loginUser(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$host/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'expiresInMins': 60,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveUserData(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_loginTypeKey, LoginType.dummyJson.name);
      return data;
    } else {
      throw Exception(response.body);
    }
  }

  /// **Save User Data to SharedPreferences**
  /// Save user data from API response based on User model
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final user = User.fromJson(userData);

    await prefs.setInt('id', user.id);
    await prefs.setString('username', user.username);
    await prefs.setString('email', user.email);
    await prefs.setString('firstName', user.firstName);
    await prefs.setString('lastName', user.lastName);
    await prefs.setString('gender', user.gender);
    await prefs.setString('image', user.image);
    await prefs.setString('accessToken', user.accessToken);
    await prefs.setString('refreshToken', user.refreshToken);

    // Support generic token key if present in API response
    if (userData.containsKey('token')) {
      await prefs.setString('token', userData['token'] ?? '');
    } else if (user.accessToken.isNotEmpty) {
      await prefs.setString('token', user.accessToken);
    }
  }

  // ---------------------------------------------------------------------------
  // Firebase Auth
  // ---------------------------------------------------------------------------

  fb.FirebaseAuth get firebaseAuth => fb.FirebaseAuth.instance;

  fb.User? get currentUser => firebaseAuth.currentUser;

  Stream<fb.User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<fb.UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _markFirebaseSession();
    // Backfills the Users collection for accounts created before chat existed.
    await _syncFirestoreUser();
    return credential;
  }

  Future<fb.UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _markFirebaseSession();
    return credential;
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  Future<void> updateUsername({required String username}) async {
    await currentUser!.updateDisplayName(username);
    await currentUser!.reload();
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    final user = currentUser!;
    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
    await user.delete();
    await firebaseAuth.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_profilePrefix${user.uid}');
    await _clearSession();
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  /// Saves the extra signup fields for the signed-in Firebase user.
  Future<void> saveFirebaseProfile({
    required String firstName,
    required String lastName,
    required int age,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_profilePrefix${currentUser!.uid}',
      jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'phone': phone,
      }),
    );
    await _syncFirestoreUser(firstName: firstName, lastName: lastName);
  }

  /// Mirrors the signed-in Firebase user into Firestore's "Users" collection
  /// so the chat list (ChatService.getUsersStream) has someone to show.
  Future<void> _syncFirestoreUser({String? firstName, String? lastName}) async {
    final user = currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$_profilePrefix${user.uid}');
    final profile = stored == null
        ? <String, dynamic>{}
        : jsonDecode(stored) as Map<String, dynamic>;

    await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'firstName': firstName ?? profile['firstName'] ?? '',
      'lastName': lastName ?? profile['lastName'] ?? '',
    }, SetOptions(merge: true));
  }

  /// Turns a thrown FirebaseAuthException into something worth showing a user.
  static String authErrorMessage(Object error) {
    if (error is fb.FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'That password is too weak.';
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'requires-recent-login':
          return 'Please sign in again and retry.';
        case 'network-request-failed':
          return 'No network connection.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
      }
      return error.message ?? error.code;
    }
    return error.toString();
  }

  Future<void> _markFirebaseSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginTypeKey, LoginType.firebase.name);
  }

  // ---------------------------------------------------------------------------
  // Shared session helpers
  // ---------------------------------------------------------------------------

  Future<LoginType> getLoginType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_loginTypeKey) == LoginType.firebase.name
        ? LoginType.firebase
        : LoginType.dummyJson;
  }

  /// Retrieve user data for whichever back end the session belongs to.
  Future<Map<String, dynamic>> getUserData() async {
    if (await getLoginType() == LoginType.firebase && currentUser != null) {
      return _getFirebaseUserData();
    }

    final prefs = await SharedPreferences.getInstance();

    return {
      'id': prefs.getInt('id') ?? 0,
      'username': prefs.getString('username') ?? '',
      'email': prefs.getString('email') ?? '',
      'firstName': prefs.getString('firstName') ?? '',
      'lastName': prefs.getString('lastName') ?? '',
      'gender': prefs.getString('gender') ?? '',
      'image': prefs.getString('image') ?? '',
      'accessToken': prefs.getString('accessToken') ?? '',
      'refreshToken': prefs.getString('refreshToken') ?? '',
      'token': prefs.getString('token') ?? prefs.getString('accessToken') ?? '',
      'loginType': LoginType.dummyJson.name,
    };
  }

  Future<Map<String, dynamic>> _getFirebaseUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = currentUser!;
    final stored = prefs.getString('$_profilePrefix${user.uid}');
    final profile = stored == null
        ? <String, dynamic>{}
        : jsonDecode(stored) as Map<String, dynamic>;

    // getIdToken transparently refreshes the token once it has expired.
    final token = await user.getIdToken() ?? '';

    return {
      'id': 0,
      'uid': user.uid,
      'username': user.displayName ?? '',
      'email': user.email ?? '',
      'firstName': profile['firstName'] ?? '',
      'lastName': profile['lastName'] ?? '',
      'age': profile['age'] ?? 0,
      'phone': profile['phone'] ?? '',
      'gender': '',
      'image': user.photoURL ?? '',
      'accessToken': token,
      'refreshToken': user.refreshToken ?? '',
      'token': token,
      'loginType': LoginType.firebase.name,
    };
  }

  /// Retrieve User model for the current session
  Future<User> getUser() async {
    final userData = await getUserData();
    return User.fromJson(userData);
  }

  /// **Check if User is Logged In**
  Future<bool> isLoggedIn() async {
    if (await getLoginType() == LoginType.firebase) {
      // Firebase restores its own session from disk on startup.
      return currentUser != null;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  /// **Logout and Clear User Data**
  /// Ends the Firebase session (if any) and wipes the saved session.
  Future<void> logout() async {
    try {
      if (currentUser != null) {
        await firebaseAuth.signOut();
      }
      await _clearSession();
    } catch (e) {
      throw Exception('Failed to log out: $e');
    }
  }

  /// Clears everything except the saved Firebase signup profiles.
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(_profilePrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
