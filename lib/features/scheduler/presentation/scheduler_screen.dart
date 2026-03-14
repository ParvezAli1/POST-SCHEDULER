import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/services.dart';
import '../../../core/models/scheduled_post.dart';
import '../../../core/models/social_account.dart';
import '../../../core/models/social_platform.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  final TextEditingController _inlineMessageController =
      TextEditingController();
  final TextEditingController _inlineCaptionController =
      TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _dialogCaptionController =
      TextEditingController();
  List<String> _inlineMediaPaths = <String>[];
  List<String> _dialogMediaPaths = <String>[];
  bool _inlineInstagramCloseFriends = false;
  bool _dialogInstagramCloseFriends = false;
  final Set<SocialPlatform> _connectingPlatforms = <SocialPlatform>{};
  SocialPlatform _inlineSelectedPlatform = SocialPlatform.instagram;
  PostType _inlinePostType = PostType.photo;
  DateTime _inlineSelectedScheduleAt = DateTime.now().add(
    const Duration(hours: 2),
  );
  SocialPlatform _selectedPlatform = SocialPlatform.instagram;
  PostType _selectedPostType = PostType.photo;
  DateTime _selectedScheduleAt = DateTime.now().add(const Duration(hours: 2));

  @override
  void dispose() {
    _inlineMessageController.dispose();
    _inlineCaptionController.dispose();
    _messageController.dispose();
    _dialogCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postRepository = AppServices.postRepository;
    final authRepository = AppServices.authRepository;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _openQuickDraftDialog(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<SocialAccount>>(
        valueListenable: authRepository.accountsNotifier,
        builder: (context, accounts, _) {
          final inlineConnected = _isPlatformConnected(
            _inlineSelectedPlatform,
            accounts,
          );
          final inlineConnecting = _connectingPlatforms.contains(
            _inlineSelectedPlatform,
          );

          return ListView(
            children: [
              SectionCard(
                title: 'Quick schedule',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _inlineMessageController,
                      decoration: const InputDecoration(
                        labelText: 'Post message',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SocialPlatform>(
                      initialValue: _inlineSelectedPlatform,
                      decoration: const InputDecoration(labelText: 'Platform'),
                      items: SocialPlatform.values
                          .map(
                            (platform) => DropdownMenuItem(
                              value: platform,
                              child: Text(
                                _platformLabelWithConnection(
                                  platform,
                                  accounts,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _inlineSelectedPlatform = value;
                          _inlinePostType = _ensureSupportedType(
                            platform: value,
                            selectedType: _inlinePostType,
                          );
                          if (!_showInstagramCloseFriendsFor(
                            value,
                            _inlinePostType,
                          )) {
                            _inlineInstagramCloseFriends = false;
                          }
                        });
                      },
                    ),
                    if (!inlineConnected) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_inlineSelectedPlatform.label} not connected.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: inlineConnecting
                                ? null
                                : () {
                                    _connectPlatform(_inlineSelectedPlatform);
                                  },
                            child: Text(
                              inlineConnecting ? 'Connecting...' : 'Connect',
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PostType>(
                      initialValue: _inlinePostType,
                      decoration: const InputDecoration(labelText: 'Post type'),
                      items: _postTypesForPlatform(_inlineSelectedPlatform)
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(
                                _postTypeLabelForPlatform(
                                  platform: _inlineSelectedPlatform,
                                  type: type,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _inlinePostType = value;
                          if (!_showInstagramCloseFriendsFor(
                            _inlineSelectedPlatform,
                            _inlinePostType,
                          )) {
                            _inlineInstagramCloseFriends = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_showCaptionFieldFor(_inlineSelectedPlatform)) ...[
                      TextField(
                        controller: _inlineCaptionController,
                        decoration: const InputDecoration(
                          labelText: 'Caption',
                          hintText: 'Add caption for media post',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_showInstagramCloseFriendsFor(
                      _inlineSelectedPlatform,
                      _inlinePostType,
                    )) ...[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _inlineInstagramCloseFriends,
                        title: const Text('Instagram Close Friends'),
                        subtitle: const Text(
                          'Only selected close friends can see this story.',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _inlineInstagramCloseFriends = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _pickInlineMedia,
                      icon: const Icon(Icons.perm_media_outlined),
                      label: Text(
                        _inlineMediaPaths.isEmpty
                            ? 'Pick media'
                            : 'Picked ${_inlineMediaPaths.length} file(s)',
                      ),
                    ),
                    if (_inlineMediaPaths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final mediaPath in _inlineMediaPaths)
                            Chip(label: Text(_fileNameFromPath(mediaPath))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Schedule date & time: ${_formatDate(_inlineSelectedScheduleAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickInlineDate,
                            child: const Text('Pick date'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickInlineTime,
                            child: const Text('Pick time'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _addInlineDraft(accounts),
                      icon: const Icon(Icons.schedule_send_outlined),
                      label: const Text('Add to drafts'),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Drafts',
                trailing: TextButton(
                  onPressed: () => _openQuickDraftDialog(context),
                  child: const Text('New draft'),
                ),
                child: ValueListenableBuilder(
                  valueListenable: postRepository.draftsNotifier,
                  builder: (context, drafts, _) {
                    if (drafts.isEmpty) {
                      return const EmptyState(
                        title: 'No drafts yet',
                        subtitle: 'Create a quick draft to start scheduling.',
                      );
                    }

                    return Column(
                      children: [
                        for (final draft in drafts)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(draft.message),
                            subtitle: Text('${draft.platform.label} draft'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    postRepository.scheduleDraft(draft.id);
                                  },
                                  child: const Text('Schedule'),
                                ),
                                IconButton(
                                  tooltip: 'Delete draft',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    _confirmDeleteDraft(draft);
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              SectionCard(
                title: 'Scheduled',
                child: ValueListenableBuilder(
                  valueListenable: postRepository.scheduledPostsNotifier,
                  builder: (context, posts, _) {
                    if (posts.isEmpty) {
                      return const EmptyState(
                        title: 'Nothing scheduled',
                        subtitle: 'Move a draft into the calendar to publish.',
                      );
                    }

                    return Column(
                      children: [
                        for (final post in posts)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(post.message),
                            subtitle: Text(
                              '${post.platform.label} · ${_formatDate(post.scheduledAt)}',
                            ),
                            trailing: Text(_statusLabel(post.status)),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickInlineDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _inlineSelectedScheduleAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _inlineSelectedScheduleAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _inlineSelectedScheduleAt.hour,
        _inlineSelectedScheduleAt.minute,
      );
    });
  }

  Future<void> _pickInlineTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_inlineSelectedScheduleAt),
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _inlineSelectedScheduleAt = DateTime(
        _inlineSelectedScheduleAt.year,
        _inlineSelectedScheduleAt.month,
        _inlineSelectedScheduleAt.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _addInlineDraft(List<SocialAccount> accounts) {
    final message = _inlineMessageController.text.trim();
    final mediaUrls = _inlineMediaPaths;
    if (!_isPlatformConnected(_inlineSelectedPlatform, accounts)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_inlineSelectedPlatform.label} is not connected. Tap Connect first.',
          ),
        ),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a post message.')),
      );
      return;
    }

    if (_requiresMedia(_inlinePostType) && mediaUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo, video, and story posts need at least one media file.',
          ),
        ),
      );
      return;
    }

    if (_inlineSelectedScheduleAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a future date/time.')),
      );
      return;
    }

    AppServices.postRepository.addDraft(
      platform: _inlineSelectedPlatform,
      message: message,
      postType: _inlinePostType,
      mediaUrls: mediaUrls,
      caption: _inlineCaptionController.text.trim().isEmpty
          ? null
          : _inlineCaptionController.text.trim(),
      instagramCloseFriends: _inlineInstagramCloseFriends,
      scheduledAt: _inlineSelectedScheduleAt,
    );

    setState(() {
      _inlineMessageController.clear();
      _inlineCaptionController.clear();
      _inlineMediaPaths = <String>[];
      _inlineInstagramCloseFriends = false;
      _inlineSelectedScheduleAt = DateTime.now().add(const Duration(hours: 2));
      _inlineSelectedPlatform = SocialPlatform.instagram;
      _inlinePostType = _postTypesForPlatform(SocialPlatform.instagram).first;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft added to schedule.')));
  }

  Future<void> _openQuickDraftDialog(BuildContext context) async {
    _messageController.clear();
    _dialogCaptionController.clear();
    _dialogMediaPaths = <String>[];
    _dialogInstagramCloseFriends = false;
    _selectedPlatform = SocialPlatform.instagram;
    _selectedPostType = _postTypesForPlatform(SocialPlatform.instagram).first;
    _selectedScheduleAt = DateTime.now().add(const Duration(hours: 2));

    final authRepository = AppServices.authRepository;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ValueListenableBuilder<List<SocialAccount>>(
              valueListenable: authRepository.accountsNotifier,
              builder: (context, accounts, _) {
                final dialogConnected = _isPlatformConnected(
                  _selectedPlatform,
                  accounts,
                );
                final dialogConnecting = _connectingPlatforms.contains(
                  _selectedPlatform,
                );

                return AlertDialog(
                  title: const Text('Quick draft'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Post message',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SocialPlatform>(
                        initialValue: _selectedPlatform,
                        decoration: const InputDecoration(
                          labelText: 'Platform',
                        ),
                        items: SocialPlatform.values
                            .map(
                              (platform) => DropdownMenuItem(
                                value: platform,
                                child: Text(
                                  _platformLabelWithConnection(
                                    platform,
                                    accounts,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            _selectedPlatform = value;
                            _selectedPostType = _ensureSupportedType(
                              platform: value,
                              selectedType: _selectedPostType,
                            );
                            if (!_showInstagramCloseFriendsFor(
                              value,
                              _selectedPostType,
                            )) {
                              _dialogInstagramCloseFriends = false;
                            }
                          });
                        },
                      ),
                      if (!dialogConnected) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_selectedPlatform.label} not connected.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            TextButton(
                              onPressed: dialogConnecting
                                  ? null
                                  : () {
                                      _connectPlatform(
                                        _selectedPlatform,
                                        setDialogState: setDialogState,
                                      );
                                    },
                              child: Text(
                                dialogConnecting ? 'Connecting...' : 'Connect',
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PostType>(
                        initialValue: _selectedPostType,
                        decoration: const InputDecoration(
                          labelText: 'Post type',
                        ),
                        items: _postTypesForPlatform(_selectedPlatform)
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  _postTypeLabelForPlatform(
                                    platform: _selectedPlatform,
                                    type: type,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            _selectedPostType = value;
                            if (!_showInstagramCloseFriendsFor(
                              _selectedPlatform,
                              _selectedPostType,
                            )) {
                              _dialogInstagramCloseFriends = false;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_showCaptionFieldFor(_selectedPlatform)) ...[
                        TextField(
                          controller: _dialogCaptionController,
                          decoration: const InputDecoration(
                            labelText: 'Caption',
                            hintText: 'Add caption for media post',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_showInstagramCloseFriendsFor(
                        _selectedPlatform,
                        _selectedPostType,
                      )) ...[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _dialogInstagramCloseFriends,
                          title: const Text('Instagram Close Friends'),
                          subtitle: const Text(
                            'Only selected close friends can see this story.',
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              _dialogInstagramCloseFriends = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickMediaFiles(
                            _selectedPostType,
                          );
                          if (!context.mounted || picked.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            _dialogMediaPaths = picked;
                          });
                        },
                        icon: const Icon(Icons.perm_media_outlined),
                        label: Text(
                          _dialogMediaPaths.isEmpty
                              ? 'Pick media'
                              : 'Picked ${_dialogMediaPaths.length} file(s)',
                        ),
                      ),
                      if (_dialogMediaPaths.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final mediaPath in _dialogMediaPaths)
                              Chip(label: Text(_fileNameFromPath(mediaPath))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Schedule date & time: ${_formatDate(_selectedScheduleAt)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedScheduleAt,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );

                                if (pickedDate == null || !context.mounted) {
                                  return;
                                }

                                setDialogState(() {
                                  _selectedScheduleAt = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    _selectedScheduleAt.hour,
                                    _selectedScheduleAt.minute,
                                  );
                                });
                              },
                              child: const Text('Pick date'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    _selectedScheduleAt,
                                  ),
                                );

                                if (pickedTime == null || !context.mounted) {
                                  return;
                                }

                                setDialogState(() {
                                  _selectedScheduleAt = DateTime(
                                    _selectedScheduleAt.year,
                                    _selectedScheduleAt.month,
                                    _selectedScheduleAt.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              },
                              child: const Text('Pick time'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final message = _messageController.text.trim();
                        final mediaUrls = _dialogMediaPaths;
                        if (!_isPlatformConnected(
                          _selectedPlatform,
                          accounts,
                        )) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${_selectedPlatform.label} is not connected. Tap Connect first.',
                              ),
                            ),
                          );
                          return;
                        }

                        if (message.isEmpty) {
                          return;
                        }

                        if (_requiresMedia(_selectedPostType) &&
                            mediaUrls.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Photo, video, and story posts need at least one media file.',
                              ),
                            ),
                          );
                          return;
                        }

                        if (_selectedScheduleAt.isBefore(DateTime.now())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please choose a future date/time.',
                              ),
                            ),
                          );
                          return;
                        }

                        AppServices.postRepository.addDraft(
                          platform: _selectedPlatform,
                          message: message,
                          postType: _selectedPostType,
                          mediaUrls: mediaUrls,
                          caption: _dialogCaptionController.text.trim().isEmpty
                              ? null
                              : _dialogCaptionController.text.trim(),
                          instagramCloseFriends: _dialogInstagramCloseFriends,
                          scheduledAt: _selectedScheduleAt,
                        );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save draft'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _connectPlatform(
    SocialPlatform platform, {
    StateSetter? setDialogState,
  }) async {
    if (_connectingPlatforms.contains(platform)) {
      return;
    }

    setState(() {
      _connectingPlatforms.add(platform);
    });
    setDialogState?.call(() {});

    try {
      await AppServices.authRepository.connectWithOAuth(platform);
      if (!mounted) {
        return;
      }

      final connected = _isPlatformConnected(
        platform,
        AppServices.authRepository.accounts,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? '${platform.label} connected successfully.'
                : 'Could not connect ${platform.label}. Check OAuth settings.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect ${platform.label}.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _connectingPlatforms.remove(platform);
        });
      }
      setDialogState?.call(() {});
    }
  }

  Future<void> _confirmDeleteDraft(ScheduledPost draft) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete draft?'),
          content: Text('Remove draft for ${draft.platform.label}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    AppServices.postRepository.deleteDraft(draft.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft deleted.')));
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(PostStatus status) {
    switch (status) {
      case PostStatus.draft:
        return 'Draft';
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

  Future<void> _pickInlineMedia() async {
    final picked = await _pickMediaFiles(_inlinePostType);
    if (!mounted || picked.isEmpty) {
      return;
    }

    setState(() {
      _inlineMediaPaths = picked;
    });
  }

  Future<List<String>> _pickMediaFiles(PostType type) async {
    final allowedExtensions = _extensionsFor(type);
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null) {
      return <String>[];
    }

    return result.files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toList();
  }

  List<String> _extensionsFor(PostType type) {
    switch (type) {
      case PostType.text:
        return const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'mp4', 'mov'];
      case PostType.photo:
        return const ['jpg', 'jpeg', 'png', 'webp', 'heic'];
      case PostType.video:
        return const ['mp4', 'mov', 'mkv', 'webm'];
      case PostType.story:
        return const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'mp4', 'mov'];
    }
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? path : segments.last;
  }

  bool _requiresMedia(PostType type) {
    return type == PostType.photo ||
        type == PostType.video ||
        type == PostType.story;
  }

  bool _showCaptionFieldFor(SocialPlatform platform) {
    return platform != SocialPlatform.x;
  }

  bool _showInstagramCloseFriendsFor(SocialPlatform platform, PostType type) {
    return platform == SocialPlatform.instagram && type == PostType.story;
  }

  List<PostType> _postTypesForPlatform(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagram:
        return const [PostType.photo, PostType.video, PostType.story];
      case SocialPlatform.facebook:
        return const [
          PostType.text,
          PostType.photo,
          PostType.video,
          PostType.story,
        ];
      case SocialPlatform.x:
        return const [PostType.text, PostType.photo, PostType.video];
      case SocialPlatform.threads:
        return const [PostType.text, PostType.photo, PostType.video];
      case SocialPlatform.linkedin:
        return const [PostType.photo, PostType.video];
    }
  }

  PostType _ensureSupportedType({
    required SocialPlatform platform,
    required PostType selectedType,
  }) {
    final allowed = _postTypesForPlatform(platform);
    if (allowed.contains(selectedType)) {
      return selectedType;
    }
    return allowed.first;
  }

  String _postTypeLabelForPlatform({
    required SocialPlatform platform,
    required PostType type,
  }) {
    if (platform == SocialPlatform.x && type == PostType.text) {
      return 'Tweet';
    }
    if (platform == SocialPlatform.x && type == PostType.photo) {
      return 'Photo Tweet';
    }
    if (platform == SocialPlatform.x && type == PostType.video) {
      return 'Video Tweet';
    }
    if (platform == SocialPlatform.threads && type == PostType.text) {
      return 'Thread';
    }
    if (platform == SocialPlatform.instagram && type == PostType.video) {
      return 'Reel';
    }
    return type.label;
  }

  bool _isPlatformConnected(
    SocialPlatform platform,
    List<SocialAccount> accounts,
  ) {
    return accounts.any(
      (account) => account.platform == platform && account.connected,
    );
  }

  String _platformLabelWithConnection(
    SocialPlatform platform,
    List<SocialAccount> accounts,
  ) {
    final connected = _isPlatformConnected(platform, accounts);
    if (connected) {
      return platform.label;
    }
    return '${platform.label} (Connect)';
  }
}
