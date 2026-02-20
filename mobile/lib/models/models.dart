class AppUser {
  final String id;
  final String name;

  AppUser({required this.id, required this.name});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json["id"] as String,
      name: json["name"] as String,
    );
  }
}

class Course {
  final String id;
  final String ownerId;
  final String name;

  Course({required this.id, required this.ownerId, required this.name});

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json["id"] as String,
      ownerId: json["ownerId"] as String,
      name: json["name"] as String,
    );
  }
}

class CourseModule {
  final String id;
  final String courseId;
  final String type; // "info" | "test"
  final Map<String, dynamic> content;

  CourseModule({
    required this.id,
    required this.courseId,
    required this.type,
    required this.content,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    return CourseModule(
      id: json["id"] as String,
      courseId: json["courseId"] as String,
      type: json["type"] as String,
      content: (json["content"] as Map).cast<String, dynamic>(),
    );
  }
}

