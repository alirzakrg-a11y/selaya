import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/permission_service.dart';

/// Shown when a permission can no longer be requested in-app (iOS won't re-prompt
/// after a denial; Android permanent denial). Offers a deep-link to system
/// Settings. Returns nothing — opening Settings is fire-and-forget.
Future<void> showOpenSettingsDialog(
  BuildContext context,
  PermissionService perms, {
  required String title,
  required String message,
}) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('common.openSettings'.tr()),
        ),
      ],
    ),
  );
  if (open == true) await perms.openSettings();
}
