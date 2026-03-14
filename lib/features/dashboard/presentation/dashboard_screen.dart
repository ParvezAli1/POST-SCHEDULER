import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/services.dart';
import '../../../core/models/scheduled_post.dart';
import '../../../core/models/social_platform.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<RealtimeUpdate> _updates = [];
  StreamSubscription<RealtimeUpdate>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AppServices.postRepository.updates.listen((update) {
      setState(() {
        _updates.insert(0, update);
        if (_updates.length > 5) {
          _updates.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postRepository = AppServices.postRepository;
    final authRepository = AppServices.authRepository;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          SectionCard(
            title: 'Today overview',
            trailing: Text(
              _formatDate(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            child: ValueListenableBuilder(
              valueListenable: postRepository.scheduledPostsNotifier,
              builder: (context, posts, _) {
                final scheduledCount = posts
                    .where((post) => post.status != PostStatus.published)
                    .length;
                final publishedCount = posts
                    .where((post) => post.status == PostStatus.published)
                    .length;
                return Row(
                  children: [
                    _StatTile(
                      label: 'Scheduled',
                      value: scheduledCount.toString(),
                    ),
                    const SizedBox(width: 16),
                    _StatTile(
                      label: 'Published',
                      value: publishedCount.toString(),
                    ),
                    const SizedBox(width: 16),
                    ValueListenableBuilder(
                      valueListenable: authRepository.accountsNotifier,
                      builder: (context, accounts, _) {
                        final connected = accounts
                            .where((account) => account.connected)
                            .length;
                        return _StatTile(
                          label: 'Connected',
                          value: '$connected/${accounts.length}',
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          SectionCard(
            title: 'Realtime activity',
            trailing: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(connectAccountsRoute);
              },
              child: const Text('Connect accounts'),
            ),
            child: _updates.isEmpty
                ? const EmptyState(
                    title: 'Waiting for updates',
                    subtitle:
                        'Realtime status pings will appear as posts go live.',
                  )
                : Column(
                    children: [
                      for (final update in _updates)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_statusLabel(update.status)),
                          subtitle: Text(update.note),
                          trailing: Text(_formatTime(update.at)),
                        ),
                    ],
                  ),
          ),
          SectionCard(
            title: 'Upcoming posts',
            child: ValueListenableBuilder(
              valueListenable: postRepository.scheduledPostsNotifier,
              builder: (context, posts, _) {
                if (posts.isEmpty) {
                  return const EmptyState(
                    title: 'No scheduled posts',
                    subtitle: 'Create a draft to start planning your week.',
                  );
                }

                final upcoming = posts.take(3).toList();
                return Column(
                  children: [
                    for (final post in upcoming)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(post.message),
                        subtitle: Text(post.platform.label),
                        trailing: Text(_formatTime(post.scheduledAt)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _statusLabel(PostStatus status) {
    switch (status) {
      case PostStatus.draft:
        return 'Draft queued';
      case PostStatus.scheduled:
        return 'Scheduled';
      case PostStatus.publishing:
        return 'Publishing';
      case PostStatus.published:
        return 'Published';
      case PostStatus.failed:
        return 'Failed';
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
