import 'package:flutter/foundation.dart';

bool isSupportedMobilePlatform({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) {
    return false;
  }

  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

bool get isRunningOnSupportedMobilePlatform => isSupportedMobilePlatform(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
