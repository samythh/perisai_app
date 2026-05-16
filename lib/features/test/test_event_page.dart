import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TestEventPage extends StatelessWidget {
  const TestEventPage({super.key});

  static const MethodChannel _channel = MethodChannel(
    'com.perisai.app/service_control',
  );

  Future<void> _sendTestEvent() async {
    try {
      await _channel.invokeMethod('sendTestEvent');
    } catch (e) {
      debugPrint('PERISAI TEST: Error → $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Event Channel')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _sendTestEvent,
          icon: const Icon(Icons.send),
          label: const Text('Kirim Dummy Event ke Flutter'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ),
    );
  }
}
