import 'package:flutter/cupertino.dart';
import 'package:frosthaven_assistant/forteller/downloader.dart';
import 'package:frosthaven_assistant/services/network/server.dart';
import 'package:frosthaven_assistant/services/network/web_server.dart';
import '../service_locator.dart';
import 'client.dart';
import 'network_info.dart';

enum ClientState{
  connected,
  disconnected,
  connecting
}

class Network {
  final Server server = Server();
  final WebServer webServer = WebServer();
  final Downloader downloader = Downloader();
  final NetworkInformation networkInfo = NetworkInformation();
  final networkMessage = ValueNotifier<String>("");

  bool appInBackground = false;
  bool clientDisconnectedWhileInBackground = false;
}