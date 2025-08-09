import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:forui/forui.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  Timer? _recordTimer;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  bool isStart = false;

  void _startTimer() {
    _startTime = DateTime.now();
    _elapsed = Duration.zero;

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });
    });
  }

  void _stopTimer() {
    _recordTimer?.cancel();
    setState(() {
      if (_startTime != null) {
        _elapsed = DateTime.now().difference(_startTime!);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _recordTimer?.cancel();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    double screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    return FScaffold(
        header: FHeader(
          title: Padding(
            padding: const EdgeInsets.only(top: 16.0), // 向下偏移8像素
            child: const Text('首页'),
          ),
          suffixes: [
            FHeaderAction(icon: Icon(FIcons.ellipsis), onPress: () {})
          ],
        ),
        child: Padding(padding: EdgeInsets.only(top: 20), child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: screenWidth * 0.5,
                  height: screenHeight * 0.4,
                  child: FButton(
                    onPress: () {
                      if (isStart) {
                        _stopTimer();
                      } else {
                        _startTimer();
                      }
                      setState(() {
                        isStart = !isStart;
                      });
                    },
                    child: Align(
                      alignment: Alignment.center, // 或 Alignment.topCenter，自己调
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_formatDuration(_elapsed)}',
                            style: TextStyle(fontSize: 36),
                          ),
                          SizedBox(height: 30),
                          Text('开始录制', style: TextStyle(fontSize: 36)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ) ,)
    );
  }
}
