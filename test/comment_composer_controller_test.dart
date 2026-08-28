import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/shared/controllers/comment_composer_controller.dart';

void main() {
  test('reply and submit state transitions stay consistent', () {
    final controller = CommentComposerController();
    addTearDown(controller.dispose);

    controller.textController.text = '  답글 내용  ';
    controller.startReply('comment-1', '사용자');
    controller.beginSubmit();

    expect(controller.trimmedText, '답글 내용');
    expect(controller.isReplying, isTrue);
    expect(controller.replyTargetNickname, '사용자');
    expect(controller.isSubmitting, isTrue);

    controller.clearReply(clearText: true);
    controller.finishSubmit();

    expect(controller.isReplying, isFalse);
    expect(controller.textController.text, isEmpty);
    expect(controller.isSubmitting, isFalse);
  });
}
