import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

// houses the dark and light mode
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // rebuilds the screen whenever theme provide notifies listeners
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const CustomText(
          text: 'Settings',
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: CustomText(
                text: themeProvider.isDark ? 'Dark Mode' : 'Light Mode',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              subtitle: CustomText(text: 'Enabled', fontSize: 12),
              value: themeProvider.isDark,
              onChanged: (value) {
                // Enhancement 3: calling setDarkMode here notifies listeners,
                context.read<ThemeProvider>().setDarkMode(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const CustomText(
                text: 'Log Out',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }

  // clears the session (Firebase sign out + saved data) and returns to sign-in
  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await UserService().logout();
    navigator.pushNamedAndRemoveUntil('/signin', (route) => false);
  }
}
