import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../models/models.dart";
import "add_learner_screen.dart";
import "module_view_screen.dart";

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  final bool isOwner;
  final List<CourseModule>? initialModules;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.isOwner,
    this.initialModules,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _api = ApiClient();
  late Future<List<CourseModule>> _modules;

  @override
  void initState() {
    super.initState();
    _modules = widget.initialModules != null ? Future.value(widget.initialModules!) : _api.courseModules(widget.course.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        actions: [
          if (widget.isOwner)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddLearnerScreen(courseId: widget.course.id),
                  ),
                );
              },
            )
        ],
      ),
      body: FutureBuilder(
        future: _modules,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final modules = snapshot.data!;
          return ListView.builder(
            itemCount: modules.length,
            itemBuilder: (context, i) {
              final m = modules[i];
              return ListTile(
                title: Text(m.type == "info" ? "Info" : "Test"),
                subtitle: Text(m.type == "info" ? (m.content["markdown"] ?? "") : (m.content["question"] ?? "")),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ModuleViewScreen(module: m)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

