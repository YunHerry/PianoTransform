import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:piano_transform/views/BLESearchPage.dart';
import 'package:piano_transform/views/HomePage.dart';
import 'package:piano_transform/views/SettingPage.dart';
import 'midiUtils.dart';

void main() {
  runApp(const Application());
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ApplicationState();
  }
}

class _ApplicationState extends State<Application> {
  int index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: index);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) =>
        FTheme(data: FThemes.zinc.light, child: child!),
    home: FScaffold(
      footer: FBottomNavigationBar(
        index: index,
        onChange: (index) {
          setState(() => this.index = index);
          _pageController.jumpToPage(index);
        },
        children: [
          FBottomNavigationBarItem(
            icon: Icon(FIcons.house),
            label: const Text('Home'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FIcons.layoutGrid),
            label: const Text('Browse'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FIcons.radio),
            label: const Text('Radio'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FIcons.libraryBig),
            label: const Text('Library'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FIcons.search),
            label: const Text('Search'),
          ),
        ],
      ),
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [Homepage(),BLESearchPage(title: "FIRST"),Homepage(),BLESearchPage(title: "FIRST"),SettingPage()],
      ),
    ),
  );
}

