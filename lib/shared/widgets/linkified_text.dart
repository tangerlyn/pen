import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'center_toast.dart';

final _urlRegex = RegExp(r'https?:\/\/\S+', caseSensitive: false);
const _trailingPunctuation = '.,!?)]}"\'';
const _linkColor = Color(0xFF2196F3);

/// 본문에 있는 URL을 자동으로 감지해서 탭 가능한 링크로 보여주는 텍스트.
/// 링크를 누르면 앱을 벗어나지 않는 인앱 브라우저로 열림.
class LinkifiedText extends StatelessWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    if (!_urlRegex.hasMatch(text)) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final linkStyle = baseStyle.copyWith(
      color: _linkColor,
      decoration: TextDecoration.underline,
      decorationColor: _linkColor,
    );

    return Text.rich(
      TextSpan(children: _buildSpans(context, baseStyle, linkStyle)),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<InlineSpan> _buildSpans(
    BuildContext context,
    TextStyle baseStyle,
    TextStyle linkStyle,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _urlRegex.allMatches(text)) {
      var url = match.group(0)!;
      var end = match.end;
      // 문장 끝 마침표·괄호 등이 URL에 딸려 들어가지 않도록 잘라냄
      while (url.isNotEmpty && _trailingPunctuation.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
        end--;
      }
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _openLink(context, url),
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!opened && context.mounted) {
        showCenterToast(context, message: '링크를 열 수 없어요.');
      }
    } catch (_) {
      if (context.mounted) {
        showCenterToast(context, message: '링크를 열 수 없어요.');
      }
    }
  }
}
