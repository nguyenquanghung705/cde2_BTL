#!/usr/bin/env bash
# Always run web on the same port so IndexedDB (Hive storage) persists
# across restarts. Origin = scheme + host + port, so a different port
# means a different IndexedDB database — which is why data looked like
# it was being wiped between `flutter run` sessions.
exec flutter run -d chrome --web-port=5050 --web-hostname=localhost "$@"
