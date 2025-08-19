import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../midiUtils.dart';

class BLEProvider extends ChangeNotifier {
  final _mIDICommand = MidiCommand();
  final List<MidiDevice> devices = [];
  Timer? _devicePollingTimer;
  MidiDevice? _nowConnectedDevice;
  // MIDI文件生成器
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
      Permission.storage, // 添加存储权限用于保存MIDI文件
    ].request();
  }

  Future<void> connectDeceive(MidiDevice device) async {
    try {
      await _mIDICommand.connectToDevice(device);

      // 设置MIDI数据接收监听
      _mIDICommand.onMidiDataReceived?.listen((packet) {
        _onMidiDataReceived(packet.data);
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

      // 获取文档目录
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final finalFileName = fileName ?? 'midi_recording_$timestamp.mid';
      final filePath = '${directory.path}/$finalFileName';

      final file = await _midiGenerator.saveMidiFile(filePath);
      await _midiGenerator.saveMidiFileToAccessible(fileName: fileName);
      _toastMessage = 'MIDI文件已保存: ${file.path}';
      notifyListeners();

      return file.path;
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
  void _onMidiDataReceived(Uint8List data) {
    final event = parseMidiPacket(data);
    if (event != null) {
      print(event);

      // 如果正在录制，添加到MIDI文件生成器
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
    return List.from(_midiGenerator._events);
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

// MIDI文件生成器类
class MidiFileGenerator {
  final List<TimedMidiEvent> _events = [];
  late DateTime _startTime;
  bool _isRecording = false;

  final int _ticksPerQuarter = 480;
  final int _tempo = 500000;

  void startRecording() {
    _isRecording = true;
    _startTime = DateTime.now();
    _events.clear();
  }

  void stopRecording() {
    _isRecording = false;
  }

  void addMidiEvent(MidiEvent event) {
    if (!_isRecording) return;

    final currentTime = DateTime.now();
    final deltaTime = currentTime.difference(_startTime).inMilliseconds;

    final timedEvent = TimedMidiEvent(
      event: event,
      timestamp: deltaTime,
    );

    _events.add(timedEvent);
  }
  Future<File> saveMidiFile(String filePath) async {
    print('=== saveMidiFile开始执行 ===');
    print('文件路径: $filePath');
    print('事件数量: ${_events.length}');

    if (_events.isEmpty) {
      print('错误: 没有MIDI事件可保存');
      throw Exception('没有MIDI事件可保存');
    }

    try {
      print('开始生成MIDI数据...');
      final midiData = _generateMidiFile();
      print('MIDI数据生成完成，大小: ${midiData.length} bytes');

      print('创建文件对象...');
      final file = File(filePath);

      // 检查目录是否存在
      final directory = file.parent;
      if (!await directory.exists()) {
        print('目录不存在，创建目录: ${directory.path}');
        await directory.create(recursive: true);
      }

      print('开始写入文件...');
      await file.writeAsBytes(midiData);
      print('文件写入完成');

      // 验证文件是否真的被创建
      if (await file.exists()) {
        final fileSize = await file.length();
        print('MIDI文件已保存到: $filePath');
        print('文件大小验证: $fileSize bytes');
        return file;
      } else {
        print('错误: 文件写入后不存在');
        throw Exception('文件保存失败：文件不存在');
      }

    } catch (e) {
      print('saveMidiFile出错: $e');
      print('错误类型: ${e.runtimeType}');
      rethrow;
    }
  }
  Future<String> saveMidiFileToAccessible({String? fileName}) async {
    Directory? directory;

    if (Platform.isAndroid) {
      // 使用外部存储的Music目录
      directory = Directory('/storage/emulated/0/Music/PianoTransform');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = fileName ?? 'midi_recording_$timestamp.mid';
    final filePath = '${directory.path}/$finalFileName';

    final file = await saveMidiFile(filePath);
    return file.path;
  }

  Uint8List _generateMidiFile() {
    final header = _createMidiHeader();
    final track = _createMidiTrack();

    final totalLength = header.length + track.length;
    final result = Uint8List(totalLength);

    result.setRange(0, header.length, header);
    result.setRange(header.length, totalLength, track);

    return result;
  }

  Uint8List _createMidiHeader() {
    final header = ByteData(14);

    header.setUint8(0, 0x4D);
    header.setUint8(1, 0x54);
    header.setUint8(2, 0x68);
    header.setUint8(3, 0x64);
    header.setUint32(4, 6);
    header.setUint16(8, 0);
    header.setUint16(10, 1);
    header.setUint16(12, _ticksPerQuarter);

    return header.buffer.asUint8List();
  }

  Uint8List _createMidiTrack() {
    final trackEvents = <int>[];

    trackEvents.addAll(_createTempoEvent());

    int lastTime = 0;
    for (final timedEvent in _events) {
      final deltaTime = _millisecondsToTicks(timedEvent.timestamp - lastTime);
      trackEvents.addAll(_createVariableLengthQuantity(deltaTime));
      trackEvents.addAll(_createMidiEventBytes(timedEvent.event));
      lastTime = timedEvent.timestamp;
    }

    trackEvents.addAll([0x00, 0xFF, 0x2F, 0x00]);

    final trackHeader = ByteData(8);
    trackHeader.setUint8(0, 0x4D);
    trackHeader.setUint8(1, 0x54);
    trackHeader.setUint8(2, 0x72);
    trackHeader.setUint8(3, 0x6B);
    trackHeader.setUint32(4, trackEvents.length);

    final result = Uint8List(8 + trackEvents.length);
    result.setRange(0, 8, trackHeader.buffer.asUint8List());
    result.setRange(8, result.length, trackEvents);

    return result;
  }

  List<int> _createTempoEvent() {
    return [0x00, 0xFF, 0x51, 0x03,
      (_tempo >> 16) & 0xFF, (_tempo >> 8) & 0xFF, _tempo & 0xFF];
  }

  List<int> _createMidiEventBytes(MidiEvent event) {
    final channel = event.channel - 1;

    switch (event.type) {
      case 'Note On':
        return [0x90 | channel, event.note, event.velocity];
      case 'Note Off':
        return [0x80 | channel, event.note, event.velocity];
      case 'Control Change':
        return [0xB0 | channel, event.note, event.velocity];
      default:
        return [];
    }
  }

  List<int> _createVariableLengthQuantity(int value) {
    if (value == 0) return [0];

    final result = <int>[];
    var temp = value;

    while (temp > 0) {
      result.insert(0, temp & 0x7F);
      temp >>= 7;
    }

    for (int i = 0; i < result.length - 1; i++) {
      result[i] |= 0x80;
    }

    return result;
  }

  int _millisecondsToTicks(int milliseconds) {
    return (milliseconds * _ticksPerQuarter * 1000) ~/ _tempo;
  }

  int get eventCount => _events.length;
  bool get isRecording => _isRecording;
  void clearEvents() => _events.clear();
  int get recordingDuration => _events.isEmpty ? 0 : _events.last.timestamp;
}

class TimedMidiEvent {
  final MidiEvent event;
  final int timestamp;

  TimedMidiEvent({
    required this.event,
    required this.timestamp,
  });

  @override
  String toString() {
    return '${event.toString()} @ ${timestamp}ms';
  }
}