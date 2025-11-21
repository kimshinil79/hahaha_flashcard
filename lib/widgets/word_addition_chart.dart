import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WordAdditionChart extends StatefulWidget {
  const WordAdditionChart({super.key});

  @override
  State<WordAdditionChart> createState() => _WordAdditionChartState();
}

class _WordAdditionChartState extends State<WordAdditionChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, int> _wordAdditionCounts = {};
  bool _isLoading = true;
  int _selectedDays = 7; // 기본 7일

  @override
  void initState() {
    super.initState();
    _loadWordAdditionData();
  }

  Future<void> _loadWordAdditionData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userData = userDoc.data();
      final flashcards = userData?['flashcards'] as List<dynamic>? ?? [];

      // 날짜별 단어 추가 카운트
      final Map<String, int> dateCounts = {};
      
      // 최근 N일 날짜 초기화
      final now = DateTime.now();
      for (int i = 0; i < _selectedDays; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        dateCounts[dateStr] = 0;
      }

      // flashcards에서 createdAt 기반으로 카운트
      for (var flashcard in flashcards) {
        final createdAt = flashcard['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final createdDate = createdAt.toDate();
          final dateStr = DateFormat('yyyy-MM-dd').format(createdDate);
          
          // 최근 N일 이내인 경우만 카운트
          if (dateCounts.containsKey(dateStr)) {
            dateCounts[dateStr] = (dateCounts[dateStr] ?? 0) + 1;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _wordAdditionCounts = dateCounts;
        _isLoading = false;
      });
    } catch (e) {
      print('단어 추가 데이터 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<FlSpot> _getChartData() {
    if (_wordAdditionCounts.isEmpty) return [];

    // 날짜 정렬 (오래된 날짜부터)
    final sortedDates = _wordAdditionCounts.keys.toList()
      ..sort();

    // 누적 합계 계산
    int cumulativeSum = 0;
    final List<FlSpot> spots = [];
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final dailyCount = _wordAdditionCounts[date] ?? 0;
      cumulativeSum += dailyCount;
      spots.add(FlSpot(i.toDouble(), cumulativeSum.toDouble()));
    }

    return spots;
  }

  String _getBottomTitle(double value) {
    final sortedDates = _wordAdditionCounts.keys.toList()..sort();
    final index = value.toInt();
    
    if (index < 0 || index >= sortedDates.length) return '';
    
    final date = DateTime.parse(sortedDates[index]);
    
    // 7일 이하면 요일, 그 이상이면 날짜만
    if (_selectedDays <= 7) {
      final weekday = ['일', '월', '화', '수', '목', '금', '토'][date.weekday % 7];
      return weekday;
    } else {
      return '${date.month}/${date.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final chartData = _getChartData();
    // 누적 합계의 최대값 계산
    final maxY = chartData.isEmpty
        ? 10.0
        : (chartData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '단어 추가 추이 (누적)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Row(
                  children: [
                    _buildDaysButton(7),
                    const SizedBox(width: 8),
                    _buildDaysButton(14),
                    const SizedBox(width: 8),
                    _buildDaysButton(30),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: chartData.isEmpty
                  ? const Center(
                      child: Text(
                        '아직 추가된 단어가 없습니다',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 5,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              interval: maxY / 5,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.max || value == meta.min) {
                                  return const SizedBox();
                                }
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _getBottomTitle(value),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (chartData.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: chartData,
                            isCurved: true,
                            color: const Color(0xFFFB923C), // 오렌지 색상
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: const Color(0xFFFB923C), // 오렌지 색상
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFFFB923C).withOpacity(0.15), // 오렌지 배경
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.white,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final sortedDates = _wordAdditionCounts.keys.toList()..sort();
                                final date = DateTime.parse(sortedDates[spot.x.toInt()]);
                                final dateStr = DateFormat('M/d').format(date);
                                return LineTooltipItem(
                                  '$dateStr\n${spot.y.toInt()}개',
                                  const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysButton(int days) {
    final isSelected = _selectedDays == days;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDays = days;
        });
        _loadWordAdditionData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFB923C) : Colors.grey.shade100, // 오렌지 색상
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${days}일',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

