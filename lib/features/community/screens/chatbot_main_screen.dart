import 'package:flutter/material.dart';

import 'ai_chat_tab.dart';

class ChatbotMainScreen extends StatelessWidget {
  const ChatbotMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Bot')),
      body: const AIChatTab(),
    );
  }
}
