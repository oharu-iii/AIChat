import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => runApp(const ProviderScope(child: MyApp()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      home: ChatPage(),
    );
  }
}

class ChatMessage {
  final String message;
  final bool isUser;

  ChatMessage({required this.message, required this.isUser});
}

// Riverpod 用の履歴状態
final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) => ChatNotifier());

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([]);

  void addUserMessage(String msg) {
    state = [...state, ChatMessage(message: msg, isUser: true)];
  }

  void addBotMessage(String msg) {
    state = [...state, ChatMessage(message: msg, isUser: false)];
  }
}

class ChatPage extends ConsumerWidget {
  ChatPage({super.key});
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '雑談AI Bot デモ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, idx) {
                  final msg = messages[idx];
                  return ListTile(
                    title: Align(
                      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: msg.isUser ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg.message),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: '話しかけてみよう'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      ref.read(chatProvider.notifier).addUserMessage(text);
                      _controller.clear();

                      // ここでAIにAPI投げて返事をもらう
                      final response = await fetchBotResponse(text, messages);
                      ref.read(chatProvider.notifier).addBotMessage(response ?? '…');
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      )
    );
  }

  // TODO:後で本物のAPIを組む
  Future<String?> fetchBotResponse(String userMessage, List<ChatMessage> history) async {
    // モック返事
    await Future.delayed(const Duration(seconds: 1));
    // 最初はモック値で
    return '（雑談風に）すごいですね！ それで、どうなったんですか？';
    // 本番はAPIを後で実装
  }
}