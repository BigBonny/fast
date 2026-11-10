import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../services/assistant_service.dart';
import '../theme.dart';
import '../l10n/tr.dart';

class _Msg {
  final String text;
  final bool mine;
  const _Msg(this.text, this.mine);
}

/// In-app FAST assistant — a lightweight chat over /api/assistant/chat.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.pro = false});
  final bool pro;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    AssistantService.instance.pro = widget.pro;
    _messages.add(
      _Msg(
        tr(
          context,
          widget.pro ? 'assistant_greeting_pro' : 'assistant_greeting',
        ),
        false,
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_Msg(text, true));
      _sending = true;
    });
    _input.clear();
    _jump();
    try {
      final reply = await AssistantService.instance.chat(text);
      if (mounted) setState(() => _messages.add(_Msg(reply, false)));
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(_Msg(tr(context, 'assistant_err'), false)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _jump();
    }
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FASTProvider>();
    final fast = context.fast;
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    const tail = Radius.circular(FASTSpace.s4);
    const round = Radius.circular(FASTRadius.md);
    return Scaffold(
      backgroundColor: fast.bg,
      appBar: AppBar(
        backgroundColor: fast.bg,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: fast.cardHigh,
                shape: BoxShape.circle,
                border: Border.all(color: fast.line),
              ),
              child: Icon(Icons.bolt, color: fast.t1, size: 18),
            ),
            const SizedBox(width: FASTSpace.s12),
            Flexible(
              child: Text(
                tr(context, 'assistant_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FASTText.item.copyWith(color: fast.t1),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(FASTSpace.s16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: FASTSpace.s12),
                      padding: const EdgeInsets.all(FASTSpace.s12),
                      decoration: BoxDecoration(
                        color: fast.card,
                        borderRadius: const BorderRadiusDirectional.only(
                          topStart: round,
                          topEnd: round,
                          bottomStart: tail,
                          bottomEnd: round,
                        ),
                        border: Border.all(color: fast.line),
                      ),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fast.t2,
                        ),
                      ),
                    ),
                  );
                }
                final m = _messages[i];
                return Align(
                  alignment: m.mine
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: FASTSpace.s12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: FASTSpace.s16,
                      vertical: FASTSpace.s12,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: m.mine ? fast.ink : fast.card,
                      borderRadius: BorderRadiusDirectional.only(
                        topStart: round,
                        topEnd: round,
                        bottomStart: m.mine ? round : tail,
                        bottomEnd: m.mine ? tail : round,
                      ),
                      border: m.mine ? null : Border.all(color: fast.line),
                    ),
                    child: Text(
                      m.text,
                      style: FASTText.body.copyWith(
                        color: m.mine ? fast.onInk : fast.t1,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FASTSpace.s16,
                FASTSpace.s8,
                FASTSpace.s16,
                FASTSpace.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      textCapitalization: TextCapitalization.sentences,
                      style: FASTText.body.copyWith(color: fast.t1),
                      decoration: InputDecoration(
                        hintText: tr(context, 'assistant_hint'),
                        hintStyle: FASTText.body.copyWith(color: fast.t3),
                        filled: true,
                        fillColor: fast.cardHigh,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: FASTSpace.s16,
                          vertical: 14,
                        ),
                        border: inputBorder(fast.line),
                        enabledBorder: inputBorder(fast.line),
                        focusedBorder: inputBorder(fast.ink, 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: FASTSpace.s8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fast.ink,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _send,
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          color: fast.onInk,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
