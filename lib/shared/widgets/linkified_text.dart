import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final RegExp _combined = RegExp(
    r'(https?://[^\s]+)|(www\.[^\s]+)|(^|\s)(@[a-z0-9][a-z0-9._]*)',
    caseSensitive: false,
    multiLine: true,
  );

  @override
  void initState() {
    super.initState();
    _attachRecognizers();
  }

  @override
  void didUpdateWidget(LinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
      _attachRecognizers();
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _attachRecognizers() {
    for (final m in _combined.allMatches(widget.text)) {
      final g1 = m.group(1);
      final g2 = m.group(2);
      final g4 = m.group(4);
      if (g1 != null) {
        _recognizers.add(TapGestureRecognizer()..onTap = () => _openUrl(g1));
      } else if (g2 != null) {
        final uriStr = g2.startsWith('http') ? g2 : 'https://$g2';
        _recognizers
            .add(TapGestureRecognizer()..onTap = () => _openUrl(uriStr));
      } else if (g4 != null) {
        final handle = g4.substring(1).toLowerCase();
        _recognizers
            .add(TapGestureRecognizer()..onTap = () => _onMentionTap(handle));
      }
    }
  }

  Future<void> _openUrl(String uriString) async {
    final parsed = Uri.tryParse(uriString);
    if (parsed == null) return;
    if (!await canLaunchUrl(parsed)) return;
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  Future<void> _onMentionTap(String handle) async {
    if (handle.isEmpty) return;
    final profileProvider = context.read<ProfileProvider>();
    final profile = await profileProvider.getProfileByUsername(handle);
    if (!mounted) return;
    if (profile != null) {
      context.push('/user-profile/${profile.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No profile found for @$handle'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = baseStyle.copyWith(
      color: AppTheme.primaryGreen,
      decoration: TextDecoration.underline,
    );
    final mentionStyle = baseStyle.copyWith(
      color: AppTheme.primaryGreen,
      decoration: TextDecoration.none,
    );

    final spans = <InlineSpan>[];
    int start = 0;
    int recIndex = 0;

    for (final m in _combined.allMatches(widget.text)) {
      if (m.start > start) {
        spans.add(TextSpan(
          text: widget.text.substring(start, m.start),
          style: baseStyle,
        ));
      }
      final g1 = m.group(1);
      final g2 = m.group(2);
      final g3 = m.group(3);
      final g4 = m.group(4);
      if (g1 != null) {
        spans.add(TextSpan(
          text: g1,
          style: linkStyle,
          recognizer: _recognizers[recIndex++],
        ));
      } else if (g2 != null) {
        spans.add(TextSpan(
          text: g2,
          style: linkStyle,
          recognizer: _recognizers[recIndex++],
        ));
      } else if (g4 != null) {
        if (g3 != null && g3.isNotEmpty) {
          spans.add(TextSpan(text: g3, style: baseStyle));
        }
        spans.add(TextSpan(
          text: g4,
          style: mentionStyle,
          recognizer: _recognizers[recIndex++],
        ));
      }
      start = m.end;
    }
    if (start < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(start),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
