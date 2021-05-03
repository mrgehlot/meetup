import 'package:flutter/material.dart';
import '../main.dart';

class CreateRoom extends StatefulWidget {
  static const valueKey = ValueKey("create_room");
  final ValueChanged<Pages> currentPageKey;
  final ValueChanged<String> roomCode;

  const CreateRoom(
      {Key key, @required this.currentPageKey, @required this.roomCode})
      : super(key: key);
  @override
  _CreateRoomState createState() => _CreateRoomState();
}

class _CreateRoomState extends State<CreateRoom> {
  TextEditingController roomCodeController = new TextEditingController();
  bool roomCodeAdded = false;
  String roomCode;
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        alignment: Alignment.center,
        color: Colors.white,
        child: Center(
          child: Row(
            children: [
              Spacer(
                flex: 1,
              ),
              ElevatedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Create a Room"),
                  ),
                  onPressed: () {
                    widget.currentPageKey(Pages.MeetingRoom);
                  }),
              Expanded(
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: roomCodeController,
                  onChanged: (value) {
                    setState(() {
                      roomCodeAdded = value.isNotEmpty ? true : false;
                    });
                  },
                ),
              ),
              ElevatedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Join"),
                  ),
                  onPressed: roomCodeAdded
                      ? () {
                          widget.roomCode(roomCodeController.text);
                          widget.currentPageKey(Pages.MeetingRoom);
                        }
                      : null),
              Spacer(
                flex: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
