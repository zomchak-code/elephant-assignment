import "package:flutter/material.dart";
import "package:flutter_markdown/flutter_markdown.dart";

import "../models/models.dart";

class ModuleViewScreen extends StatefulWidget {
  final CourseModule module;
  const ModuleViewScreen({super.key, required this.module});

  @override
  State<ModuleViewScreen> createState() => _ModuleViewScreenState();
}

class _ModuleViewScreenState extends State<ModuleViewScreen> {
  int? _selected;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    return Scaffold(
      appBar: AppBar(title: Text(m.type == "info" ? "Info" : "Test")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: m.type == "info" ? _info(m) : _test(m),
      ),
    );
  }

  Widget _info(CourseModule m) {
    final md = (m.content["markdown"] as String?) ?? "";
    return Markdown(data: md);
  }

  Widget _test(CourseModule m) {
    final question = (m.content["question"] as String?) ?? "";
    final options = (m.content["options"] as List?)?.cast<String>() ?? const <String>[];
    final correctIndex = (m.content["correctIndex"] as num?)?.toInt() ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < options.length; i++)
          RadioListTile<int>(
            value: i,
            // ignore: deprecated_member_use
            groupValue: _selected,
            title: Text(options[i]),
            // ignore: deprecated_member_use
            onChanged: _submitted ? null : (v) => setState(() => _selected = v),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: (_submitted || _selected == null)
              ? null
              : () {
                  final ok = _selected == correctIndex;
                  setState(() => _submitted = true);
                  showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(ok ? "Correct" : "Incorrect"),
                      content: Text(ok ? "Nice job." : "Try again next time."),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("OK")),
                      ],
                    ),
                  );
                },
          child: const Text("Submit"),
        ),
      ],
    );
  }
}

