import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:convert';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:archive/archive.dart';
import 'package:web_socket_channel/html.dart';

class InitializeWebRTC {
  RTCPeerConnection _peerConnection;
  MediaStream _localStream;
  final RTCVideoRenderer _localRenderer;
  final RTCVideoRenderer _remoteRenderer;
  final String roomCode;
  final bool offerFlag;
  List<String> candidates = [];
  String singleCandidate;
  String rtcString;
  String sdpString;
  String serverHost = "localhost";
  InitializeWebRTC(
      this._localRenderer, this._remoteRenderer, this.roomCode, this.offerFlag);

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  signalingListeners(bool isOffer) async {
    if (isOffer) {
      print("into signaling when creating offer");
      print(this.roomCode);
      //When creating createOffer()
      // var answerChannel = HtmlWebSocketChannel.connect(
      //     Uri.parse('ws://$serverHost:8765/answer/' + this.roomCode));
      // answerChannel.stream.listen((message) {
      //   print("Oh just got the answer!!");
      //   setRemoteDescription(message.toString(), false);
      // });
    } else {
      print("into signaling when creating answer");
      //When creating createAnswer()
      var roomInfoChannel = HtmlWebSocketChannel.connect(
          Uri.parse('ws://$serverHost:8765/room_info'));
      roomInfoChannel.sink.add(this.roomCode);
      roomInfoChannel.stream.listen((event) {
        print("got offer sdp");
        setRemoteDescription(event.toString(), true);
        // roomInfoChannel.sink.close();
      });
    }
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
        // {"url": "stun:stun1.l.google.com:19302"},
        // {"url": "stun:stun2.l.google.com:19302"},
        // {"url": "stun:stun3.l.google.com:19302"},
        // {"url": "stun:stun4.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };
    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);
    pc.onIceCandidate = (event) {
      if (event.candidate != null) {
        print("candidate added");
        candidates.add(
          json.encode(
            {
              'candidate': event.candidate.toString(),
              'sdpMid': event.sdpMid.toString(),
              'sdpMlineIndex': event.sdpMlineIndex
            },
          ),
        );
      }
    };
    pc.onIceConnectionState = (event) {
      print("on Ice Connection state -----> $event");
    };

    pc.onSignalingState = (RTCSignalingState event) {
      print("on signaling state ---> $event");
      if (event == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        print("----------- when state have local offer -------------");
        print(this.roomCode);
        
        var answerChannel = new HtmlWebSocketChannel.connect(
            Uri.parse('ws://$serverHost:8765/answer/' + this.roomCode));
        answerChannel.sink.add("hello world");
        answerChannel.stream.listen((message) {
          print("Oh just got the answer!!");
          // setRemoteDescription(message.toString(), false);
        });
      } else if (event == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        createAnswer();
      } else if (event ==
          RTCSignalingState.RTCSignalingStateHaveLocalPrAnswer) {
             print("----------- when state have local answer -------------");
        var candidateChannel = HtmlWebSocketChannel.connect(
            Uri.parse('ws://$serverHost:8765/send_candidate/' + this.roomCode));
        candidateChannel.stream.listen((message) {
          print("Oh just got the candidate!!");
          var decryptedCandidate = decrypt(message);
          var allCandidates = json.decode(decryptedCandidate);
          allCandidates.forEach((sessionCandidate) async {
            dynamic session = await jsonDecode(sessionCandidate);
            print(session['candidate']);
            dynamic candidate = new RTCIceCandidate(session['candidate'],
                session['sdpMid'], session['sdpMlineIndex']);
            await _peerConnection.addCandidate(candidate);
          });

          String allOfferCandidates = encrypt(json.encode(this.candidates));
          var senderChannel = HtmlWebSocketChannel.connect(Uri.parse(
              'ws://$serverHost:8765/set_candidate/' + this.roomCode));
          senderChannel.sink.add(allOfferCandidates);
          senderChannel.sink.close();
        });
      } else if (event ==
          RTCSignalingState.RTCSignalingStateHaveRemotePrAnswer) {
        String allCandidates = encrypt(json.encode(this.candidates));
        var senderChannel = HtmlWebSocketChannel.connect(
            Uri.parse('ws://$serverHost:8765/send_candidate/' + this.roomCode));
        senderChannel.sink.add(allCandidates);
        senderChannel.sink.close();

        var candidateChannel = HtmlWebSocketChannel.connect(
            Uri.parse('ws://$serverHost:8765/set_candidate/' + this.roomCode));
        candidateChannel.stream.listen((message) {
          print("Oh just got the candidate!!");
          var decryptedCandidate = decrypt(message);
          var allCandidates = json.decode(decryptedCandidate);
          allCandidates.forEach((sessionCandidate) async {
            dynamic session = await jsonDecode(sessionCandidate);
            print(session['candidate']);
            dynamic candidate = new RTCIceCandidate(session['candidate'],
                session['sdpMid'], session['sdpMlineIndex']);
            await _peerConnection.addCandidate(candidate);
          });
        });
      }
    };

    pc.onAddStream = (stream) {
      print("addStream: " + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  createOffer() async {
    print(
        "------------------step1  create an offer ---------------------------------------");
    RTCSessionDescription description = await _peerConnection.createOffer(
      {'offerToReceiveVideo': 1, 'offerToReceiveAudio': 1},
    );
    var session = parse(description.sdp);
    _peerConnection.setLocalDescription(description);
    String offer = encrypt(json.encode(session));
    String data = json.encode({"room_code": this.roomCode, "offer": offer});
    var channel = HtmlWebSocketChannel.connect(
        Uri.parse('ws://$serverHost:8765/create_room'));
    channel.sink.add(data);
  }

  void createAnswer() async {
    print("--------creating answer----------");
    RTCSessionDescription description = await _peerConnection.createAnswer(
      {'offerToReceiveVideo': 1, 'offerToReceiveAudio': 1},
    );
    var session = parse(description.sdp);
    var answer = encrypt(json.encode(session));
    _peerConnection.setLocalDescription(description);
    var channel = HtmlWebSocketChannel.connect(
        Uri.parse('ws://$serverHost:8765/answer/' + this.roomCode));
    channel.sink.add(answer);
    // channel.sink.close();
  }

  void setRemoteDescription(String remoteSession, bool isOffer) async {
    var decryptedString = decrypt(remoteSession);
    dynamic session = await jsonDecode(decryptedString);
    String sdp = write(session, null);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, isOffer ? 'offer' : 'answer');
    print("remote description");
    _peerConnection.setRemoteDescription(description);
  }

  initialConnection(bool isProducer) async {
    _peerConnection = await _createPeerConnection();
    turnOnCamera();
    if (isProducer) {
      createOffer();
    }
  }

  void turnOnCamera() async {
    _localStream = await getUserMedia();
    _peerConnection.addStream(_localStream);
  }

  void turnOffCamera() {
    _localStream.getVideoTracks().forEach((element) {
      element.stop();
    });
  }

  void toggleMic(bool value) {
    if (_localStream != null) {
      _localStream.getAudioTracks()[0].enabled = value ? true : false;
    }
  }

  void closeAllConnection() {
    _peerConnection.close();
    _localStream.getTracks().forEach((element) {
      element.stop();
    });
  }

  getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = stream;
    // _localRenderer.mirror = true;
    return stream;
  }

  encrypt(String rtcString) {
    return base64.encode(GZipEncoder().encode(utf8.encode(rtcString)));
  }

  decrypt(String rtcString) {
    return utf8.decode(GZipDecoder().decodeBytes(base64.decode(rtcString)));
  }
}
