import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:mqtt_client/mqtt_browser_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MqttButtonPage(),
    );
  }
}

class MqttButtonPage extends StatefulWidget {
  const MqttButtonPage({super.key});
  @override
  State<MqttButtonPage> createState() => _MqttButtonPageState();
}

class _MqttButtonPageState extends State<MqttButtonPage> {
  late MqttClient client;
  String status = 'Disconnected';
  final String topic = 'esp32';
  final String responseTopic = 'esp32';

  @override
  void initState() {
    super.initState();
    connectToBroker();
  }

  Future<void> connectToBroker() async {
    String host = 'mqtt.eclipseprojects.io';
    String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb) {
      client = MqttBrowserClient('wss://$host/mqtt', clientId)
        ..port = 443
        ..websocketProtocols = ['mqtt'];
    } else {
      client = MqttServerClient.withPort(host, clientId, 1883);
    }

    client
      ..logging(on: true)
      ..keepAlivePeriod = 20
      ..onDisconnected = onDisconnected
      ..connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

    try {
      await client.connect();
    } catch (e) {
      setState(() => status = 'Connection failed: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() => status = 'Connected');
      client.subscribe(responseTopic, MqttQos.atMostOnce);
      client.updates!.listen((msgs) {
        final payload =
            (msgs[0].payload as MqttPublishMessage).payload.message;
        final message = String.fromCharCodes(payload);
        setState(() => status = 'ESP32 Response: $message');
      });
    } else {
      setState(() => status = 'Connection failed: ${client.connectionStatus}');
      client.disconnect();
    }
  }

  void sendSound(String sound) {
    final builder = MqttClientPayloadBuilder()..addString(sound);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    setState(() => status = 'Sent "$sound"');
  }

  void onDisconnected() {
    setState(() => status = 'Disconnected');
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled =
        status.startsWith('Connected') || status.startsWith('ESP32');

    return Scaffold(
      appBar: AppBar(title: const Text('ESP32 Sound Board')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: enabled ? () => sendSound('flavor') : null,
                  child: const Text("That's Flavor Town"),
                ),
                ElevatedButton(
                  onPressed: enabled ? () => sendSound('woo') : null,
                  child: const Text('Woo'),
                ),
                ElevatedButton(
                  onPressed: enabled ? () => sendSound('bonk') : null,
                  child: const Text('Bonk'),
                ),
                ElevatedButton(
                  onPressed: enabled ? () => sendSound('ugh') : null,
                  child: const Text('Ugh'),
                ),
                ElevatedButton(
                  onPressed: enabled ? () => sendSound('scooby') : null,
                  child: const Text('Scooby'),
                ),
                ElevatedButton(
                  onPressed: enabled ? () => sendSound('alrighty then') : null,
                  child: const Text('Alrighty Then'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
