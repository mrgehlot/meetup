import 'dart:developer';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:convert';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:archive/archive.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

class InitializeCreatorWebRTC {
  RTCPeerConnection _peerConnection;
  MediaStream _localStream;
  final RTCVideoRenderer _localRenderer;
  final RTCVideoRenderer _remoteRenderer;
  final String roomCode;
  List<String> candidates = [];
  String singleCandidate;
  String rtcString;
  String sdpString;
  MqttBrowserClient client;
  String username = "ngtyutmq";
  String passcode = "LuwKDV6Raabe";
  String mqttClientIdentifer = "meetup";
  InitializeCreatorWebRTC(
      this._localRenderer, this._remoteRenderer, this.roomCode);

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  String generateRandomClientID() {
    DateTime now = new DateTime.now();
    return "public_cloud" + now.toString();
  }

  Future<bool> initializeMQTTClient() async {
    this.client = new MqttBrowserClient(
        "wss://hairdresser.cloudmqtt.com", generateRandomClientID());
    this.client.logging(on: false);
    this.client.port = 36642;
    this.client.keepAlivePeriod = 1600;
    this.client.onDisconnected = onDisconnected;
    this.client.onConnected = onConnected;
    this.client.onSubscribed = onSubscribed;
    // this.client.autoReconnect = true;
    // this.client..websocketProtocols = ["websockets"];
    final connMess = MqttConnectMessage()
        .keepAliveFor(1600)
        // .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);
    // .withClientIdentifier(this.mqttClientIdentifer)
    // .authenticateAs(this.username, this.passcode);
    print('EXAMPLE::Mosquitto client connecting....');
    client.connectionMessage = connMess;

    try {
      await client.connect(this.username, this.passcode);
    } on Exception catch (e) {
      print('EXAMPLE::client exception - $e');
      client.disconnect();
    }

    if (client.connectionStatus.state == MqttConnectionState.connected) {
      print('EXAMPLE::Mosquitto client connected');
      return true;
    } else {
      print(
          'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
      client.disconnect();
      return false;
    }
  }

  void onConnected() {
    print('EXAMPLE::Mosquitto client connected....');
    this.client.subscribe("answer/$roomCode", MqttQos.atLeastOnce);
    this.client.subscribe("send_to_creator/$roomCode", MqttQos.atLeastOnce);
    this.client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload;
      final String pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      if (c[0].topic.toString() == "answer/$roomCode") {
        print(
            'EXAMPLE::Change notification:: topic is ${c[0].topic}, payload is <-- $pt -->');
        setRemoteDescription(pt);
      } else if (c[0].topic.toString() == "send_to_creator/$roomCode") {
        print(
            'EXAMPLE::Change notification:: topic is ${c[0].topic}, payload is <-- $pt -->');
        addCandidates(pt);
      }
    });
    print(
        'EXAMPLE::OnConnected client callback - Client connection was sucessful');
  }

  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
  }

  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    print(client.connectionStatus.returnCode);
    if (client.connectionStatus.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    }
  }

  void publish(String topic, String message, [bool retain]) async {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload,
        retain: retain);
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
        {"url": "stun:stun1.l.google.com:19302"},
        {"url": "stun:stun2.l.google.com:19302"},
        {"url": "stun:stun3.l.google.com:19302"},
        {"url": "stun:stun4.l.google.com:19302"},
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
    pc.onIceConnectionState = (RTCIceConnectionState event) {
      print("onIceConnectionState --> $event");
      // if (event == RTCIceConnectionState.RTCIceConnectionStateCompleted) {}
    };

    pc.onSignalingState = (RTCSignalingState event) {
      if (event == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        print("----------- local offer has been set -------------");
      } else if (event ==
          RTCSignalingState.RTCSignalingStateHaveRemotePrAnswer) {
        debugger();
        print("----------- remote answer has been set -------------");
        // String allOfferCandidates = encrypt(json.encode(this.candidates));
        // publish("send_to_member/$roomCode", allOfferCandidates);
      }
    };

    pc.onAddStream = (stream) {
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  addCandidates(String message) {
    var decryptedCandidate = decrypt(message);
    var allCandidates = json.decode(decryptedCandidate);
    allCandidates.forEach((sessionCandidate) {
      dynamic session = jsonDecode(sessionCandidate);
      print(session['candidate']);
      dynamic candidate = new RTCIceCandidate(
          session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
      _peerConnection.addCandidate(candidate);
      // .then((value) {
      //   if (byProducer) {
      //     String allAnswerCandidates = encrypt(json.encode(this.candidates));
      //     publish("send_to_creator/$roomCode", allAnswerCandidates);
      //   }
      // });
    });
    dynamic lastCandidate = new RTCIceCandidate("","",0);
      _peerConnection.addCandidate(lastCandidate);
  }

  createOffer() async {
    if (candidates.length > 0) candidates.clear();
    print("--------creating offer ----------");
    RTCSessionDescription description = await _peerConnection.createOffer(
      {'offerToReceiveVideo': 1, 'offerToReceiveAudio': 1},
    );
    var session = parse(description.sdp);
    _peerConnection.setLocalDescription(description);
    String offer = encrypt(json.encode(session));
    publish("create_room/$roomCode", offer, true);
  }

  void createAnswer() async {
    print("--------creating answer----------");
    RTCSessionDescription description = await _peerConnection.createAnswer(
      {'offerToReceiveVideo': 1, 'offerToReceiveAudio': 1},
    );
    var session = parse(description.sdp);
    var answer = encrypt(json.encode(session));
    _peerConnection.setLocalDescription(description);
    publish("answer/$roomCode", answer);
  }

  void setRemoteDescription(String remoteSession) async {
    print("--------setting remote description----------");
    var decryptedString = decrypt(remoteSession);
    dynamic session = await jsonDecode(decryptedString);
    String sdp = write(session, null);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, 'answer');
    _peerConnection.setRemoteDescription(description).then((value) {
      String allOfferCandidates = encrypt(json.encode(this.candidates));
      publish("send_to_member/$roomCode", allOfferCandidates);
    });
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
    this.client.disconnect();
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
