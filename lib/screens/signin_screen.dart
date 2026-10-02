import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/user_service.dart';
import '../widgets/custom_text.dart';

// Enhancement 2: custom sign-in UI wired to UserService.loginUser, which
// hits dummyjson's /auth/login and persists the response to SharedPreferences
// (UserService.saveUserData) before routing to home.
class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final UserService _userService = UserService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  LoginType _loginType = LoginType.dummyJson;

  bool get _isFirebase => _loginType == LoginType.firebase;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    if (_formKey.currentState!.validate()) {
      try {
        if (_isFirebase) {
          // the username field carries the email address for Firebase
          await _userService.signIn(
            email: _usernameController.text.trim(),
            password: _passwordController.text,
          );
        } else {
          // user data is persisted to SharedPreferences by loginUser
          await _userService.loginUser(
            _usernameController.text.trim(),
            _passwordController.text,
          );
        }

        if (!mounted) return;
        setState(() => _isLoading = false);

        // the splash screen appears after login and then routes to home
        Navigator.pushReplacementNamed(context, '/splash');
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login failed: ${_isFirebase ? UserService.authErrorMessage(e) : e}',
            ),
          ),
        );
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/nuicon.jpeg',
                        width: 28.w,
                        height: 28.w,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.school, size: 28.sp),
                      ),
                      SizedBox(width: 8.w),
                      CustomText(
                        text: 'Welcome',
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  SegmentedButton<LoginType>(
                    segments: const [
                      ButtonSegment(
                        value: LoginType.dummyJson,
                        label: Text('DummyJSON'),
                      ),
                      ButtonSegment(
                        value: LoginType.firebase,
                        label: Text('Firebase'),
                      ),
                    ],
                    selected: {_loginType},
                    onSelectionChanged: (selection) => setState(() {
                      _loginType = selection.first;
                      _usernameController.clear();
                      _formKey.currentState?.reset();
                    }),
                  ),
                  SizedBox(height: 24.h),
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: _isFirebase
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: _isFirebase ? 'Email address' : 'Username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? '${_isFirebase ? 'Email' : 'Username'} is required'
                        : null,
                  ),
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Password is required'
                        : null,
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const CustomText(
                              text: 'Log In',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                  if (_isFirebase)
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pushNamed(context, '/signup'),
                      child: const Text("Don't have an account? Sign up"),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
