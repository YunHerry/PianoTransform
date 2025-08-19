import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:piano_transform/provider/BLEProvider.dart';
import 'package:provider/provider.dart';

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
        _startTime = null;
      }
    });
  }

  void _startRecord() {
    Provider.of<BLEProvider>(context, listen: false)
        .startMidiRecording()
        .then((_) {
          _startTimer();
          isStart = true;
        })
        .catchError((error) {
          showFToast(
            context: context,
            duration: Duration(seconds: 1),
            alignment: FToastAlignment.topCenter,
            icon: Icon(FIcons.messageSquareWarning, color: Colors.yellow[800]),
            title: Text(error.toString().replaceFirst('Exception: ', '')),
          );
        });
  }

  void _stopRecord() {
    _stopTimer();
    isStart = false;
    Provider.of<BLEProvider>(context, listen: false).stopMidiRecording();
    Provider.of<BLEProvider>(context, listen: false)
        .saveMidiFile()
        .then((data) {
          if (!context.mounted) return;
          showFToast(
            context: context,
            duration: Duration(seconds: 3),
            alignment: FToastAlignment.topCenter,
            icon: const Icon(FIcons.triangleAlert),
            title: Text('录制完成,保存到: $data'),
          );
        })
        .catchError((error) {
          showFToast(
            context: context,
            duration: null,
            alignment: FToastAlignment.topCenter,
            icon: const Icon(FIcons.triangleAlert),
            title: Text(error.toString().replaceFirst('Exception: ', '')),
          );
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
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return FScaffold(
      header: FHeader(
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0), // 向下偏移8像素
          child: const Text('首页', style: TextStyle(fontSize: 21)),
        ),
        suffixes: [FHeaderAction(icon: Icon(FIcons.ellipsis), onPress: () {})],
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 20),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: screenWidth * 0.5,
                  height: screenHeight * 0.4,
                  child: FButton(
                    onPress: () async {
                      if (!isStart) {
                        _startRecord();
                      } else {
                        _stopRecord();
                      }
                      setState(() {});
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
                          Text(
                            isStart ? '结束录制' : '开始录制',
                            style: TextStyle(fontSize: 36),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
