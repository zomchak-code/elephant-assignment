import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../api/api_client.dart";
import "../models/models.dart";
import "create_course_chat_screen.dart";
import "course_detail_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();

  late Future<({AppUser me, List<Course> owned, List<Course> enrolled})> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<({AppUser me, List<Course> owned, List<Course> enrolled})> _load() async {
    final me = await _api.me();
    final owned = await _api.ownedCourses();
    final enrolled = await _api.enrolledCourses();
    return (me: me, owned: owned, enrolled: enrolled);
  }

  void _openCourse(Course course, {required String myUserId}) {
    final isOwner = course.ownerId == myUserId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailScreen(course: course, isOwner: isOwner),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Courses"),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<({Course course, List<CourseModule> modules})>(
            MaterialPageRoute(builder: (_) => const CreateCourseChatScreen()),
          );
          if (!context.mounted) return;
          if (created == null) return;
          setState(() => _data = _load());
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: created.course, isOwner: true, initialModules: created.modules),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final me = snapshot.data!.me;
          final owned = snapshot.data!.owned;
          final enrolled = snapshot.data!.enrolled;

          return RefreshIndicator(
            onRefresh: () async => setState(() => _data = _load()),
            child: ListView(
              children: [
                ListTile(title: Text("Signed in as ${me.name}")),
                const Divider(),
                const ListTile(title: Text("Owned")),
                for (final c in owned)
                  ListTile(
                    title: Text(c.name),
                    onTap: () => _openCourse(c, myUserId: me.id),
                  ),
                const Divider(),
                const ListTile(title: Text("Enrolled")),
                for (final c in enrolled)
                  ListTile(
                    title: Text(c.name),
                    onTap: () => _openCourse(c, myUserId: me.id),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

