import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

// Enhancement 3: renders the User model (built from UserService.getUserData)
// and adapts to the LoginType of the session. DummyJSON users get a read-only
// profile; Firebase users can also update their username, change their
// password and delete their account.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  late Future<User> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _userService.getUser();
  }

  void _reload() {
    setState(() {
      _userFuture = _userService.getUser();
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await _userService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  Future<void> _updateUsername(User user) async {
    final username = await showDialog<String>(
      context: context,
      builder: (_) => _UsernameDialog(initial: user.username),
    );
    if (username == null) return;

    try {
      await _userService.updateUsername(username: username);
      if (!mounted) return;
      _reload();
      _toast('Username updated');
    } catch (e) {
      if (!mounted) return;
      _toast(UserService.authErrorMessage(e));
    }
  }

  Future<void> _changePassword(User user) async {
    final passwords = await showDialog<({String current, String next})>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (passwords == null) return;

    try {
      await _userService.resetPasswordFromCurrentPassword(
        currentPassword: passwords.current,
        newPassword: passwords.next,
        email: user.email,
      );
      if (!mounted) return;
      _toast('Password changed');
    } catch (e) {
      if (!mounted) return;
      _toast(UserService.authErrorMessage(e));
    }
  }

  Future<void> _deleteAccount(User user) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null) return;

    try {
      await _userService.deleteAccount(email: user.email, password: password);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
    } catch (e) {
      if (!mounted) return;
      _toast(UserService.authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: CustomText(
              text: 'Failed to load profile',
              fontSize: 14.sp,
            ),
          );
        }

        final user = snapshot.data!;
        final isFirebase = user.loginType == LoginType.firebase.name;
        final displayName = user.fullName.isNotEmpty
            ? user.fullName
            : user.username;

        final tiles = <_ProfileTile>[
          _ProfileTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
          ),
          if (isFirebase) ...[
            _ProfileTile(
              icon: Icons.cake_outlined,
              label: 'Age',
              value: user.age > 0 ? '${user.age}' : '-',
            ),
            _ProfileTile(
              icon: Icons.phone_outlined,
              label: 'Contact',
              value: user.phone.isNotEmpty ? user.phone : '-',
            ),
            _ProfileTile(
              icon: Icons.badge_outlined,
              label: 'UID',
              value: user.uid.length > 8
                  ? '${user.uid.substring(0, 8)}...'
                  : user.uid,
            ),
          ] else ...[
            _ProfileTile(
              icon: Icons.wc,
              label: 'Gender',
              value: user.gender,
            ),
            _ProfileTile(
              icon: Icons.badge_outlined,
              label: 'User ID',
              value: '#${user.id}',
            ),
          ],
          _ProfileTile(
            icon: Icons.verified_user_outlined,
            label: 'Signed in with',
            value: isFirebase ? 'Firebase' : 'DummyJSON',
          ),
        ];

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48.r,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: user.image.isNotEmpty
                      ? NetworkImage(user.image)
                      : null,
                  child: user.image.isEmpty
                      ? Icon(Icons.person, size: 48.sp)
                      : null,
                ),
                SizedBox(height: 12.h),
                CustomText(
                  text: displayName.isNotEmpty ? displayName : user.email,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
                if (user.username.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  CustomText(
                    text: '@${user.username}',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ],
                SizedBox(height: 24.h),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: Colors.grey.shade300),
                        tiles[i],
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                if (isFirebase) ...[
                  _ActionButton(
                    icon: Icons.edit,
                    label: 'Update Username',
                    onPressed: () => _updateUsername(user),
                  ),
                  SizedBox(height: 12.h),
                  _ActionButton(
                    icon: Icons.lock_reset,
                    label: 'Change Password',
                    onPressed: () => _changePassword(user),
                  ),
                  SizedBox(height: 12.h),
                  _ActionButton(
                    icon: Icons.delete_forever,
                    label: 'Delete Account',
                    color: Colors.red.shade900,
                    onPressed: () => _deleteAccount(user),
                  ),
                  SizedBox(height: 12.h),
                ],
                _ActionButton(
                  icon: Icons.logout,
                  label: 'Log Out',
                  color: Colors.redAccent,
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = const Color(0xFF1A237E),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: CustomText(
          text: label,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: Colors.grey.shade600),
          SizedBox(width: 12.w),
          CustomText(text: label, fontSize: 13.sp),
          const Spacer(),
          CustomText(
            text: value,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

// The dialogs own their controllers so they're only disposed once the dialog
// route (including its closing animation) is fully gone.
class _UsernameDialog extends StatefulWidget {
  final String initial;

  const _UsernameDialog({required this.initial});

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update username'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Username'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Username is required' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, (current: _current.text, next: _next.text));
            }
          },
          child: const Text('Change'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This permanently deletes your account. Enter your password to '
            'confirm.',
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _password.text),
          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}
