import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarGridWidget extends StatelessWidget {
  final DateTime displayedMonth;
  final DateTime selectedDate;
  final Map<String, int> studyCounts;
  final Function(DateTime) onDateSelected;
  final Function(String) onDateTapped;

  const CalendarGridWidget({
    super.key,
    required this.displayedMonth,
    required this.selectedDate,
    required this.studyCounts,
    required this.onDateSelected,
    required this.onDateTapped,
  });

  double _getIntensity(int count) => (count / 5).clamp(0.0, 1.0);

  Color _getDateBackgroundColor(int count) {
    if (count == 0) return Colors.transparent;
    final intensity = _getIntensity(count);
    return Color.lerp(
      const Color(0xFF6366F1).withOpacity(0.2),
      const Color(0xFF6366F1),
      intensity,
    ) ?? Colors.transparent;
  }

  Color _getDayTextColor(bool isSelected, bool isToday, int count, Color backgroundColor) {
    if (isSelected) {
      if (count == 0 || backgroundColor == Colors.transparent) {
        return Colors.grey.shade700;
      }
      return Colors.white;
    }
    if (count == 0 || backgroundColor == Colors.transparent) {
      return Colors.grey.shade700;
    }

    final luminance = backgroundColor.computeLuminance();
    if (luminance < 0.2) {
      return Colors.white.withOpacity(0.95);
    } else if (luminance < 0.4) {
      return Colors.white.withOpacity(0.85);
    } else if (luminance < 0.6) {
      return Colors.white.withOpacity(0.75);
    } else {
      return const Color(0xFF1F1F39);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  bool _isSelected(DateTime date) {
    return date.year == selectedDate.year &&
           date.month == selectedDate.month &&
           date.day == selectedDate.day;
  }

  Widget _buildDateCell(DateTime date, String dateStr) {
    final isToday = _isToday(date);
    final isSelected = _isSelected(date);
    final count = studyCounts[dateStr] ?? 0;
    final backgroundColor = _getDateBackgroundColor(count);
    final dayColor = _getDayTextColor(isSelected, isToday, count, backgroundColor);
    // 공부 횟수 숫자도 날짜와 같은 색상 로직 사용
    final countColor = dayColor;

    // 테두리 색상 결정
    Color? borderColor;
    double? borderWidth;
    if (isSelected) {
      borderColor = const Color(0xFF6366F1); // 푸른색 테두리
      borderWidth = 2.0;
    } else if (isToday) {
      borderColor = Colors.red; // 붉은색 테두리
      borderWidth = 2.0;
    }

    return GestureDetector(
      onTap: () {
        onDateSelected(date);
        onDateTapped(dateStr);
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor, // 공부 횟수에 따른 배경색
          borderRadius: BorderRadius.circular(8),
          border: borderColor != null
              ? Border.all(color: borderColor, width: borderWidth!)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                color: dayColor,
              ),
            ),
            if (count > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  color: countColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final lastDayOfMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    final daysInMonth = lastDayOfMonth.day;

    // 주 시작을 월요일로 (firstWeekday가 1이면 월요일)
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday - 1;

    return Column(
      children: [
        // 요일 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['월', '화', '수', '목', '금', '토', '일'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // 달력 그리드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              // 첫 주 (빈 칸 + 날짜)
              Row(
                children: List.generate(7, (index) {
                  if (index < startOffset) {
                    return const Expanded(child: SizedBox());
                  }
                  final day = index - startOffset + 1;
                  final date = DateTime(displayedMonth.year, displayedMonth.month, day);
                  final dateStr = DateFormat('yyyy-MM-dd').format(date);
                  
                  return Expanded(
                    child: _buildDateCell(date, dateStr),
                  );
                }),
              ),
              // 나머지 주들
              ...List.generate((daysInMonth - (7 - startOffset) + 6) ~/ 7, (weekIndex) {
                return Row(
                  children: List.generate(7, (dayIndex) {
                    final day = (weekIndex * 7) + dayIndex + (7 - startOffset) + 1;
                    if (day > daysInMonth) {
                      return const Expanded(child: SizedBox());
                    }
                    final date = DateTime(displayedMonth.year, displayedMonth.month, day);
                    final dateStr = DateFormat('yyyy-MM-dd').format(date);
                    
                    return Expanded(
                      child: _buildDateCell(date, dateStr),
                    );
                  }),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

