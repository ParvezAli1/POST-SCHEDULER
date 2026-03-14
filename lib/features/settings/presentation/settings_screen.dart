import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/services.dart';
import '../../../core/widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;
  bool _smartWindows = false;

  @override
  Widget build(BuildContext context) {
    final authRepository = AppServices.authRepository;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SectionCard(
            title: 'Connections',
            trailing: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(connectAccountsRoute);
              },
              child: const Text('Manage'),
            ),
            child: ValueListenableBuilder(
              valueListenable: authRepository.accountsNotifier,
              builder: (context, accounts, _) {
                final connected = accounts
                    .where((account) => account.connected)
                    .length;
                return Text('$connected connected accounts');
              },
            ),
          ),
          SectionCard(
            title: 'Notifications',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _pushEnabled,
                  title: const Text('Push notifications'),
                  subtitle: const Text('Alerts for publishing status'),
                  onChanged: (value) {
                    setState(() {
                      _pushEnabled = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _smartWindows,
                  title: const Text('Smart send windows'),
                  subtitle: const Text('Auto-schedule for peak times'),
                  onChanged: (value) {
                    setState(() {
                      _smartWindows = value;
                    });
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: authRepository.biometricRequiredNotifier,
                  builder: (context, required, _) {
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: required,
                      title: const Text('Fingerprint for publishing'),
                      subtitle: const Text(
                        'Require biometric unlock before posting',
                      ),
                      onChanged: (value) {
                        authRepository.setBiometricRequiredForPublishing(value);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Realtime backend',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Configured for Firebase Auth.'),
                SizedBox(height: 8),
                Text('Enable Email/Password in Firebase Console.'),
              ],
            ),
          ),
          SectionCard(
            title: 'Session',
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  authRepository.logout();
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(authRoute, (route) => false);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
