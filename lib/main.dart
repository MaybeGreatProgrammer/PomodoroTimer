import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibrate/vibrate.dart';
import 'package:screen/screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Pomodoro',
        theme: ThemeData(
          primarySwatch: Colors.red,
        ),
        home: PomodoroTimer());
  }
}

class PomodoroTimer extends StatefulWidget {
  @override
  PomodoroTimerState createState() => new PomodoroTimerState();
}

class PomodoroTimerState extends State<PomodoroTimer> {
  int workingTime;
  int shortBreakTime;
  int longBreakTime;
  int workToLongBreak;
  int _seconds;
  int _workDone = 0;
  Timer _timer;
  bool _isPlaying = false;
  bool _isWorking = true;
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    getConfig().then((List<int> result) {
      workingTime = result[0] * 60;
      shortBreakTime = result[1] * 60;
      longBreakTime = result[2] * 60;
      workToLongBreak = result[3] - 1;
      setState(() {
        _seconds = workingTime;
      });
      Screen.keepOn(true);
    });
  }

  Widget build(BuildContext context) {
    double value = 1;
    if (_isWorking)
      value = _seconds / workingTime;
    else if (_workDone == 0)
      value = _seconds / longBreakTime;
    else
      value = _seconds / shortBreakTime;
    int displayMinutes = _seconds ~/ 60;
    int displaySeconds = _seconds - (displayMinutes * 60);
    String paddedSeconds;
    if (displaySeconds < 10)
      paddedSeconds = "0$displaySeconds";
    else
      paddedSeconds = "$displaySeconds";

    return new Scaffold(
      appBar: new AppBar(title: Text("Pomodoro"), actions: <Widget>[
        new IconButton(icon: const Icon(Icons.list), onPressed: _pushConfig),
      ]),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          SizedBox(
            height: 200,
            child: Stack(
              children: <Widget>[
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    child: new CircularProgressIndicator(
                      strokeWidth: 15,
                      value: value,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    "$displayMinutes:$paddedSeconds",
                    style: TextStyle(fontSize: 50, color: Colors.red),
                  ),
                )
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton(
                  icon: Icon(Icons.fast_rewind),
                  onPressed: () {
                    if (_isWorking)
                      setTime(workingTime);
                    else {
                      if (_workDone == 0)
                        setTime(longBreakTime);
                      else
                        setTime(shortBreakTime);
                    }
                  }),
              FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () {
                    if (_isPlaying) {
                      setState(() {
                        _timer.cancel();
                        _isPlaying = false;
                      });
                    } else {
                      setState(() {
                        _timer = new Timer.periodic(
                            Duration(seconds: 1), everySecond);
                        _isPlaying = true;
                      });
                    }
                  },
                  child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow)),
              IconButton(
                icon: Icon(Icons.fast_forward),
                onPressed: () {
                  if (_isWorking) {
                    if (_workDone >= workToLongBreak)
                      setTime(longBreakTime, false, 0);
                    else
                      setTime(shortBreakTime, false, _workDone + 1);
                  } else
                    setTime(workingTime, true);
                },
              )
            ],
          )
        ],
      ),
    );
  }

  void everySecond(Timer timer) {
    setState(() {
      if (_seconds > 0)
        _seconds = _seconds -= 1;
      else {
        Vibrate.vibrate();
        if (_isWorking) {
          if (_workDone >= workToLongBreak)
            setTime(longBreakTime, false, 0);
          else
            setTime(shortBreakTime, false, _workDone + 1);
        } else {
          setTime(workingTime, true);
        }
        setState(() {
          _timer.cancel();
          _isPlaying = false;
        });
      }
    });
  }

  void setTime(int seconds, [bool isWorking, int breaksTaken]) {
    setState(() {
      _seconds = seconds;
      if (isWorking != null) _isWorking = isWorking;
      if (breaksTaken != null) _workDone = breaksTaken;
      if (_isPlaying) {
        _timer.cancel();
        _timer = new Timer.periodic(Duration(seconds: 1), everySecond);
      }
    });
  }

  void _pushConfig() async {
    List<int> result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConfigScreen()),
    );
    setState(() {
      int oldWt = workingTime;
      int oldSb = shortBreakTime;
      int oldLb = longBreakTime;
      if (result[0] != null) workingTime = result[0] * 60;
      if (result[1] != null) shortBreakTime = result[1] * 60;
      if (result[2] != null) longBreakTime = result[2] * 60;
      if (result[3] != null) workToLongBreak = result[3] - 1;
      if (_isWorking) {
        if (workingTime != oldWt) setTime(workingTime);
      } else {
        if (_workDone == 0) {
          if (longBreakTime != oldLb) setTime(longBreakTime);
        } else if (shortBreakTime != oldSb) setTime(shortBreakTime);
      }
    });
  }

  Future<List<int>> getConfig() async {
    int workTime = await _prefs.then((SharedPreferences prefs) {
      return (prefs.getInt('workTime') ?? 25);
    });
    int shortTime = await _prefs.then((SharedPreferences prefs) {
      return (prefs.getInt('shortTime') ?? 5);
    });
    int longTime = await _prefs.then((SharedPreferences prefs) {
      return (prefs.getInt('longTime') ?? 20);
    });
    int workPeriods = await _prefs.then((SharedPreferences prefs){
      return (prefs.getInt('workPeriods') ?? 4);
    });
    return [workTime, shortTime, longTime, workPeriods];
  }
}

class ConfigScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new ConfigState();
}

class ConfigState extends State<ConfigScreen> {
  final workController = TextEditingController();
  final sbController = TextEditingController();
  final lbController = TextEditingController();
  final wpController = TextEditingController();

  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
  }

  Future<bool> _onWillPop() async {
    SharedPreferences prefs = await _prefs;
    String workText = workController.text;
    String sbText = sbController.text;
    String lbText = lbController.text;
    String wpText = wpController.text;
    int workTime;
    int shortTime;
    int longTime;
    int workPeriods;
    if (workText.length != 0) {
      workText = workText.replaceAll(".", "");
      workTime = int.parse(workText);
      if(workTime < 1) workTime = 1;
      if(workTime > 59) workTime = 59;
      prefs.setInt("workTime", workTime);
    }
    if (sbText.length != 0) {
      sbText = sbText.replaceAll(".", "");
      shortTime = int.parse(sbText);
      if(shortTime < 1) shortTime = 1;
      if(shortTime > 59) shortTime = 59;
      prefs.setInt("shortTime", shortTime);
    }
    if (lbText.length != 0) {
      lbText = lbText.replaceAll(".", "");
      longTime = int.parse(lbText);
      if(longTime < 1) longTime = 1;
      if(longTime > 59) longTime = 59;
      prefs.setInt("longTime", longTime);
    }
    if(wpText.length != 0){
      wpText = wpText.replaceAll(".", "");
      workPeriods = int.parse(wpText);
      if(workPeriods < 1) workPeriods = 1;
      if(workPeriods > 100) workPeriods = 100;
      prefs.setInt("workPeriods", workPeriods);
    }
    Navigator.pop(context, [workTime, shortTime, longTime, workPeriods]);
    return new Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
      onWillPop: _onWillPop,
      child: new Scaffold(
        appBar: new AppBar(title: Text("Pomodoro")),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new TextField(
              decoration: new InputDecoration(labelText: "Work Time (Minutes)"),
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              controller: workController,
            ),
            new TextField(
              decoration:
                  new InputDecoration(labelText: "Short Break Time (Minutes)"),
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              controller: sbController,
            ),
            new TextField(
              decoration:
                  new InputDecoration(labelText: "Long Break Time (Minutes)"),
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              controller: lbController,
            ),
            new TextField(
              decoration:
              new InputDecoration(labelText: "Work Periods Before Long Break"),
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              controller: wpController,
            ),
          ],
        ),
      ),
    );
  }
}
