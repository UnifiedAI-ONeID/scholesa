import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ui/theme/scholesa_theme.dart';
import 'parent_models.dart';
import 'parent_service.dart';

/// Parent Schedule Page - View learner schedules and upcoming sessions
class ParentSchedulePage extends StatefulWidget {
  const ParentSchedulePage({super.key});

  @override
  State<ParentSchedulePage> createState() => _ParentSchedulePageState();
}

class _ParentSchedulePageState extends State<ParentSchedulePage> {
  String _selectedLearner = 'all';
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'week'; // day, week, month

  @override
  void initState() {
    super.initState();
    // Load schedule data from Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final DateTime now = DateTime.now();
      final DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final DateTime endOfMonth = DateTime(now.year, now.month + 1, 0);
      context.read<ParentService>().loadSchedule(
            startDate: startOfWeek,
            endDate: endOfMonth,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ParentService parentService = context.watch<ParentService>();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.parent.withOpacity(0.05),
              Colors.white,
              ScholesaColors.leadership.withOpacity(0.03),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildLearnerFilter()),
            SliverToBoxAdapter(child: _buildCalendarStrip(parentService)),
            SliverToBoxAdapter(child: _buildUpcomingSection(parentService)),
            SliverToBoxAdapter(child: _buildTodaySchedule(parentService)),
            SliverToBoxAdapter(child: _buildWeekOverview()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.parentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.parent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.calendar_month, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Schedule',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.parent,
                        ),
                  ),
                  Text(
                    'View upcoming sessions',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: ScholesaColors.parent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  _ViewModeButton(
                    label: 'D',
                    isSelected: _viewMode == 'day',
                    onTap: () => setState(() => _viewMode = 'day'),
                  ),
                  _ViewModeButton(
                    label: 'W',
                    isSelected: _viewMode == 'week',
                    onTap: () => setState(() => _viewMode = 'week'),
                  ),
                  _ViewModeButton(
                    label: 'M',
                    isSelected: _viewMode == 'month',
                    onTap: () => setState(() => _viewMode = 'month'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButton<String>(
          value: _selectedLearner,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'all', child: Text('All Learners')),
            DropdownMenuItem<String>(value: 'emma', child: Text('Emma Johnson')),
            DropdownMenuItem<String>(value: 'jack', child: Text('Jack Johnson')),
          ],
          onChanged: (String? value) {
            if (value != null) setState(() => _selectedLearner = value);
          },
        ),
      ),
    );
  }

  Widget _buildCalendarStrip(ParentService parentService) {
    final DateTime today = DateTime.now();
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int i) => today.add(Duration(days: i - today.weekday + 1)),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: days.map((DateTime date) {
            final bool isSelected = date.day == _selectedDate.day &&
                date.month == _selectedDate.month;
            final bool isToday = date.day == today.day &&
                date.month == today.month;

            return GestureDetector(
              onTap: () => setState(() => _selectedDate = date),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ScholesaColors.parent
                      : isToday
                          ? ScholesaColors.parent.withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      _getDayName(date.weekday),
                      style: TextStyle(
                        color: isSelected ? Colors.white70 : Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_hasEvents(date, parentService))
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : ScholesaColors.parent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUpcomingSection(ParentService parentService) {
    final List<UpcomingEvent> events = parentService.scheduleEvents;
    final DateTime now = DateTime.now();

    // Find next upcoming event
    final List<UpcomingEvent> upcomingEvents = events
        .where((UpcomingEvent e) => e.dateTime.isAfter(now))
        .toList()
      ..sort((UpcomingEvent a, UpcomingEvent b) => a.dateTime.compareTo(b.dateTime));

    final UpcomingEvent? nextEvent =
        upcomingEvents.isNotEmpty ? upcomingEvents.first : null;

    String timeUntil = 'No upcoming sessions';
    String eventTitle = 'Check back later';
    if (nextEvent != null) {
      final Duration diff = nextEvent.dateTime.difference(now);
      if (diff.inDays > 0) {
        timeUntil = 'Next Session in ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
      } else if (diff.inHours > 0) {
        timeUntil = 'Next Session in ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}';
      } else {
        timeUntil = 'Next Session in ${diff.inMinutes} min';
      }
      eventTitle = '${nextEvent.title} @ ${nextEvent.location}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.parent.withOpacity(0.1),
              ScholesaColors.leadership.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_available, color: ScholesaColors.parent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    timeUntil,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    eventTitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (nextEvent != null)
              TextButton(
                onPressed: () {},
                child: const Text('Details'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySchedule(ParentService parentService) {
    final List<UpcomingEvent> todayEvents =
        parentService.getEventsForDate(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                "Today's Schedule",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                '${todayEvents.length} session${todayEvents.length != 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (todayEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No sessions scheduled for today',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...todayEvents.map((UpcomingEvent event) {
              final DateTime now = DateTime.now();
              String status = 'upcoming';
              if (event.dateTime
                  .isBefore(now.subtract(const Duration(hours: 1)))) {
                status = 'completed';
              } else if (event.dateTime
                  .isBefore(now.add(const Duration(hours: 1)))) {
                status = 'in_progress';
              }

              return _ScheduleItem(
                time: _formatTime(event.dateTime),
                title: event.title,
                learner: event.learnerName ?? 'Unknown',
                location: event.location ?? '',
                pillar: event.pillar ?? 'Future Skills',
                pillarColor: _getPillarColor(event.pillar ?? 'Future Skills'),
                status: status,
              );
            }),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final int hour = dt.hour;
    final int minute = dt.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Color _getPillarColor(String pillar) {
    switch (pillar.toLowerCase()) {
      case 'future skills':
      case 'futureskills':
        return ScholesaColors.futureSkills;
      case 'leadership':
      case 'leadership & agency':
        return ScholesaColors.leadership;
      case 'impact':
      case 'impact & innovation':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.parent;
    }
  }

  Widget _buildWeekOverview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'This Week',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: <Widget>[
                _WeekDayRow(
                  day: 'Monday',
                  sessions: 3,
                  hours: '9 AM - 4 PM',
                  isToday: true,
                ),
                Divider(),
                _WeekDayRow(
                  day: 'Tuesday',
                  sessions: 2,
                  hours: '10 AM - 2 PM',
                ),
                Divider(),
                _WeekDayRow(
                  day: 'Wednesday',
                  sessions: 4,
                  hours: '9 AM - 5 PM',
                ),
                Divider(),
                _WeekDayRow(
                  day: 'Thursday',
                  sessions: 2,
                  hours: '11 AM - 3 PM',
                ),
                Divider(),
                _WeekDayRow(
                  day: 'Friday',
                  sessions: 3,
                  hours: '9 AM - 4 PM',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: _WeekStat(
                    label: 'Total Sessions',
                    value: '14',
                    icon: Icons.event,
                    color: ScholesaColors.parent,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade200,
                ),
                const Expanded(
                  child: _WeekStat(
                    label: 'Future Skills',
                    value: '6',
                    icon: Icons.code,
                    color: ScholesaColors.futureSkills,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade200,
                ),
                const Expanded(
                  child: _WeekStat(
                    label: 'Leadership',
                    value: '4',
                    icon: Icons.emoji_events,
                    color: ScholesaColors.leadership,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade200,
                ),
                const Expanded(
                  child: _WeekStat(
                    label: 'Impact',
                    value: '4',
                    icon: Icons.eco,
                    color: ScholesaColors.impact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const List<String> days = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[weekday - 1];
  }

  bool _hasEvents(DateTime date, ParentService parentService) {
    return parentService.hasEventsOnDate(date);
  }
}

class _ViewModeButton extends StatelessWidget {

  const _ViewModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ScholesaColors.parent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ScholesaColors.parent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {

  const _ScheduleItem({
    required this.time,
    required this.title,
    required this.learner,
    required this.location,
    required this.pillar,
    required this.pillarColor,
    required this.status,
  });
  final String time;
  final String title;
  final String learner;
  final String location;
  final String pillar;
  final Color pillarColor;
  final String status;

  IconData get _statusIcon {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.play_circle;
      default:
        return Icons.schedule;
    }
  }

  Color get _statusColor {
    switch (status) {
      case 'completed':
        return ScholesaColors.success;
      case 'in_progress':
        return ScholesaColors.warning;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: <Widget>[
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: pillarColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(_statusIcon, color: _statusColor, size: 20),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pillarColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    pillar,
                                    style: TextStyle(
                                      color: pillarColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.person,
                                    size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  learner,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.location_on,
                                  size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {

  const _WeekDayRow({
    required this.day,
    required this.sessions,
    required this.hours,
    this.isToday = false,
  });
  final String day;
  final int sessions;
  final String hours;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          if (isToday)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: ScholesaColors.parent,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              day,
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? ScholesaColors.parent : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$sessions sessions',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          Text(
            hours,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {

  const _WeekStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
