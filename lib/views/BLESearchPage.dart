import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:forui/forui.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../midiUtils.dart';
import '../provider/BLEProvider.dart';

class BLESearchPage extends StatefulWidget {
  const BLESearchPage({super.key, required this.title});

  final String title;

  @override
  State<BLESearchPage> createState() => _BLESearchPageState();
}

class _BLESearchPageState extends State<BLESearchPage> {
  var logger = Logger();

  @override
  void dispose() {
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: const Text('设备管理', style: TextStyle(fontSize: 21)),
        ),
      ),
      child: Consumer<BLEProvider>(
        builder: (context, provider, child) {
          final scaffoldContext = context;
          print(provider.devices);
          return provider.devices.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [FProgress.circularIcon(), Text("正在扫描设备...")],
                )
              : ListView.separated(
                  itemCount: provider.devices.length,

                  itemBuilder: (context, index) {
                    final device = provider.devices[index];
                    return FTile(
                      prefix: Icon(FIcons.bell),
                      title: Text(
                        device.name.isNotEmpty ? device.name : "(未命名)",
                      ),
                      subtitle: Text("ID: ${device.id}"),
                      suffix: Icon(FIcons.chevronRight),
                      onLongPress: () {
                        HapticFeedback.vibrate();
                        FocusScope.of(context).unfocus();
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
                                onPress: () async {
                                  await provider.connectDeceive(device);
                                  print("完成");
                                  if (!context.mounted) return;
                                  showFToast(
                                    context: scaffoldContext,
                                      duration: Duration(seconds: 2),
                                    alignment: FToastAlignment.topCenter,
                                    icon: const Icon(FIcons.triangleAlert),
                                    title: const Text('连接成功'),
                                  );
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
                );
        },
      ),
    );
  }
}
