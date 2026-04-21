@echo off
REM Always run web on the same port so IndexedDB (Hive storage) persists
REM across restarts. Origin = scheme + host + port, so a different port
REM means a different IndexedDB database — which is why data looked like
REM it was being wiped between `flutter run` sessions.
flutter run -d chrome --web-port=5050 --web-hostname=localhost %*
