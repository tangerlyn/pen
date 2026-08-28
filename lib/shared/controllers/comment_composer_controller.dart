import 'package:flutter/material.dart';

class CommentComposerController {
  final textController = TextEditingController();
  final focusNode = FocusNode();

  String? replyTargetCommentId;
  String? replyTargetNickname;
  bool isSubmitting = false;

  String get trimmedText => textController.text.trim();
  bool get isReplying => replyTargetCommentId != null;

  void startReply(String commentId, String nickname) {
    replyTargetCommentId = commentId;
    replyTargetNickname = nickname;
  }

  void clearReply({bool clearText = false}) {
    replyTargetCommentId = null;
    replyTargetNickname = null;
    if (clearText) textController.clear();
  }

  void beginSubmit() => isSubmitting = true;
  void finishSubmit() => isSubmitting = false;

  void dispose() {
    textController.dispose();
    focusNode.dispose();
  }
}
