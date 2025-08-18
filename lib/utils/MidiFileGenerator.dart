import 'dart:io';
import 'dart:typed_data';

import '../SettingsManager.dart';
import '../midiUtils.dart';
import '../provider/BLEProvider.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class MidiFileGenerator {
  final List<TimedMidiEvent> _events = [];
  late DateTime _startTime;
  bool _isRecording = false;

  // 直接使用SettingsManager实例
  final SettingsManager _settings = SettingsManager();

  // MIDI文件参数 - 从设置获取
  int get _ticksPerQuarter => _settings.sharedPreferences.getInt("midiQuality") ?? 480;
  final int _tempo = 500000; // 默认tempo (120 BPM)

  void startRecording() {
    _isRecording = true;
    _startTime = DateTime.now();
    _events.clear();
    print('开始录制MIDI... 质量设置: ${_ticksPerQuarter} ticks/quarter');
  }

  void stopRecording() {
    _isRecording = false;
    print('停止录制MIDI，共录制 ${_events.length} 个事件');

    // 检查自动保存设置
    final autoSave = _settings.sharedPreferences.getBool("autoSave") ?? false;
    if (autoSave && _events.isNotEmpty) {
      _autoSave();
    }
  }

  void addMidiEvent(MidiEvent event) {
    if (!_isRecording) return;

    final currentTime = DateTime.now();
    final deltaTime = currentTime.difference(_startTime).inMilliseconds;

    // 应用力度增强 - 从设置获取倍数
    final velocityMultiplier = _settings.sharedPreferences.getDouble("velocityMultiplier") ?? 1.0;
    final enhancedEvent = _applyVelocityBoost(event, velocityMultiplier + 1);

    final timedEvent = TimedMidiEvent(
      event: enhancedEvent,
      timestamp: deltaTime,
    );

    _events.add(timedEvent);
    print('录制事件: ${enhancedEvent.toString()} at ${deltaTime}ms (增强${velocityMultiplier}x)');
  }

  // 应用力度增强
  MidiEvent _applyVelocityBoost(MidiEvent event, double multiplier) {
    if (event.type == 'Note On' || event.type == 'Note Off') {
      final boostedVelocity = (event.velocity * multiplier).round().clamp(0, 127);
      return MidiEvent(
        type: event.type,
        channel: event.channel,
        note: event.note,
        velocity: boostedVelocity,
      );
    }
    return event;
  }

  // 自动保存功能
  Future<void> _autoSave() async {
    try {
      final saveLocation = await _getDefaultSaveLocation();
      final fileName = _generateAutoFileName();
      final filePath = '$saveLocation/$fileName';
      await saveMidiFile(filePath);
      print('自动保存完成: $filePath');
    } catch (e) {
      print('自动保存失败: $e');
    }
  }

  // 获取默认保存位置
  Future<String> _getDefaultSaveLocation() async {
    // 先从设置中获取
    final savedLocation = _settings.sharedPreferences.getString("defaultSaveLocation");
    if (savedLocation != null && savedLocation.isNotEmpty) {
      return savedLocation;
    }

    // 如果没有设置，创建默认位置
    final directory = await getApplicationDocumentsDirectory();
    final midiFolder = Directory('${directory.path}/midi_recordings');
    if (!await midiFolder.exists()) {
      await midiFolder.create(recursive: true);
    }

    // 保存默认位置到设置
    await _settings.sharedPreferences.setString("defaultSaveLocation", midiFolder.path);
    return midiFolder.path;
  }

  // 生成自动保存文件名
  String _generateAutoFileName() {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'midi_recording_$timestamp.mid';
  }

  Future<File> saveMidiFile(String filePath) async {
    print('=== saveMidiFile开始执行 ===');
    print('文件路径: $filePath');
    print('事件数量: ${_events.length}');
    print('设置 - 质量: ${_ticksPerQuarter}, 力度增强: ${_settings.sharedPreferences.getDouble("velocityMultiplier") ?? 1.0}x');

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

        // 保存最后保存位置到设置
        await _settings.sharedPreferences.setString("lastSavedFile", filePath);

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

  // 快速保存到默认位置
  Future<File> quickSave() async {
    final saveLocation = await _getDefaultSaveLocation();
    final fileName = _generateAutoFileName();
    final filePath = '$saveLocation/$fileName';
    return await saveMidiFile(filePath);
  }

  // 获取推荐保存路径
  Future<String> getRecommendedFilePath([String? customName]) async {
    final saveLocation = await _getDefaultSaveLocation();
    final fileName = customName ?? _generateAutoFileName();
    return '$saveLocation/$fileName';
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

    // MIDI文件头标识 "MThd"
    header.setUint8(0, 0x4D); // M
    header.setUint8(1, 0x54); // T
    header.setUint8(2, 0x68); // h
    header.setUint8(3, 0x64); // d

    // 头部长度 (6字节)
    header.setUint32(4, 6);

    // 格式类型 (0 = 单轨道)
    header.setUint16(8, 0);

    // 轨道数量
    header.setUint16(10, 1);

    // 时间分辨率 (每四分音符的tick数) - 从设置获取
    header.setUint16(12, _ticksPerQuarter);

    return header.buffer.asUint8List();
  }

  Uint8List _createMidiTrack() {
    final trackEvents = <int>[];

    // 添加tempo事件
    trackEvents.addAll(_createTempoEvent());

    // 转换并添加MIDI事件
    int lastTime = 0;
    for (final timedEvent in _events) {
      final deltaTime = _millisecondsToTicks(timedEvent.timestamp - lastTime);
      trackEvents.addAll(_createVariableLengthQuantity(deltaTime));
      trackEvents.addAll(_createMidiEventBytes(timedEvent.event));
      lastTime = timedEvent.timestamp;
    }

    // 添加轨道结束标记
    trackEvents.addAll([0x00, 0xFF, 0x2F, 0x00]);

    // 创建轨道头
    final trackHeader = ByteData(8);
    trackHeader.setUint8(0, 0x4D); // M
    trackHeader.setUint8(1, 0x54); // T
    trackHeader.setUint8(2, 0x72); // r
    trackHeader.setUint8(3, 0x6B); // k
    trackHeader.setUint32(4, trackEvents.length);

    final result = Uint8List(8 + trackEvents.length);
    result.setRange(0, 8, trackHeader.buffer.asUint8List());
    result.setRange(8, result.length, trackEvents);

    return result;
  }

  List<int> _createTempoEvent() {
    // Delta time = 0
    final deltaTime = [0x00];

    // Meta event: Set Tempo
    final metaEvent = [0xFF, 0x51, 0x03];

    // Tempo值 (微秒每四分音符)
    final tempoBytes = [
      (_tempo >> 16) & 0xFF,
      (_tempo >> 8) & 0xFF,
      _tempo & 0xFF,
    ];

    return [...deltaTime, ...metaEvent, ...tempoBytes];
  }

  List<int> _createMidiEventBytes(MidiEvent event) {
    final channel = event.channel - 1; // MIDI通道从0开始

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
    final result = <int>[];

    if (value == 0) {
      return [0];
    }

    var temp = value;
    while (temp > 0) {
      result.insert(0, temp & 0x7F);
      temp >>= 7;
    }

    // 除了最后一个字节，其他字节的最高位都要设置为1
    for (int i = 0; i < result.length - 1; i++) {
      result[i] |= 0x80;
    }

    return result;
  }

  int _millisecondsToTicks(int milliseconds) {
    // 将毫秒转换为MIDI ticks
    // 公式: ticks = (milliseconds * ticksPerQuarter * 1000) / (tempo)
    return (milliseconds * _ticksPerQuarter * 1000) ~/ _tempo;
  }

  // === 新增的便捷方法 ===

  // 获取当前设置摘要
  String getSettingsSummary() {
    final quality = _settings.sharedPreferences.getInt("midiQuality") ?? 480;
    final velocity = _settings.sharedPreferences.getDouble("velocityMultiplier") ?? 1.0;
    final autoSave = _settings.sharedPreferences.getBool("autoSave") ?? false;
    return '质量:${quality} | 力度增强:${velocity}x | 自动保存:${autoSave ? "开" : "关"}';
  }

  // 更新设置的便捷方法
  Future<void> updateMidiQuality(int quality) async {
    await _settings.sharedPreferences.setInt("midiQuality", quality);
    print('MIDI质量已更新为: $quality ticks/quarter');
  }

  Future<void> updateVelocityMultiplier(double multiplier) async {
    await _settings.sharedPreferences.setDouble("velocityMultiplier", multiplier);
    print('力度增强倍数已更新为: ${multiplier}x');
  }

  Future<void> updateAutoSave(bool enabled) async {
    await _settings.sharedPreferences.setBool("autoSave", enabled);
    print('自动保存已${enabled ? "开启" : "关闭"}');
  }

  Future<void> updateDefaultSaveLocation(String path) async {
    await _settings.sharedPreferences.setString("defaultSaveLocation", path);
    print('默认保存位置已更新为: $path');
  }

  // 获取当前录制的事件数量
  int get eventCount => _events.length;

  // 获取录制状态
  bool get isRecording => _isRecording;

  // 清空所有事件
  void clearEvents() {
    _events.clear();
  }

  // 获取录制时长（毫秒）
  int get recordingDuration {
    if (_events.isEmpty) return 0;
    return _events.last.timestamp;
  }

  // 获取录制状态信息
  Map<String, dynamic> getRecordingInfo() {
    return {
      'isRecording': _isRecording,
      'eventCount': _events.length,
      'duration': recordingDuration,
      'settings': getSettingsSummary(),
    };
  }
}

// 扩展原有的BLEProvider - 保持原来的结构
extension BLEProviderMidiFile on BLEProvider {
  static final MidiFileGenerator _midiGenerator = MidiFileGenerator();

  MidiFileGenerator get midiGenerator => _midiGenerator;

  void startMidiRecording() {
    _midiGenerator.startRecording();
  }

  void stopMidiRecording() {
    _midiGenerator.stopRecording();
  }

  Future<File> saveMidiFile(String filePath) async {
    return await _midiGenerator.saveMidiFile(filePath);
  }

  Future<File> quickSaveMidi() async {
    return await _midiGenerator.quickSave();
  }

  // 修改原有的方法，增加设置集成
  void onMidiDataReceivedWithRecording(Uint8List data) {
    final event = parseMidiPacket(data);
    if (event != null) {
      print('原始事件: $event');

      // 添加到MIDI文件生成器（会自动应用设置中的增强）
      _midiGenerator.addMidiEvent(event);

    } else {
      print('无法识别的MIDI消息: ${data.map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ')}');
    }
  }

  // 获取录制状态
  String getRecordingStatus() {
    final info = _midiGenerator.getRecordingInfo();
    return '${info['isRecording'] ? "录制中" : "待机"} | 事件:${info['eventCount']} | ${info['settings']}';
  }
}

// 保持原有的数据类不变
class TimedMidiEvent {
  final MidiEvent event;
  final int timestamp; // 毫秒

  TimedMidiEvent({
    required this.event,
    required this.timestamp,
  });

  @override
  String toString() {
    return '${event.toString()} @ ${timestamp}ms';
  }
}