import 'package:flutter/cupertino.dart';
import 'package:forui/forui.dart';
import 'package:piano_transform/SettingsManager.dart';
import 'package:piano_transform/provider/BLEProvider.dart';
import 'package:provider/provider.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool state = false;
  late final FAccordionController _controller;
  late final FContinuousSliderController _continuousSliderController;
  late final FSliderSelection _initialSelection;
  final SettingsManager _settingsManager = SettingsManager();
  @override
  void initState() {
    super.initState();
    _controller = FAccordionController(max: 1);
    _initialSelection = FSliderSelection(max: 1);
    _continuousSliderController = FContinuousSliderController(
      selection: FSliderSelection(max: _settingsManager.volume),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0), // 向下偏移8像素
          child: const Text('设置', style: TextStyle(fontSize: 21)),
        ),
      ),
      child: Column(
        children: [
          FAccordion(
            controller: _controller,
            children: [
              FAccordionItem(
                initiallyExpanded: true,
                title: const Text('主题颜色'),
                child: const Text(
                  'Yes. It includes default styles matching other components.',
                ),
              ),
              FAccordionItem(
                title: const Text('录制'),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FSlider(
                        label: Text('声音录制额外倍率'),
                        controller: _continuousSliderController,
                        marks: [FSliderMark(value: 0, label: Text('0%')),
                          FSliderMark(value: 0.25, tick: false),
                          FSliderMark(value: 0.5),
                          FSliderMark(value: 0.75, tick: false),
                          FSliderMark(value: 1, label: Text('100%')),],
                        onChange: (selection) {
                          _settingsManager.setDouble("volume", selection.offset.max);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              FAccordionItem(
                title: const Text('关于'),
                child: const Text(
                  'Yes. Animations are enabled by default but can be disabled.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
