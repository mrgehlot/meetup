import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:meetup/video_connection/creator.dart';
import 'package:meetup/video_connection/members.dart';
import '../main.dart';

class MeetingRoom extends StatefulWidget {
  static const valueKey = ValueKey("meeting_room");
  final ValueChanged<Pages> currentPageKey;
  final String remoteRoomCode;

  const MeetingRoom({Key key, this.remoteRoomCode, this.currentPageKey})
      : super(key: key);
  @override
  _MeetingRoomState createState() => _MeetingRoomState();
}

class _MeetingRoomState extends State<MeetingRoom> {
  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();
  bool videoOn = true;
  bool audioOn = true;
  bool remoteConnected = false;
  bool localConnected = false;
  bool codeGenerated = false;
  double otherMembersWidth = 300;
  double bottomBarHeight = 100;
  String roomCode;
  dynamic initializeWebRTC;

  String characters = 'ABCDEFGHIJKLMNOPQRSTUVWXZ';
  Random _rnd = Random();

  String getRandomString(int length) {
    return String.fromCharCodes(Iterable.generate(
        length, (_) => characters.codeUnitAt(_rnd.nextInt(characters.length))));
  }

  @override
  void initState() {
    bool isProducer = widget.remoteRoomCode == null;
    var tempRoomCode = isProducer ? getRandomString(5) : widget.remoteRoomCode;
    initializeWebRTC = isProducer
        ? new InitializeCreatorWebRTC(
            _localRenderer, _remoteRenderer, tempRoomCode)
        : new InitializeMemberWebRTC(
            _localRenderer, _remoteRenderer, tempRoomCode);
    initializeWebRTC.initializeMQTTClient().then((value) {
      if (value) {
        initializeWebRTC.initialConnection(isProducer);
        initializeWebRTC.initRenderers();
      }
    });
    super.initState();
    if (isProducer) {
      setState(() {
        roomCode = tempRoomCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  height: MediaQuery.of(context).size.height - bottomBarHeight,
                  width: MediaQuery.of(context).size.width - otherMembersWidth,
                  color: Colors.black,
                  child: Transform(
                    transform: Matrix4.identity()..rotateY(-pi),
                    alignment: FractionalOffset.center,
                    child: RTCVideoView(
                      _localRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
                Container(
                  color: Colors.black,
                  width: otherMembersWidth,
                  height: MediaQuery.of(context).size.height - bottomBarHeight,
                  child: codeGenerated
                      ? Center(
                          child: SelectableText(
                            "share this code with your members $roomCode",
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Scrollbar(
                          child: ListView(
                            scrollDirection: Axis.vertical,
                            children: [
                              Container(
                                color: Colors.pink,
                                height: 200,
                                child: RTCVideoView(_remoteRenderer),
                              ),
                            ],
                          ),
                        ),
                )
              ],
            ),
            Container(
              height: 100,
              width: MediaQuery.of(context).size.width,
              color: Colors.white,
              child: Row(
                children: [
                  Spacer(
                    flex: 1,
                  ),
                  FloatingActionButton(
                      child: Icon(
                        audioOn
                            ? Icons.mic_external_on
                            : Icons.mic_external_off,
                        size: 20,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          audioOn = !audioOn;
                        });
                        initializeWebRTC.toggleMic(audioOn);
                      }),
                  SizedBox(
                    width: 10,
                  ),
                  FloatingActionButton(
                      backgroundColor: Colors.red,
                      child: Icon(
                        Icons.call_end,
                        size: 20,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        initializeWebRTC.closeAllConnection();
                        setState(() {
                          videoOn = !videoOn;
                        });
                        widget.currentPageKey(Pages.MainScreen);
                      }),
                  SizedBox(
                    width: 10,
                  ),
                  FloatingActionButton(
                      child: Icon(
                        videoOn ? Icons.video_call : Icons.video_call_outlined,
                        size: 30,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        videoOn
                            ? initializeWebRTC.turnOffCamera()
                            : initializeWebRTC.turnOnCamera();
                        setState(() {
                          videoOn = !videoOn;
                        });
                      }),
                  Spacer(
                    flex: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
