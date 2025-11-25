import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class ClassroomStudent {
  final String id;
  final String email;
  final String displayName;

  const ClassroomStudent({
    required this.id,
    required this.email,
    required this.displayName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'displayName': displayName,
      };

  factory ClassroomStudent.fromMap(Map<String, dynamic> data) {
    return ClassroomStudent(
      id: data['id'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Student',
    );
  }
}

class ClassroomRepository {
  final FirebaseFirestore _firestore;

  ClassroomRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  DocumentReference<Map<String, dynamic>> _classroomDoc(String teacherId) =>
      _firestore.collection('classrooms').doc(teacherId);

  Future<List<ClassroomStudent>> fetchAllStudents() async {
    final snapshot =
        await _users.where('role', isEqualTo: 'student').get();
    final students = snapshot.docs
        .map(
          (doc) => ClassroomStudent(
            id: doc.id,
            email: doc.data()['email'] as String? ?? '',
            displayName: doc.data()['displayName'] as String? ??
                (doc.data()['username'] as String? ?? 'Student'),
          ),
        )
        .toList(growable: false);
    students.sort((a, b) => a.displayName.compareTo(b.displayName));
    return students;
  }

  Future<List<ClassroomStudent>> fetchClassroomStudents(String teacherId) async {
    final snapshot = await _classroomDoc(teacherId).get();
    final data = snapshot.data();
    if (data == null) return const [];
    final raw = data['students'] as List<dynamic>? ?? const [];
    return raw
        .map((entry) => ClassroomStudent.fromMap(
              Map<String, dynamic>.from(entry as Map),
            ))
        .toList(growable: false);
  }

  Future<void> saveClassroomStudents(
    String teacherId,
    List<ClassroomStudent> students,
  ) async {
    await _classroomDoc(teacherId).set({
      'teacherId': teacherId,
      'students': students.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class ClassroomController extends ChangeNotifier {
  final ClassroomRepository? _repository;
  String? _teacherId;
  bool _loading = false;
  bool _updating = false;
  String? _error;
  List<ClassroomStudent> _allStudents = const <ClassroomStudent>[];
  List<ClassroomStudent> _assignedStudents = const <ClassroomStudent>[];
  ClassroomStudent? _selectedStudent;

  ClassroomController({required ClassroomRepository? repository})
      : _repository = repository;

  bool get isLoading => _loading;
  bool get isUpdating => _updating;
  String? get errorMessage => _error;
  List<ClassroomStudent> get allStudents => List.unmodifiable(_allStudents);
  List<ClassroomStudent> get assignedStudents =>
      List.unmodifiable(_assignedStudents);
  ClassroomStudent? get selectedStudent => _selectedStudent;

  void updateForUser(AuthUser? user) {
    if (user == null || user.role != UserRole.teacher) {
      _teacherId = null;
      _selectedStudent = null;
      _assignedStudents = const <ClassroomStudent>[];
      _allStudents = const <ClassroomStudent>[];
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }

    if (_teacherId == user.id && _assignedStudents.isNotEmpty) {
      return;
    }

    _teacherId = user.id;
    _refreshData();
  }

  Future<void> refreshAvailableStudents() async {
    final repo = _repository;
    if (_teacherId == null || repo == null) return;
    try {
      _allStudents = await repo.fetchAllStudents();
      notifyListeners();
    } catch (error) {
      _error = 'Unable to load students';
      notifyListeners();
    }
  }

  Future<void> toggleStudent(ClassroomStudent student, bool include) async {
    final repo = _repository;
    final teacherId = _teacherId;
    if (teacherId == null || repo == null) return;
    final exists = _assignedStudents.any((s) => s.id == student.id);
    if (include && exists) return;
    if (!include && !exists) return;

    _updating = true;
    notifyListeners();
    try {
      if (include) {
        _assignedStudents = [..._assignedStudents, student];
      } else {
        _assignedStudents =
            _assignedStudents.where((s) => s.id != student.id).toList();
        if (_selectedStudent?.id == student.id) {
          _selectedStudent = null;
        }
      }
      await repo.saveClassroomStudents(teacherId, _assignedStudents);
      _error = null;
    } catch (error) {
      _error = 'Unable to update classroom';
    } finally {
      _updating = false;
      notifyListeners();
    }
  }

  void selectStudent(ClassroomStudent student) {
    _selectedStudent = student;
    notifyListeners();
  }

  Future<void> _refreshData() async {
    final repo = _repository;
    final teacherId = _teacherId;
    if (teacherId == null || repo == null) return;
    _loading = true;
    notifyListeners();
    try {
      final all = await repo.fetchAllStudents();
      final assigned = await repo.fetchClassroomStudents(teacherId);
      _allStudents = all;
      _assignedStudents = assigned;
      if (_assignedStudents.isNotEmpty &&
          _selectedStudent == null) {
        _selectedStudent = _assignedStudents.first;
      }
      _error = null;
    } catch (error) {
      _error = 'Unable to load classroom';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
