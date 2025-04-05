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
  String topic = 'esp32';
  String responseTopic = 'esp32';

  @override
  void initState() {
    super.initState();
    connectToBroker();
  }

  Future<void> connectToBroker() async {
    String host = 'mqtt.eclipseprojects.io';
    String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb) {
      client = MqttBrowserClient('wss://$host/mqtt', clientId);
      //client = MqttServerClient.withPort(host, clientId, 80); // WebSocket port
      client.port = 443;
      client.websocketProtocols = ['mqtt'];
    } else {
      client = MqttServerClient.withPort(host, clientId, 1883); // Standard MQTT port
    }
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;

  client.connectionMessage = MqttConnectMessage()
      .withClientIdentifier('flutter_client')
      .startClean()
      .withWillQos(MqttQos.atMostOnce);

    try {
      await client.connect();
    } catch (e) {
      setState(() {
        status = 'Connection failed: $e';
      });
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() {
        status = 'Connected';
      });
      client.subscribe(responseTopic, MqttQos.atMostOnce);
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final payload = (c[0].payload as MqttPublishMessage).payload.message;
        final message = String.fromCharCodes(payload);
        setState(() {
          status = 'ESP32 Response: $message';
        });
      });
    } else {
      setState(() {
        status = 'Connection failed: ${client.connectionStatus}';
      });
      client.disconnect();
    }
  }

  void sendPing() {
    final builder = MqttClientPayloadBuilder();
    builder.addString('ping');
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    setState(() {
      status = 'Ping sent...';
    });
  }

  void onDisconnected() {
    setState(() {
      status = 'Disconnected';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32 Ping Button')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: status.startsWith('Connected') || status.startsWith('ESP32') ? sendPing : null,
              child: const Text('Ping ESP32'),
            ),
          ],
        ),
      ),
    );
  }
}
