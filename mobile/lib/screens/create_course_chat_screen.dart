import "package:flutter/material.dart";

import "../api/api_client.dart";

class CreateCourseChatScreen extends StatefulWidget {
  const CreateCourseChatScreen({super.key});

  @override
  State<CreateCourseChatScreen> createState() => _CreateCourseChatScreenState();
}

class _CreateCourseChatScreenState extends State<CreateCourseChatScreen> {
  final _api = ApiClient();
  final _text = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _sendUserMessage() {
    final content = _text.text.trim();
    if (content.isEmpty) return;
    setState(() {
      _messages.add({"role": "user", "content": content});
      _text.clear();
      _error = null;
    });
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.generateCourse(messages: _messages);
      if (!mounted) return;
      Navigator.of(context).pop((course: result.course, modules: result.modules));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create course (chat)")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m["content"] ?? ""),
                  ),
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    decoration: const InputDecoration(hintText: "Say what you want to learn..."),
                    onSubmitted: (_) => _sendUserMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _loading ? null : _sendUserMessage, icon: const Icon(Icons.send)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: FilledButton(
              onPressed: (_loading || _messages.isEmpty) ? null : _generate,
              child: Text(_loading ? "Generating..." : "Generate course"),
            ),
          ),
        ],
      ),
    );
  }
}

