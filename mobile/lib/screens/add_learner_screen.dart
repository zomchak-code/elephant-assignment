import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../models/models.dart";

class AddLearnerScreen extends StatefulWidget {
  final String courseId;
  const AddLearnerScreen({super.key, required this.courseId});

  @override
  State<AddLearnerScreen> createState() => _AddLearnerScreenState();
}

class _AddLearnerScreenState extends State<AddLearnerScreen> {
  final _api = ApiClient();
  late Future<List<AppUser>> _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _users = _api.listUsers();
  }

  Future<void> _add(AppUser user) async {
    setState(() => _error = null);
    try {
      await _api.addLearner(courseId: widget.courseId, userId: user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Learner added")));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add learner")),
      body: FutureBuilder(
        future: _users,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!;
          return Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return ListTile(
                      title: Text(u.name),
                      subtitle: Text(u.id),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _add(u),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

