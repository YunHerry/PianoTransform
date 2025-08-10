import 'package:flutter/cupertino.dart';
import 'package:forui/forui.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool state = false;
  late final FAccordionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FAccordionController(max: 1);
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0), // 向下偏移8像素
          child: const Text('设置',style: TextStyle(fontSize: 21),),
        ),
      ),
      child: Column(
        children: [
          FAccordion(
            controller: _controller,
            children: [
              FAccordionItem(
                title: const Text('Is it accessible?'),
                child: Column(
                  children: [
                    FSwitch(
                      label: const Text('Airplane Mode'),
                      semanticsLabel: 'Airplane Mode',
                      value: state,
                      onChange: (value) => setState(() => state = value),
                    ),
                  ],
                ),
              ),
              FAccordionItem(
                initiallyExpanded: true,
                title: const Text('Is it Styled?'),
                child: const Text(
                  'Yes. It includes default styles matching other components.',
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
