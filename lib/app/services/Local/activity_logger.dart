import 'package:financy_ui/app/services/Local/activity_log_db.dart';
import 'package:flutter/widgets.dart';

/// Thin convenience wrapper so call sites don't need to build ActivityEntry.
class ActivityLogger {
  ActivityLogger._();

  static Future<void> log(
    String event, {
    String? route,
    Map<String, Object?>? data,
  }) async {
    await ActivityLogDb.instance.record(ActivityEntry(
      timestamp: DateTime.now(),
      event: event,
      route: route,
      data: data,
    ));
  }
}

/// Writes every named navigation into the activity log.
///
/// Attach via `MaterialApp(navigatorObservers: [ActivityNavigatorObserver()])`.
class ActivityNavigatorObserver extends NavigatorObserver {
  void _log(String action, Route<dynamic>? route, Route<dynamic>? previous) {
    final name = route?.settings.name;
    final prev = previous?.settings.name;
    if (name == null) return;
    ActivityLogger.log('nav_$action', route: name, data: {
      if (prev != null) 'from': prev,
    });
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _log('push', route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _log('replace', newRoute, oldRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _log('pop', route, previousRoute);
  }
}
