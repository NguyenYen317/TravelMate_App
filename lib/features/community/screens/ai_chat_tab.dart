import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/ai_provider.dart';
import '../../ai/models/ai_chat_models.dart';

class AIChatTab extends StatefulWidget {
  const AIChatTab({super.key, this.autofocusInput = false});

  final bool autofocusInput;

  @override
  State<AIChatTab> createState() => _AIChatTabState();
}

class _AIChatTabState extends State<AIChatTab> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  int _lastMessageCount = 0;
  bool _lastLoadingState = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.autofocusInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _inputFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AIProvider>(
      builder: (context, aiProvider, _) {
        final messages = aiProvider.chatMessages;

        if (_lastMessageCount != messages.length ||
            _lastLoadingState != aiProvider.isChatLoading) {
          _lastMessageCount = messages.length;
          _lastLoadingState = aiProvider.isChatLoading;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: messages.length + (aiProvider.isChatLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= messages.length) {
                    return const _TypingBubble();
                  }
                  return _ChatBubble(message: messages[index]);
                },
              ),
            ),
            if (messages.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Ban co the hoi ve lich trinh, dia diem, an uong, di chuyen...',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (aiProvider.chatError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  aiProvider.chatError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        autofocus: widget.autofocusInput,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _onSend(aiProvider),
                        decoration: InputDecoration(
                          hintText: 'Nhap cau hoi...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: aiProvider.isChatLoading
                          ? null
                          : () => _onSend(aiProvider),
                      icon: const Icon(Icons.send),
                    ),
                    if (messages.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Xoa chat',
                        onPressed: aiProvider.isChatLoading
                            ? null
                            : aiProvider.clearChat,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onSend(AIProvider aiProvider) async {
    final text = _inputController.text.trim();
    if (text.isEmpty || aiProvider.isChatLoading) {
      return;
    }

    _inputController.clear();
    await aiProvider.sendChatMessage(text);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AIChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AIChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? colorScheme.primary : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isUser ? 14 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 14),
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
