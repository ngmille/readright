import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class ClassroomStudent {
  final String id;
  final String email;
  final String displayName;
  final bool retainAudio;
  final int retentionDays;

  const ClassroomStudent({
    required this.id,
    required this.email,
    required this.displayName,
    this.retainAudio = false,
    this.retentionDays = 30,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'retainAudio': retainAudio,
        'retentionDays': retentionDays,
      };

  factory ClassroomStudent.fromMap(Map<String, dynamic> data) {
    return ClassroomStudent(
      id: data['id'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Student',
      retainAudio: data['retainAudio'] as bool? ?? false,
      retentionDays: data['retentionDays'] as int? ?? 30,
    );
  }

  ClassroomStudent copyWith({
    String? id,
    String? email,
    String? displayName,
    bool? retainAudio,
    int? retentionDays,
  }) {
    return ClassroomStudent(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      retainAudio: retainAudio ?? this.retainAudio,
      retentionDays: retentionDays ?? this.retentionDays,
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
            retainAudio: doc.data()['retainAudio'] as bool? ?? false,
            retentionDays: doc.data()['retentionDays'] as int? ?? 30,
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


  Future<void> saveClassroomStudents(String teacherId, List<ClassroomStudent> students) async {
    final batch = _firestore.batch();
    final teacherRef = _firestore.collection('teachers').doc(teacherId);

    for (final student in students) {
      final docRef = teacherRef.collection('students').doc(student.id);
      batch.set(docRef, student.toMap(), SetOptions(merge: true));
    }

    await batch.commit();
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

  Future<void> toggleAudioRetention(String studentId, {int? newRetentionDays}) async {
    final student = _assignedStudents.firstWhereOrNull((s) => s.id == studentId);
    if (student == null) return;

    _updating = true;
    notifyListeners();

    try {
      final bool newRetainAudio = newRetentionDays != null ? true : !student.retainAudio;
      final int newDays = newRetentionDays ?? student.retentionDays;

      final updatedStudent = student.copyWith(
        retainAudio: newRetainAudio,
        retentionDays: newDays,
      );

      // Update local state
      _assignedStudents = _assignedStudents.map((s) => s.id == studentId ? updatedStudent : s).toList();
      if (_selectedStudent?.id == studentId) {
        _selectedStudent = updatedStudent;
      }

      // Save to firebase
      await _repository?.saveClassroomStudents(_teacherId!, _assignedStudents);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .set({
        'retainAudio': newRetainAudio,
        'retentionDays': newDays,
      }, SetOptions(merge: true));

      if (!newRetainAudio) {
        unawaited(_cleanupOldAudio(studentId));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update audio retention: $e');
      _error = 'Failed to update settings';
      notifyListeners();
    } finally {
      _updating = false;
    }
}

  Future<void> _cleanupOldAudio(String studentId) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7)); // grace period
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .collection('attempts')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final audioUrl = data['audioUrl'] as String?;
        if (audioUrl != null && audioUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(audioUrl).delete();
          } catch (_) {}
        }
        batch.update(doc.reference, {'audioUrl': FieldValue.delete()});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Audio cleanup failed: $e');
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
      if (include) { // add student
        _assignedStudents = [..._assignedStudents, student];
        _selectedStudent = student;

      } else { // remove student
        _assignedStudents = _assignedStudents.where((s) => s.id != student.id).toList();
        
        // Only deselect if they were the currently selected one
        if (_selectedStudent?.id == student.id) {
          _selectedStudent = null;
        }
      }

      await repo.saveClassroomStudents(teacherId, _assignedStudents);
      _error = null;
    } catch (error) {
      _error = 'Unable to update classroom';
      // Rollback on error
      if (include) {
        _assignedStudents.removeWhere((s) => s.id == student.id);
        if (_selectedStudent?.id == student.id) _selectedStudent = null;
      } else {
        _assignedStudents = [..._assignedStudents, student];
      }
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

  void updateStudentLocally(ClassroomStudent updatedStudent) {
    _assignedStudents = _assignedStudents
        .map((s) => s.id == updatedStudent.id ? updatedStudent : s)
        .toList();
    notifyListeners();
  }

  Future<void> saveClassroom() async {
    if (_teacherId == null || _repository == null) return;
    _updating = true;
    notifyListeners();
    try {
      await _repository.saveClassroomStudents(_teacherId!, _assignedStudents);
    } catch (e) {
      _error = 'Failed to save classroom';
    } finally {
      _updating = false;
      notifyListeners();
    }
  }
}

extension FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}