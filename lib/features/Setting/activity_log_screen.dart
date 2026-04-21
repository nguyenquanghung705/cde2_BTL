import 'dart:convert';

import 'package:financy_ui/app/services/Local/activity_log_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<ActivityEntry> _entries = [];
  int _total = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    final list = await ActivityLogDb.instance.recent(limit: 200);
    final n = await ActivityLogDb.instance.count();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _total = n;
      _busy = false;
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá toàn bộ log?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ActivityLogDb.instance.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Nhật ký hoạt động ($_total)'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _load,
          ),
          IconButton(
            tooltip: 'Xoá',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _busy ? null : _clear,
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('Chưa có hoạt động nào'))
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _iconFor(e.event),
                        color: theme.primaryColor,
                      ),
                      title: Text(
                        e.event,
                        style:
                            const TextStyle(fontFamily: 'monospace'),
                      ),
                      subtitle: Text(
                        '${e.timestamp.toLocal().toString().split('.').first}'
                        '${e.route != null ? '  •  ${e.route}' : ''}'
                        '${e.data != null ? '\n${jsonEncode(e.data)}' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                      isThreeLine: e.data != null,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                            text: jsonEncode({
                              'event': e.event,
                              'route': e.route,
                              'data': e.data,
                              'at': e.timestamp.toIso8601String(),
                            }),
                          ));
                        },
                      ),
                    );
                  },
                ),
    );
  }

  IconData _iconFor(String event) {
    if (event.startsWith('nav_')) return Icons.navigation;
    if (event.startsWith('login')) return Icons.login;
    if (event.startsWith('logout')) return Icons.logout;
    if (event.startsWith('export')) return Icons.file_download;
    if (event.startsWith('sync')) return Icons.sync;
    if (event.startsWith('transfer')) return Icons.swap_horiz;
    if (event.startsWith('budget')) return Icons.pie_chart;
    if (event.startsWith('goal')) return Icons.savings;
    return Icons.circle;
  }
}
