import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'calendar_grid_widget.dart';
import 'study_session_dialog.dart';

class StudyCalendarWidget extends StatefulWidget {
  final int refreshTrigger;

  const StudyCalendarWidget({
    super.key,
    required this.refreshTrigger,
  });

  @override
  State<StudyCalendarWidget> createState() => _StudyCalendarWidgetState();
}

class _StudyCalendarWidgetState extends State<StudyCalendarWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, int> _studyCounts = {}; // 날짜별 공부 횟수
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudyHistory();
  }

  @override
  void didUpdateWidget(covariant StudyCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _loadStudyHistory();
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    });
  }

  Future<void> _loadStudyHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && userDoc.exists) {
        final userData = userDoc.data() ?? {};
        final studyHistory = userData['studyHistory'] as Map<String, dynamic>? ?? {};

        // 날짜별 공부 횟수 계산
        final counts = <String, int>{};
        studyHistory.forEach((date, data) {
          if (data is Map<String, dynamic>) {
            final sessions = data['sessions'] as List<dynamic>? ?? [];
            counts[date] = sessions.length;
          }
        });

        if (mounted) {
          setState(() {
            _studyCounts = counts;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('공부 기록 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        // 월/년 표시
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: const Color(0xFF6366F1),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                DateFormat('yyyy년 M월').format(_displayedMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6366F1),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: const Color(0xFF6366F1),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        // 달력 그리드
        CalendarGridWidget(
          displayedMonth: _displayedMonth,
          selectedDate: _selectedDate,
          studyCounts: _studyCounts,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
          onDateTapped: (dateStr) {
            _showDateSessions(dateStr);
          },
        ),
      ],
    );
  }

  Future<void> _showDateSessions(String date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted || !userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final studyHistory = userData['studyHistory'] as Map<String, dynamic>? ?? {};
      final dateData = studyHistory[date] as Map<String, dynamic>?;
      final sessions = (dateData?['sessions'] as List<dynamic>?) ?? [];

      if (!mounted) return;

      final formattedDate = DateFormat('yyyy년 M월 d일').format(DateTime.parse(date));
      final sessionList = sessions.map((s) => Map<String, dynamic>.from(s as Map<String, dynamic>)).toList();

      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder: (context) => StudySessionsDialog(
          formattedDate: formattedDate,
          sessions: sessionList,
          onSessionSelected: (session) {
            Navigator.of(context).pop();
            final time = session['time'] as String? ?? '';
            final words = (session['words'] as List<dynamic>?) ?? [];
            _showSessionWords(date, time, words);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('세션 로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _showSessionWords(String date, String time, List<dynamic> words) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted || !userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final flashcards = (userData['flashcards'] as List<dynamic>?) ?? [];

      // 단어 목록 가져오기
      final wordList = <Map<String, dynamic>>[];
      for (final wordStr in words) {
        for (final flashcard in flashcards) {
          final card = flashcard as Map<String, dynamic>;
          if (card['word'] == wordStr) {
            wordList.add(card);
            break;
          }
        }
      }

      if (!mounted) return;

      final dialogTitle = '$date $time';
      final wordMapList = wordList.map((w) => Map<String, dynamic>.from(w)).toList();

      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder: (context) => StudySessionWordsDialog(
          title: dialogTitle,
          wordList: wordMapList,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 로드 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildCalendar(),
    );
  }
}

