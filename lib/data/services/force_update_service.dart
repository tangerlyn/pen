import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

enum UpdateRequirement { none, optional, required }

class ForceUpdateService {
  static const _iosAppStoreUrl = 'https://apps.apple.com/app/id6791441592';
  static const _androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.nibpen.nibpen';

  static const _dismissedVersionKey = 'update_prompt_dismissed_version';
  static const _dismissedAtKey = 'update_prompt_dismissed_at';
  static const _remindAfter = Duration(days: 3);

  /// Remote Config로 업데이트 필요 여부를 판단한다.
  /// - `min_version`보다 낮으면 [UpdateRequirement.required] (닫을 수 없는 안내)
  /// - `latest_version`보다 낮으면 [UpdateRequirement.optional] (나중에 가능)
  /// 값을 비워 두면 해당 안내는 꺼진다. 네트워크 오류 등은 안내 없음으로 처리.
  static Future<UpdateRequirement> checkUpdate() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await remoteConfig.fetchAndActivate();

      final current = (await PackageInfo.fromPlatform()).version;
      final minVersion = remoteConfig.getString('min_version').trim();
      if (minVersion.isNotEmpty && isVersionLower(current, minVersion)) {
        return UpdateRequirement.required;
      }

      final latest = remoteConfig.getString('latest_version').trim();
      if (latest.isEmpty || !isVersionLower(current, latest)) {
        return UpdateRequirement.none;
      }
      // "나중에"를 누른 버전이면 며칠 동안은 다시 묻지 않는다.
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getString(_dismissedVersionKey);
      final dismissedAt = prefs.getInt(_dismissedAtKey) ?? 0;
      final recentlyDismissed = dismissed == latest &&
          DateTime.now().millisecondsSinceEpoch - dismissedAt <
              _remindAfter.inMilliseconds;
      if (recentlyDismissed) return UpdateRequirement.none;
      _pendingLatest = latest;
      return UpdateRequirement.optional;
    } catch (_) {
      return UpdateRequirement.none;
    }
  }

  static String? _pendingLatest;

  static Future<void> _rememberDismissed() async {
    final latest = _pendingLatest;
    if (latest == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedVersionKey, latest);
      await prefs.setInt(
        _dismissedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// "1.2" · "1.2.3" · "1.2.3+4" 모두 처리. 숫자가 아닌 부분은 0으로 본다.
  @visibleForTesting
  static bool isVersionLower(String current, String target) {
    List<int> parse(String v) {
      final parts = v.split('+').first.split('.');
      return List.generate(
        3,
        (i) => i < parts.length ? int.tryParse(parts[i].trim()) ?? 0 : 0,
      );
    }

    final c = parse(current);
    final t = parse(target);
    for (var i = 0; i < 3; i++) {
      if (c[i] < t[i]) return true;
      if (c[i] > t[i]) return false;
    }
    return false;
  }

  static Future<void> openStore() async {
    final url = Platform.isIOS ? _iosAppStoreUrl : _androidPlayStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void showForceUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          backgroundColor: const Color(0xFFFFFCF5),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_outlined,
                    size: 34,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('업데이트 필요', style: AppTextStyles.titleLarge),
                const SizedBox(height: 10),
                Text(
                  '최신 버전으로 업데이트 후\n이용할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: openStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      '업데이트하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 선택 업데이트 안내 — "나중에"로 닫을 수 있다.
  static Future<void> showOptionalUpdateDialog(BuildContext context) async {
    final update = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: const Color(0xFFFFFCF5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_outlined,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text('새 버전이 나왔어요', style: AppTextStyles.titleLarge),
              const SizedBox(height: 10),
              Text(
                '더 편해진 만티를 만나 보세요.\n지금 업데이트할까요?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    '업데이트하기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  '나중에',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (update == true) {
      await openStore();
    } else {
      await _rememberDismissed();
    }
  }
}
