import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/agora_constants.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelName;

  const VideoCallScreen({super.key, required this.channelName});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final List<int> _remoteUids = [];
  bool _localUserJoined = false;
  bool _muted = false;
  bool _videoDisabled = false;
  bool _isReconnecting = false;
  bool _isDisconnected = false;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<String> _fetchToken() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate-agora-token',
        body: {'channelName': widget.channelName, 'uid': 0},
      );
      final token = response.data['token'] as String?;
      if (token == null) throw Exception('Token not returned from server');
      return token;
    } catch (e) {
      return AgoraConstants.tempToken;
    }
  }

  Future<void> initAgora() async {
    try {
      await [Permission.microphone, Permission.camera].request();
    } catch (e) {
      debugPrint("Warning: Could not request permissions: $e");
    }

    final token = await _fetchToken();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: AgoraConstants.appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          setState(() {
            _localUserJoined = true;
            _isReconnecting = false;
            _isDisconnected = false;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          setState(() {
            if (!_remoteUids.contains(remoteUid)) {
              _remoteUids.add(remoteUid);
            }
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          setState(() {
            _remoteUids.remove(remoteUid);
          });
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) async {
          final newToken = await _fetchToken();
          await _engine.renewToken(newToken);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[Agora Error] $err: $msg');
        },
        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state,
            ConnectionChangedReasonType reason) {
          debugPrint('[ConnectionStateChanged] state: $state, reason: $reason');
          if (state == ConnectionStateType.connectionStateReconnecting) {
            setState(() {
              _isReconnecting = true;
              _isDisconnected = false;
            });
          } else if (state == ConnectionStateType.connectionStateFailed) {
            setState(() {
              _isReconnecting = false;
              _isDisconnected = true;
              _localUserJoined = false;
              _remoteUids.clear();
            });
          } else if (state == ConnectionStateType.connectionStateConnected) {
            setState(() {
              _isReconnecting = false;
              _isDisconnected = false;
            });
          }
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    try {
      await _engine.startPreview();
    } catch (e) {
      debugPrint('Camera preview failed: $e');
      setState(() {
        _videoDisabled = true;
      });
    }

    await _joinChannel(token);
  }

  Future<void> _joinChannel(String token) async {
    await _engine.joinChannel(
      token: token,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> _rejoin() async {
    setState(() {
      _isDisconnected = false;
      _isReconnecting = true;
    });
    try {
      final token = await _fetchToken();
      await _joinChannel(token);
    } catch (e) {
      debugPrint('Rejoin failed: $e');
      setState(() {
        _isReconnecting = false;
        _isDisconnected = true;
      });
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  void _onToggleMute() {
    setState(() {
      _muted = !_muted;
    });
    _engine.muteLocalAudioStream(_muted);
  }

  void _onToggleVideo() {
    setState(() {
      _videoDisabled = !_videoDisabled;
    });
    _engine.muteLocalVideoStream(_videoDisabled);
  }

  @override
  Widget build(BuildContext context) {
    if (AgoraConstants.appId == 'YOUR_AGORA_APP_ID') {
      return Scaffold(
        appBar: AppBar(title: const Text('Agora Error')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Agora App ID is missing! Please update lib/core/constants/agora_constants.dart',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _remoteVideo()),
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 120,
                  height: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: _localUserJoined && !_videoDisabled
                            ? AgoraVideoView(
                                controller: VideoViewController(
                                  rtcEngine: _engine,
                                  canvas: const VideoCanvas(uid: 0),
                                ),
                              )
                            : Icon(
                                _videoDisabled
                                    ? Icons.videocam_off
                                    : Icons.person,
                                color: Colors.white54,
                                size: 40,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isReconnecting || _isDisconnected) _reconnectOverlay(),
          _toolbar(),
        ],
      ),
    );
  }

  Widget _reconnectOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isReconnecting) ...[
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Reconnecting...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ] else ...[
              const Icon(Icons.wifi_off, color: Colors.white54, size: 72),
              const SizedBox(height: 20),
              const Text(
                'Connection Lost',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your internet connection\nand rejoin the meeting.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _rejoin,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Rejoin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUids.isNotEmpty) {
      if (_remoteUids.length == 1) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUids.first),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      } else {
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.0,
          ),
          itemCount: _remoteUids.length,
          itemBuilder: (context, index) {
            return AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUids[index]),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            );
          },
        );
      }
    } else {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white54),
          SizedBox(height: 20),
          Text(
            'Waiting for others to join...',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  Widget _toolbar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RawMaterialButton(
              onPressed: _onToggleMute,
              shape: const CircleBorder(),
              elevation: 2.0,
              fillColor: _muted ? Colors.blueAccent : Colors.white,
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                _muted ? Icons.mic_off : Icons.mic,
                color: _muted ? Colors.white : Colors.blueAccent,
                size: 20.0,
              ),
            ),
            const SizedBox(width: 20),
            RawMaterialButton(
              onPressed: () => _onCallEnd(context),
              shape: const CircleBorder(),
              elevation: 2.0,
              fillColor: Colors.redAccent,
              padding: const EdgeInsets.all(15.0),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 35.0,
              ),
            ),
            const SizedBox(width: 20),
            RawMaterialButton(
              onPressed: _onToggleVideo,
              shape: const CircleBorder(),
              elevation: 2.0,
              fillColor: _videoDisabled ? Colors.blueAccent : Colors.white,
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                _videoDisabled ? Icons.videocam_off : Icons.videocam,
                color: _videoDisabled ? Colors.white : Colors.blueAccent,
                size: 20.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
