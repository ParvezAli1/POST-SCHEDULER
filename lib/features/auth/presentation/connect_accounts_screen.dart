import 'package:flutter/material.dart';

import '../../../app/services.dart';
import '../../../core/models/social_account.dart';
import '../../../core/models/social_platform.dart';
import '../../../core/widgets/section_card.dart';

class ConnectAccountsScreen extends StatefulWidget {
  const ConnectAccountsScreen({super.key});

  @override
  State<ConnectAccountsScreen> createState() => _ConnectAccountsScreenState();
}

class _ConnectAccountsScreenState extends State<ConnectAccountsScreen> {
  final Set<SocialPlatform> _busyPlatforms = <SocialPlatform>{};

  Future<void> _toggleConnection(
    SocialPlatform platform,
    bool connect,
    BuildContext context,
  ) async {
    final authRepository = AppServices.authRepository;

    if (_busyPlatforms.contains(platform)) {
      return;
    }

    setState(() {
      _busyPlatforms.add(platform);
    });

    try {
      if (connect) {
        await authRepository.connectWithOAuth(platform);
      } else {
        await authRepository.disconnect(platform);
      }
    } finally {
      if (context.mounted) {
        setState(() {
          _busyPlatforms.remove(platform);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = AppServices.authRepository;

    return Scaffold(
      appBar: AppBar(title: const Text('Connect Accounts')),
      body: ValueListenableBuilder(
        valueListenable: authRepository.accountsNotifier,
        builder: (context, accounts, _) {
          return ListView(
            children: [
              SectionCard(
                title: 'Social Platforms',
                child: Column(
                  children: [
                    for (final account in accounts)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _colorFor(account.platform),
                          child: Icon(
                            _iconFor(account.platform),
                            color: Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(account.platform.label)),
                            if (account.connected)
                              _AuthModeBadge(isRealAuth: account.isRealAuth),
                          ],
                        ),
                        subtitle: Text(_subtitleFor(account)),
                        trailing: Switch.adaptive(
                          value: account.connected,
                          onChanged: (value) {
                            _toggleConnection(account.platform, value, context);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Enable a platform to open social login in-app (OAuth), then auto-refresh tokens for scheduled publishing.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  String _subtitleFor(SocialAccount account) {
    final busy = _busyPlatforms.contains(account.platform);
    if (busy) {
      return 'Connecting with OAuth...';
    }

    if (!account.connected) {
      return '${account.handle} · disconnected';
    }

    final expiresAt = account.accessTokenExpiresAt;
    if (expiresAt == null) {
      return '${account.handle} · connected';
    }

    final remaining = expiresAt.difference(DateTime.now()).inMinutes;
    return '${account.handle} · token ${remaining > 0 ? 'expires in $remaining min' : 'expired'}';
  }

  IconData _iconFor(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagram:
        return Icons.camera_alt_outlined;
      case SocialPlatform.facebook:
        return Icons.facebook_outlined;
      case SocialPlatform.x:
        return Icons.close;
      case SocialPlatform.threads:
        return Icons.message_outlined;
      case SocialPlatform.linkedin:
        return Icons.work_outline;
    }
  }

  Color _colorFor(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagram:
        return const Color(0xFFE1306C);
      case SocialPlatform.facebook:
        return const Color(0xFF1877F2);
      case SocialPlatform.x:
        return Colors.black;
      case SocialPlatform.threads:
        return const Color(0xFF2D2D2D);
      case SocialPlatform.linkedin:
        return const Color(0xFF0A66C2);
    }
  }
}

class _AuthModeBadge extends StatelessWidget {
  const _AuthModeBadge({required this.isRealAuth});

  final bool isRealAuth;

  @override
  Widget build(BuildContext context) {
    final text = isRealAuth ? 'REAL' : 'MOCK';
    final background = isRealAuth
        ? const Color(0xFFE7F7ED)
        : const Color(0xFFFFF2D9);
    final foreground = isRealAuth
        ? const Color(0xFF1B6F3B)
        : const Color(0xFF8A5A00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
