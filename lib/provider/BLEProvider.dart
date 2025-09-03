import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../SettingsManager.dart';
import '../midiUtils.dart';
import '../utils/MidiFileGenerator.dart';

class BLEProvider extends ChangeNotifier {
  final _mIDICommand = MidiCommand();
  final List<MidiDevice> devices = [];
  Timer? _devicePollingTimer;
  MidiDevice? _nowConnectedDevice;

  final MidiFileGenerator _midiGenerator = MidiFileGenerator();

  // Toast状态
  String? _toastMessage;
  String? _errorMessage;

  // 录制状态
  bool _isRecording = false;

  // Getters
  String? get toastMessage => _toastMessage;
  String? get errorMessage => _errorMessage;
  bool get isRecording => _isRecording;
  int get recordedEventCount => _midiGenerator.eventCount;
  int get recordingDuration => _midiGenerator.recordingDuration;

  BLEProvider() {
    _startScan();
  }

  Future<void> _startScan() async {
    await _requestPermissions();
    _mIDICommand.startScanningForBluetoothDevices();
    _devicePollingTimer = Timer.periodic(Duration(seconds: 4), (_) async {
      final devices = await _mIDICommand.devices;
      if (devices != null) {
        this.devices
          ..clear()
          ..addAll(devices);
        notifyListeners();
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.storage,
    ].request();
  }

  Future<void> connectDeceive(MidiDevice device) async {
    try {
      await _mIDICommand.connectToDevice(device);

      // 设置MIDI数据接收监听
      _mIDICommand.onMidiDataReceived?.listen((packet) {
        onMidiDataReceivedWithRecording(packet.data);
      });

      _devicePollingTimer?.cancel();
      _toastMessage = '连接成功';
      _nowConnectedDevice = device;
      notifyListeners();

    } catch (error) {
      _toastMessage = '连接失败: $error';
      notifyListeners();
      throw error;
    }
  }

  // 开始录制MIDI
  Future<void> startMidiRecording() async {
    if (_nowConnectedDevice == null) {
      throw Exception('你还没有连接设备!');
    }
    _midiGenerator.startRecording();
    _isRecording = true;
    _toastMessage = '开始录制MIDI';
    notifyListeners();
  }

  // 停止录制MIDI
  void stopMidiRecording() {
    _midiGenerator.stopRecording();
    _isRecording = false;
    _toastMessage = '停止录制MIDI，共录制 ${_midiGenerator.eventCount} 个事件';
    notifyListeners();
  }

  // 保存MIDI文件
  Future<String> saveMidiFile({String? fileName}) async {
    try {
      if (_midiGenerator.eventCount == 0) {
        throw Exception('没有MIDI数据可保存');
      }

      // 使用utils中MidiFileGenerator的saveMidiFileToAccessible方法
      final filePath = await _midiGenerator.saveMidiFileToAccessible(fileName: fileName);
      _toastMessage = 'MIDI文件已保存: $filePath';
      notifyListeners();

      return filePath;
    } catch (e) {
      _errorMessage = '保存MIDI文件失败: $e';
      _toastMessage = _errorMessage;
      notifyListeners();
      throw e;
    }
  }

  // 清空录制的MIDI数据
  void clearMidiRecording() {
    _midiGenerator.clearEvents();
    _toastMessage = '已清空MIDI录制数据';
    notifyListeners();
  }

  // 处理接收到的MIDI数据
  void onMidiDataReceivedWithRecording(Uint8List data) {
    final event = parseMidiPacket(data);
    if (event != null) {
      print('原始事件: $event');

      if (_isRecording) {
        _midiGenerator.addMidiEvent(event);
        notifyListeners(); // 通知UI更新事件计数
      }
    } else {
      print('无法识别的MIDI消息: ${data.map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ')}');
    }
  }

  // 获取所有录制的事件（用于UI显示）
  List<TimedMidiEvent> getRecordedEvents() {
    return _midiGenerator.getRecordedEvents();
  }

  // 清除Toast消息
  void clearToastMessage() {
    _toastMessage = null;
    notifyListeners();
  }

  // 断开设备连接
  Future<void> disconnectDevice() async {
    try {
      _mIDICommand.stopScanningForBluetoothDevices();
      _toastMessage = '设备已断开连接';
      notifyListeners();
    } catch (e) {
      _errorMessage = '断开连接失败: $e';
      _toastMessage = _errorMessage;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _mIDICommand.stopScanningForBluetoothDevices();
    _devicePollingTimer?.cancel();
    super.dispose();
  }
}