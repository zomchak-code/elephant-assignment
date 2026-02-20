import "dart:convert";

import "package:http/http.dart" as http;
import "package:supabase_flutter/supabase_flutter.dart";

import "../config.dart";
import "../models/models.dart";

class ApiClient {
  ApiClient();

  Uri _u(String path) => Uri.parse("${AppConfig.backendBaseUrl}$path");

  String _token() {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError("Not authenticated");
    }
    return token;
  }

  Map<String, String> _headers() {
    return {
      "content-type": "application/json",
      "authorization": "Bearer ${_token()}",
    };
  }

  Future<AppUser> me() async {
    final res = await http.get(_u("/me"), headers: _headers());
    if (res.statusCode != 200) throw StateError("Failed /me: ${res.statusCode}");
    return AppUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<AppUser>> listUsers() async {
    final res = await http.get(_u("/users"), headers: _headers());
    if (res.statusCode != 200) throw StateError("Failed /users: ${res.statusCode}");
    final arr = jsonDecode(res.body) as List<dynamic>;
    return arr.map((j) => AppUser.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Course>> ownedCourses() async {
    final res = await http.get(_u("/courses/owned"), headers: _headers());
    if (res.statusCode != 200) throw StateError("Failed /courses/owned: ${res.statusCode}");
    final arr = jsonDecode(res.body) as List<dynamic>;
    return arr.map((j) => Course.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Course>> enrolledCourses() async {
    final res = await http.get(_u("/courses/enrolled"), headers: _headers());
    if (res.statusCode != 200) throw StateError("Failed /courses/enrolled: ${res.statusCode}");
    final arr = jsonDecode(res.body) as List<dynamic>;
    return arr.map((j) => Course.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<({Course course, List<CourseModule> modules})> generateCourse({
    required List<Map<String, String>> messages,
  }) async {
    final res = await http.post(
      _u("/courses/generate"),
      headers: _headers(),
      body: jsonEncode({"messages": messages}),
    );
    if (res.statusCode != 201) throw StateError("Failed /courses/generate: ${res.statusCode}");
    final obj = jsonDecode(res.body) as Map<String, dynamic>;
    final course = Course.fromJson(obj["course"] as Map<String, dynamic>);
    final mods = (obj["modules"] as List<dynamic>)
        .map((j) => CourseModule.fromJson(j as Map<String, dynamic>))
        .toList();
    return (course: course, modules: mods);
  }

  Future<List<CourseModule>> courseModules(String courseId) async {
    final res = await http.get(_u("/courses/$courseId/modules"), headers: _headers());
    if (res.statusCode != 200) throw StateError("Failed /courses/:id/modules: ${res.statusCode}");
    final arr = jsonDecode(res.body) as List<dynamic>;
    return arr.map((j) => CourseModule.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> addLearner({required String courseId, required String userId}) async {
    final res = await http.post(
      _u("/courses/$courseId/learners"),
      headers: _headers(),
      body: jsonEncode({"userId": userId}),
    );
    if (res.statusCode != 201) throw StateError("Failed add learner: ${res.statusCode}");
  }
}

