import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:piano_transform/provider/BLEProvider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class FileListPage extends StatefulWidget {
  const FileListPage({super.key});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage>
    with TickerProviderStateMixin {
  final List<FileSystemEntity> _files = [];
  final List<FPopoverController> _fAccordionControllers = [];

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
      _files
        ..clear()
        ..addAll(fileList);
    });
  }

  @override
  Widget build(BuildContext context) {
    print('FileListPage: initState');
    return FScaffold(
      header: FHeader(
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0), // 向下偏移8像素
          child: const Text('集合', style: TextStyle(fontSize: 21)),
        ),
      ),
      child: _files.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [FProgress.circularIcon(), Text("还没有录制的MIDI文件")],
            )
          : ListView.separated(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                final fileName = file.path.split('/').last;
                final isDir = FileSystemEntity.isDirectorySync(file.path);
                final controller = FPopoverController(vsync: this);
                _fAccordionControllers.add(controller);
                // return ;
                return FPopover(
                  controller: controller,
                  popoverAnchor: Alignment.bottomLeft,
                  childAnchor: Alignment.bottomRight,
                  popoverBuilder: (context, controller) => Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      top: 14,
                      right: 20,
                      bottom: 10,
                    ),
                    child: Column(
                      children: [
                        FButton(
                          style: FButtonStyle.ghost(),
                          onPress: () async {
                              controller.hide();
                              final params = ShareParams(
                                text: '分享音乐midi',
                                files: [XFile(file.path)],
                              );

                              final result = await SharePlus.instance.share(params);

                              if (result.status == ShareResultStatus.success) {
                                if (!context.mounted) return;
                                showFToast(
                                  context: context,
                                  duration: Duration(seconds: 2),
                                  alignment: FToastAlignment.topCenter,
                                  icon: const Icon(FIcons.triangleAlert),
                                  title: const Text('分享成功'),
                                );
                              }
                          },
                          child: const Text('分享'),
                        ),
                        FButton(
                          style: FButtonStyle.ghost(),
                          onPress: () {
                            file.delete(recursive: true).then((_) {
                              if(!context.mounted) return;
                              showFToast(
                                context: context,
                                duration: Duration(seconds: 2),
                                alignment: FToastAlignment.topCenter,
                                icon: const Icon(FIcons.triangleAlert),
                                title: const Text('删除成功'),
                              );
                            }).catchError((err){
                              if(!context.mounted) return;
                              showFToast(
                                context: context,
                                duration: Duration(seconds: 2),
                                alignment: FToastAlignment.topCenter,
                                icon: const Icon(FIcons.triangleAlert),
                                title: const Text('删除失败'),
                              );
                            });
                            controller.hide();
                            _loadFiles();
                          },
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  ),
                  builder: (context, controller, child) => FTile(
                    prefix: Icon(
                      isDir ? Icons.folder : Icons.music_note,
                      color: isDir ? Colors.amber : Colors.blue,
                    ),
                    title: Text(fileName),
                    subtitle: Text(file.path),
                    onLongPress: () {
                      HapticFeedback.vibrate();
                      FocusScope.of(context).unfocus();
                      controller.show();

                    },
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
            ),
    );
  }
}
