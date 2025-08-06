import 'dart:typed_data';

import 'package:forui/forui.dart';

class MidiEvent {
  final String type;
  final int channel;
  final int note;
  final int velocity;

  MidiEvent({required this.type, required this.channel, required this.note, required this.velocity});

  @override
  String toString() {
    final noteName = midiNoteToName(note);
    return 'Type: $type, Channel: $channel, Note: $note ($noteName), Velocity: $velocity';
  }
}

String midiNoteToName(int note) {
  const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  int octave = (note ~/ 12) - 1;
  int noteIndex = note % 12;

  return '${notes[noteIndex]}$octave';
}

MidiEvent? parseMidiPacket(Uint8List data) {
  if (data.length < 3) return null;

  int status = data[0];
  int data1 = data[1];
  int data2 = data[2];

  int messageType = (status & 0xF0) >> 4;
  int channel = (status & 0x0F) + 1;

  switch (messageType) {
    case 0x8:
      return MidiEvent(type: 'Note Off', channel: channel, note: data1, velocity: data2);
    case 0x9:
      if (data2 == 0) {
        return MidiEvent(type: 'Note Off', channel: channel, note: data1, velocity: data2);
      } else {
        return MidiEvent(type: 'Note On', channel: channel, note: data1, velocity: data2);
      }
    case 0xB:
      return MidiEvent(type: 'Control Change', channel: channel, note: data1, velocity: data2);
    default:
      return null;
  }
}

void onMidiDataReceived(Uint8List data) {
  final event = parseMidiPacket(data);
  if (event != null) {
    print(event);
  } else {
    print('无法识别的MIDI消息: ${data.map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ')}');
  }
}
