import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarWidget extends StatefulWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final Map<DateTime, int> entryCountsByDay;
  final Function(DateTime?) onDateSelected;
  final Function(DateTime) onMonthChanged;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final bool isRecording;
  final List<int> availableYears;

  const CalendarWidget({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.entryCountsByDay,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.isRecording,
    required this.availableYears,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  String _formatMonthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Color? _getMarkerColor(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final count = widget.entryCountsByDay[dateKey] ?? 0;

    if (count == 0) return null;
    if (count <= 2) return const Color(0xFFE0E7FF);
    if (count <= 5) return const Color(0xFF8B9AFF);
    return const Color(0xFF4F5FE8);
  }

  Widget _buildDayCell(DateTime day, bool isSelected, {bool isToday = false}) {
    final markerColor = _getMarkerColor(day);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.3)
            : markerColor,
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: isSelected || markerColor != null
                ? Colors.white
                : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButton<int>(
      value: widget.focusedMonth.year,
      underline: Container(),
      items: widget.availableYears.map((year) {
        return DropdownMenuItem(
          value: year,
          child: Text('$year'),
        );
      }).toList(),
      onChanged: (newYear) {
        if (newYear != null) {
          final newMonth = DateTime(newYear, widget.focusedMonth.month, 1);
          widget.onMonthChanged(newMonth);
        }
      },
    );
  }

  Widget _buildCollapsedHeader() {
    return InkWell(
      onTap: widget.onToggleExpand,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Text(
              _formatMonthYear(widget.focusedMonth),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            _buildYearDropdown(),
            const Spacer(),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prevMonth = DateTime(
                widget.focusedMonth.year,
                widget.focusedMonth.month - 1,
                1,
              );
              widget.onMonthChanged(prevMonth);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Text(
            _formatMonthYear(widget.focusedMonth),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          _buildYearDropdown(),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final nextMonth = DateTime(
                widget.focusedMonth.year,
                widget.focusedMonth.month + 1,
                1,
              );
              widget.onMonthChanged(nextMonth);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.expand_less, size: 20),
            onPressed: widget.onToggleExpand,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedCalendar() {
    return Column(
      children: [
        _buildExpandedHeader(),
        TableCalendar(
          firstDay: DateTime(2020, 1, 1),
          lastDay: DateTime(2030, 12, 31),
          focusedDay: widget.focusedMonth,
          selectedDayPredicate: (day) {
            if (widget.selectedDate == null) return false;
            return isSameDay(day, widget.selectedDate);
          },
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerVisible: false,
          onDaySelected: (selectedDay, focusedDay) {
            if (widget.selectedDate != null &&
                isSameDay(selectedDay, widget.selectedDate)) {
              widget.onDateSelected(null);
            } else {
              widget.onDateSelected(selectedDay);
            }
          },
          onPageChanged: widget.onMonthChanged,
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              return _buildDayCell(day, false);
            },
            selectedBuilder: (context, day, focusedDay) {
              return _buildDayCell(day, true);
            },
            todayBuilder: (context, day, focusedDay) {
              return _buildDayCell(day, false, isToday: true);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.isRecording ? 0.5 : 1.0,
      child: IgnorePointer(
        ignoring: widget.isRecording,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: widget.isExpanded
              ? _buildExpandedCalendar()
              : _buildCollapsedHeader(),
        ),
      ),
    );
  }
}
