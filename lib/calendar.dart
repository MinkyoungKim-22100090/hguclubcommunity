import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class CalendarPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'HGU Club Calendar', home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SfCalendar(
      view: CalendarView.schedule,
      dataSource: MeetingDataSource(_getDataSource()),
      monthViewSettings: const MonthViewSettings(
          appointmentDisplayMode: MonthAppointmentDisplayMode.appointment),
    ));
  }

  List<Meeting> _getDataSource() {
    final List<Meeting> meetings = <Meeting>[];
    final DateTime today = DateTime.now();
    final DateTime startTime = DateTime(today.year, today.month, today.day, 9);
    final DateTime endTime = startTime.add(const Duration(hours: 2));
    meetings.add(Meeting(
        'Conference', startTime, endTime, 0xFF0F8644, false));
    return meetings;
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Meeting> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return _getMeetingData(index).from;
  }

  @override
  DateTime getEndTime(int index) {
    return _getMeetingData(index).to;
  }

  @override
  String getSubject(int index) {
    return _getMeetingData(index).eventName;
  }

  @override
  Color getColor(int index) {
    return _getMeetingData(index).background;
  }

  @override
  bool isAllDay(int index) {
    return _getMeetingData(index).isAllDay;
  }

  Meeting _getMeetingData(int index) {
    final dynamic meeting = appointments![index];
    late final Meeting meetingData;
    if (meeting is Meeting) {
      meetingData = meeting;
    }

    return meetingData;
  }
}


class Meeting {
  Meeting(
    this.eventName,
    this.from,
    this.to,
    int background, // Change Color to int
    this.isAllDay,
  ) : background = Color(background); // Convert int to Color

  String eventName;
  DateTime from;
  DateTime to;
  Color background; // Change type to Color
  bool isAllDay;
}



//add
class AddPage extends StatefulWidget {
  const AddPage({Key? key}) : super(key: key);

  @override
  _AddPageState createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  late TextEditingController _eventNameController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedStartTime;
  late TimeOfDay _selectedEndTime;
  late bool _isAllDay;

  @override
  void initState() {
    super.initState();
    _eventNameController = TextEditingController();
    _selectedDate = DateTime.now();
    _selectedStartTime = TimeOfDay(hour: 9, minute: 0);
    _selectedEndTime = TimeOfDay(hour: 11, minute: 0);
    _isAllDay = false;
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    super.dispose();
  }

  void _addMeeting() {
    final String eventName = _eventNameController.text.trim();

    if (eventName.isNotEmpty) {
      final DateTime startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedStartTime.hour,
        _selectedStartTime.minute,
      );

      final DateTime endTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedEndTime.hour,
        _selectedEndTime.minute,
      );

      final Meeting newMeeting = Meeting(
        eventName,
        startTime,
        endTime,
        0xFF0F8644,
        _isAllDay,
      );
      FirebaseFirestore.instance.collection('calendar').add({
        'eventName': newMeeting.eventName,
        'startTime': newMeeting.from,
        'endTime': newMeeting.to,
        'background': newMeeting.background.value,
        'isAllDay': newMeeting.isAllDay,
      }).then((value) {

        Navigator.pop(context, newMeeting);
      }).catchError((error) {

        print('Error adding meeting: $error');
      });
      Navigator.pop(context, newMeeting);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Meeting'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Text('Date: ${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}'),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );

                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Text('Start Time: ${_selectedStartTime.format(context)}'),
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _selectedStartTime,
                    );

                    if (pickedTime != null) {
                      setState(() {
                        _selectedStartTime = pickedTime;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Text('End Time: ${_selectedEndTime.format(context)}'),
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _selectedEndTime,
                    );

                    if (pickedTime != null) {
                      setState(() {
                        _selectedEndTime = pickedTime;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Checkbox(
                  value: _isAllDay,
                  onChanged: (value) {
                    setState(() {
                      _isAllDay = value ?? false;
                    });
                  },
                ),
                const Text('All Day Event'),
              ],
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _addMeeting,
              child: const Text('Add Meeting'),
            ),
          ],
        ),
      ),
    );
  }
}


//delete


//update


//detail
