import 'package:flutter/material.dart';
import 'package:meetup/widgets/widgets.dart';

void main() {
  runApp(MyApp());
}

enum Pages { MainScreen, MeetingRoom }

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Pages currentPage = Pages.MainScreen;
  String currentRoomCode;
  void _handlePageKey(Pages page) {
    setState(() {
      currentPage = page;
    });
  }

  void _roomCode(String roomCode) {
    setState(() {
      currentRoomCode = roomCode;
    });
    print("current room code $currentRoomCode");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet UP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Navigator(
        pages: [
          if (currentPage == Pages.MainScreen)
            MaterialPage(
              name: "Create Room",
              key: CreateRoom.valueKey,
              child: CreateRoom(
                currentPageKey: _handlePageKey,
                roomCode: _roomCode,
              ),
            ),
          if (currentPage == Pages.MeetingRoom)
            MaterialPage(
              name: "Meeting Room",
              key: MeetingRoom.valueKey,
              child: MeetingRoom(
                currentPageKey: _handlePageKey,
                remoteRoomCode: currentRoomCode,
              ),
            ),
        ],
        onPopPage: (route, result) {
          final page = route.settings as MaterialPage;
          if (page.key == MeetingRoom.valueKey) {
            setState(() {
              currentPage = Pages.MainScreen;
            });
          }
          return route.didPop(result);
        },
      ),
    );
  }
}
