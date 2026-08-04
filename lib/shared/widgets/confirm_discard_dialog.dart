import 'package:flutter/material.dart';

/// 작성/수정 중인 내용을 저장하지 않고 나갈 것인지 확인하는 공용 다이얼로그.
/// true를 반환하면 나가도 된다는 뜻.
Future<bool> confirmDiscardDialog(
  BuildContext context, {
  String title = '작성 중인 내용이 있어요',
  String content = '지금 나가면 작성한 내용이 모두 삭제됩니다.',
  String cancelLabel = '계속 작성',
  String confirmLabel = '나가기',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancelLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                confirmLabel,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ) ??
      false;
}
