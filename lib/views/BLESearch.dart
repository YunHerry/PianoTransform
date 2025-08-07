import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:forui/forui.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../midiUtils.dart';
class BLESearchPage extends StatefulWidget {
  const BLESearchPage({super.key, required this.title});

  final String title;

  @override
  State<BLESearchPage> createState() => _BLESearchPageState();
}

class _BLESearchPageState extends State<BLESearchPage> {
  final mIDICommand = MidiCommand();
  Timer? _devicePollingTimer;
  var logger = Logger();
  final List<MidiDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    mIDICommand.stopScanningForBluetoothDevices();
  }

  Future<void> _startScan() async {
    await _requestPermissions();
    mIDICommand.startScanningForBluetoothDevices();
    _devicePollingTimer = Timer.periodic(Duration(seconds: 4), (_) async {
      final devices = await mIDICommand.devices;
      if (devices != null) {
        setState(() {
          _devices
            ..clear()
            ..addAll(devices);
        });
        // showFToast(
        //   context: context,
        //   duration: null,
        //   alignment: FToastAlignment.topLeft,
        //   icon: const Icon(FIcons.triangleAlert),
        //   title: const Text('扫描完成'),
        // );
      }
    });
    // print(mIDICommand.dispose());

    // mIDICommand.setD
    // mIDICommand.stopScanningForBluetoothDevices();
    // mIDICommand.devices.then((value) {
    //   if (value != null) {
    //     // print("检测到");
    //     setState(() {
    //       _devices.clear();
    //       _devices.addAll(value);
    //     });
    //   }
    // });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0), // 向下偏移8像素
          child: const Text('设备管理'),
        ),
        suffixes: [FHeaderAction(icon: Icon(FIcons.ellipsis), onPress: () {})],
      ),
      child: ListView.separated(
        itemCount: _devices.length,

        itemBuilder: (context, index) {
          final device = _devices[index];
          return FTile(
            prefix: Icon(FIcons.bell),
            title: Text(device.name.isNotEmpty ? device.name : "(未命名)"),
            subtitle: Text("ID: ${device.id}"),
            suffix: Icon(FIcons.chevronRight),
            onLongPress: () {
              HapticFeedback.vibrate();
              FocusScope.of(context).unfocus();
              setState(() {
                // 恢复颜色状态
              });
              showFDialog(
                context: context,
                builder: (context, style, animation) => FDialog(
                  style: style,
                  animation: animation,
                  direction: Axis.horizontal,
                  title: const Text('是否连接 ?'),
                  body: Text('你确定要将${device.name}绑定至本机吗?'),
                  actions: [
                    FButton(
                      style: FButtonStyle.outline(),
                      onPress: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FButton(
                      onPress: () {
                        mIDICommand.connectToDevice(device).then((
                            dynamic _,
                            ) async {
                          showFToast(
                            context: context,
                            duration: null,
                            alignment: FToastAlignment.topCenter,
                            icon: const Icon(FIcons.triangleAlert),
                            title: const Text('连接成功'),
                          );
                          mIDICommand.onMidiDataReceived?.listen((packet) {
                            onMidiDataReceived(packet.data);
                          });
                          // mIDICommand.stopScanningForBluetoothDevices();
                          _devicePollingTimer?.cancel();
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text('连接'),
                    ),
                  ],
                ),
              );
            },
          );
        },
        separatorBuilder: (context, index) => SizedBox(height: 10),
      ),
    );
  }
}
