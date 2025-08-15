import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:piano_transform/provider/BLEProvider.dart';
import 'package:provider/provider.dart';

class FileListPage extends StatefulWidget {
  const FileListPage({super.key});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage> {
  final List<FileSystemEntity> _files = [];
  @override
  void initState() {
    super.initState();
    _loadFiles();
  }
  Future<void> _loadFiles() async {
    // 获取应用的文档目录（你可以改成任意路径）
    Directory dir = Directory('/storage/emulated/0/Music/PianoTransform');
    // 如果想访问自定义路径，例如 /storage/emulated/0/Download：
    // Directory dir = Directory('/storage/emulated/0/Download');

    List<FileSystemEntity> fileList = dir.listSync();
    setState(() {
      _files..clear()..addAll(fileList);
    });
  }
  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0), // 向下偏移8像素
          child: const Text('集合', style: TextStyle(fontSize: 21)),
        ),
      ),
      child: _files.isEmpty ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [FProgress.circularIcon(), Text("还没有录制的MIDI文件")],
      ) : ListView.separated(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final fileName = file.path.split('/').last;
          final isDir = FileSystemEntity.isDirectorySync(file.path);
          return FTile(
            prefix: Icon(
              isDir ? Icons.folder : Icons.music_note,
              color: isDir ? Colors.amber : Colors.blue,
            ),
            title: Text(fileName),
            subtitle: Text(file.path),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 10),
      ),
    );
  }
}
