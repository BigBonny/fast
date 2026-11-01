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
  const AssistantScreen({super.key});

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
    _messages.add(_Msg(tr(context, 'assistant_greeting'), false));
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
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: context.fast.bg,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.bolt, color: Color(0xFF1A1425), size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              tr(context, 'assistant_title'),
              style: TextStyle(
                color: context.fast.t1,
                fontWeight: FontWeight.w900,
                fontSize: 16,
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
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.fast.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final m = _messages[i];
                return Align(
                  alignment: m.mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      gradient: m.mine
                          ? const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            )
                          : null,
                      color: m.mine ? null : context.fast.card,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(m.mine ? 14 : 4),
                        bottomRight: Radius.circular(m.mine ? 4 : 14),
                      ),
                      border: m.mine
                          ? null
                          : Border.all(color: context.fast.line),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: m.mine
                            ? const Color(0xFF1A1425)
                            : context.fast.t1,
                        fontSize: 13,
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: context.fast.t1, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: tr(context, 'assistant_hint'),
                        hintStyle: TextStyle(color: context.fast.t3),
                        filled: true,
                        fillColor: context.fast.card,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.fast.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.fast.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFF1A1425),
                        size: 20,
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
