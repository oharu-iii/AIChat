import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<void> main() async {
  await dotenv.load();
  runApp(const ProviderScope(child: MyApp()));
}

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

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  String summaryText = "";

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // WidgetsBindingで確実に反映
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatHistory = ref.watch(chatProvider);

    // メッセージ追加時にスクロール（messagesが更新されるたび）
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

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
                controller: _scrollController,
                itemCount: chatHistory.length,
                itemBuilder: (context, idx) {
                  final msg = chatHistory[idx];
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
                      controller: _textController,
                      decoration: const InputDecoration(hintText: '話しかけてみよう'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final userMessage = _textController.text.trim();
                      if (userMessage.isEmpty) return;
                      ref.read(chatProvider.notifier).addUserMessage(userMessage);
                      _textController.clear();

                      // 5回おきにサマリーアップデート
                      if (chatHistory.length % 5 == 0 && chatHistory.isNotEmpty) {
                        summaryText = await updateSummary(chatHistory);
                      }

                      // Bot返事
                      final aiResponse = await fetchBotResponse(userMessage, chatHistory, summaryText);
                      // final response = await fetchBotResponse(userMessage, chatHistory);
                      ref.read(chatProvider.notifier).addBotMessage(aiResponse ?? '…');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// OpenAI APIを使ってAIの返答を取得する関数
  Future<String?> fetchBotResponse(String userMessage, List<ChatMessage> history, String summaryText) async {

    print("FetchBotResponse\n");

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    const endpoint = 'https://api.openai.com/v1/chat/completions';

    // --- プロンプト＆履歴作成 ---
    List<Map<String, String>> messages = [
      {
        "role": "system",
        "content":
            "あなたは聞き上手な友達AIです。相槌や質問を適度に交えながら、自然な雑談をしてください。また、過去の重要事項のまとめが下記にあります。これも参考にしつつ雑談してください。\n\n【ユーザーの重要情報】\n$summaryText\n\n---\n\n【会話履歴 (あなたは role:assistant です)】\n"
      }
    ];

    // 直近10ターンだけhistoryから追加
    final historyTail = history.length > 10 ? history.sublist(history.length - 10) : history;
    for (var msg in historyTail) {
      messages.add({
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.message,
      });
    }

    // 今回のユーザー発話
    messages.add({
      "role": "user",
      "content": userMessage,
    });

    print("Messages: $messages");

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": messages,
        "max_tokens": 1000,
        "temperature": 0.8,
        "top_p": 1.0,
      }),
    );

    // ステータスチェック
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      print("AI Response: ${data['choices'][0]['message']['content']}");
      return data['choices'][0]['message']['content'];
    } else {
      print("API Error: ${response.statusCode}, ${utf8.decode(response.bodyBytes)}");
      return "（エラー: AI返答を取得できませんでした）";
    }
  }
  
  Future<String> updateSummary(List<ChatMessage> allHistory) async {

    print("UpdateSummary\n");

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    const endpoint = 'https://api.openai.com/v1/chat/completions';

    // 1. 過去全ての会話履歴を "user"/"assistant" で投げる
    final summaryPrompt = [
      {
        "role": "system",
        "content": "次の会話ログから、ユーザーが大事そうに話した内容・よく出る趣味・自己紹介・特徴・好きな話題などを日本語で要約してください。\n---\n【会話履歴】\n\n"
      }
    ];

    for (var msg in allHistory) {
      summaryPrompt.add({
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.message,
      });
    }

    print("SummaryPrompt: $summaryPrompt");

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": summaryPrompt,
        "max_tokens": 1000,
        "temperature": 0.3,
        "top_p": 1.0,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      print("Summary API response: ${data['choices'][0]['message']['content']}");
      return data['choices'][0]['message']['content'].trim();
    } else {
      print("Summary API error: ${response.statusCode}, ${response.body}");
      return "";
    }
  }
}