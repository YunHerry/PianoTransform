import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'midiUtils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
    _devicePollingTimer = Timer.periodic(Duration(seconds: 1), (_) async {
      final devices = await mIDICommand.devices;
      if (devices != null) {
        setState(() {
          _devices
            ..clear()
            ..addAll(devices);
        });
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return ListTile(
            title: Text(device.name.isNotEmpty ? device.name : "(未命名)"),
            subtitle: Text("ID: ${device.id}"),
            onLongPress: () {
              mIDICommand.connectToDevice(device).then((dynamic _) async {
                mIDICommand.onMidiDataReceived?.listen((packet) {
                  onMidiDataReceived(packet.data);
                });
                mIDICommand.stopScanningForBluetoothDevices();
              });
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        tooltip: '扫描设备',
        child: const Icon(Icons.search),
      ),
    );
  }
}