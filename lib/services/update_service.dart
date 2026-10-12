import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String? apkDownloadUrl;
  final String htmlUrl;
  final bool hasUpdate;
  final int? apkSizeBytes;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.htmlUrl,
    required this.hasUpdate,
    this.apkSizeBytes,
  });
}

class UpdateProgress {
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final String speedText;
  final bool isCompleted;
  final String? error;

  const UpdateProgress({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    required this.speedText,
    this.isCompleted = false,
    this.error,
  });
}

class UpdateService {
  static const String repoOwner = 'lubovoladuska';
  static const String repoName = 'LiReader';
  static const String apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;
  static const int _notificationId = 1001;

  static CancelToken? _cancelToken;
  static ValueNotifier<UpdateProgress?> downloadProgressNotifier = ValueNotifier(null);

  /// Initialize local notifications for Android
  static Future<void> initNotifications() async {
    if (_notificationsInitialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          // If tapped when downloaded, we could re-trigger installer
        },
      );

      // Create Android Notification Channel
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'lireader_updates',
            'Обновления приложения',
            description: 'Уведомления о загрузке и установке обновлений LiReader',
            importance: Importance.low, // silent updates while downloading
          ),
        );
      }
      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Check GitHub Releases for updates
  static Future<UpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final dio = Dio();
      final response = await dio.get(
        apiUrl,
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? '').replaceAll('v', '').trim();
        final body = data['body'] as String? ?? 'Новая версия LiReader!';
        final htmlUrl = data['html_url'] as String? ?? 'https://github.com/$repoOwner/$repoName/releases';

        String? apkUrl;
        int? apkSize;
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url'] as String?;
              apkSize = asset['size'] as int?;
              break;
            }
          }
        }

        final hasNewer = _isNewerVersion(currentVersion, tagName);

        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: tagName.isEmpty ? currentVersion : tagName,
          releaseNotes: body,
          apkDownloadUrl: apkUrl,
          htmlUrl: htmlUrl,
          hasUpdate: hasNewer,
          apkSizeBytes: apkSize,
        );
      }
    } catch (e) {
      debugPrint('Update check error: $e');
    }

    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseNotes: '',
      apkDownloadUrl: null,
      htmlUrl: 'https://github.com/$repoOwner/$repoName/releases',
      hasUpdate: false,
    );
  }

  /// Semantic version comparator
  static bool _isNewerVersion(String current, String remote) {
    if (remote.isEmpty) return false;
    try {
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (remoteParts.length < 3) {
        remoteParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
    } catch (e) {
      debugPrint('Version comparison error: $e');
    }
    return false;
  }

  /// Download the APK with progress updates to UI and Android notification bar
  static Future<bool> startDownloadAndInstall({
    required String downloadUrl,
    required String targetVersion,
  }) async {
    await initNotifications();

    final dio = Dio();
    _cancelToken = CancelToken();

    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/LiReader-v$targetVersion.apk';

    final file = File(savePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    int lastBytes = 0;
    DateTime lastTime = DateTime.now();
    DateTime lastNotificationTime = DateTime.now();
    String currentSpeed = '0 KB/s';

    downloadProgressNotifier.value = const UpdateProgress(
      progress: 0.0,
      receivedBytes: 0,
      totalBytes: 0,
      speedText: 'Подключение...',
    );

    try {
      await _updateNotification(
        progressPercent: 0,
        title: 'LiReader — Загрузка обновления v$targetVersion',
        body: 'Начало загрузки...',
      );

      await dio.download(
        downloadUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;

          final now = DateTime.now();
          final durationMs = now.difference(lastTime).inMilliseconds;

          if (durationMs >= 600) {
            final byteDelta = received - lastBytes;
            final speedBytesPerSec = (byteDelta / (durationMs / 1000.0));
            currentSpeed = _formatSpeed(speedBytesPerSec);
            lastBytes = received;
            lastTime = now;
          }

          final progressRatio = (received / total).clamp(0.0, 1.0);
          final percent = (progressRatio * 100).toInt();

          downloadProgressNotifier.value = UpdateProgress(
            progress: progressRatio,
            receivedBytes: received,
            totalBytes: total,
            speedText: currentSpeed,
          );

          // Update Android notification (throttle to 1s to prevent system spam)
          if (now.difference(lastNotificationTime).inMilliseconds >= 1000) {
            lastNotificationTime = now;
            final recMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totMB = (total / (1024 * 1024)).toStringAsFixed(1);
            _updateNotification(
              progressPercent: percent,
              title: 'LiReader — Скачивание ($percent%)',
              body: '$recMB / $totMB МБ • $currentSpeed',
            );
          }
        },
      );

      // Download completed
      downloadProgressNotifier.value = UpdateProgress(
        progress: 1.0,
        receivedBytes: (await file.length()),
        totalBytes: (await file.length()),
        speedText: 'Готово',
        isCompleted: true,
      );

      await _showCompletedNotification(targetVersion, savePath);

      // Open Android Package Installer
      await installApk(savePath);
      return true;
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        downloadProgressNotifier.value = null;
        await _cancelNotification();
        return false;
      }
      debugPrint('Download error: $e');
      downloadProgressNotifier.value = UpdateProgress(
        progress: 0,
        receivedBytes: 0,
        totalBytes: 0,
        speedText: 'Ошибка',
        error: e.toString(),
      );
      await _cancelNotification();
      return false;
    }
  }

  static void cancelDownload() {
    _cancelToken?.cancel('Отменено пользователем');
    _cancelToken = null;
    _cancelNotification();
    downloadProgressNotifier.value = null;
  }

  /// Open APK with Android installer
  static Future<void> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      debugPrint('OpenFilex result: ${result.message} (type: ${result.type})');
    } catch (e) {
      debugPrint('Error triggering APK installer: $e');
    }
  }

  static Future<void> _updateNotification({
    required int progressPercent,
    required String title,
    required String body,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'lireader_updates',
        'Обновления приложения',
        channelDescription: 'Уведомления о загрузке и установке обновлений LiReader',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: progressPercent,
        ongoing: true,
        onlyAlertOnce: true,
        icon: '@mipmap/ic_launcher',
      );
      await _notificationsPlugin.show(
        id: _notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }

  static Future<void> _showCompletedNotification(String version, String filePath) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'lireader_updates',
        'Обновления приложения',
        channelDescription: 'Уведомления о загрузке и установке обновлений LiReader',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        icon: '@mipmap/ic_launcher',
      );
      await _notificationsPlugin.show(
        id: _notificationId,
        title: 'Обновление LiReader v$version загружено 🎉',
        body: 'Нажмите для завершения установки',
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: filePath,
      );
    } catch (_) {}
  }

  static Future<void> _cancelNotification() async {
    try {
      await _notificationsPlugin.cancel(id: _notificationId);
    } catch (_) {}
  }

  static String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} МБ/с';
    } else if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} КБ/с';
    }
    return '${bytesPerSec.toStringAsFixed(0)} Б/с';
  }
}
