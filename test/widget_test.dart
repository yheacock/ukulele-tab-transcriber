import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fft/flutter_fft.dart'; // Assuming you're using flutter_fft

void main() {
  runApp(const MelodyListenerApp());
}

class MelodyListenerApp extends StatelessWidget {
  const MelodyListenerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note Listener',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MelodyListenerPage(),
    );
  }
}

class MelodyListenerPage extends StatefulWidget {
  const MelodyListenerPage({super.key});

  @override
  State<MelodyListenerPage> createState() => _MelodyListenerPageState();
}

class _MelodyListenerPageState extends State<MelodyListenerPage> {
  final FlutterFft _flutterFft = FlutterFft();

  StreamSubscription? _recorderSubscription;
  bool _isListening = false;
  List<String> _detectedNotes = [];

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _flutterFft.stopRecorder();
    super.dispose();
  }

  // Example: Converts frequency to note name (simplified)
  String frequencyToNoteName(double freq) {
    if (freq <= 0) return '--';
    // Basic mapping just for demo, improve for accuracy
    List<String> notes = [
      "C",
      "C#",
      "D",
      "D#",
      "E",
      "F",
      "F#",
      "G",
      "G#",
      "A",
      "A#",
      "B"
    ];
    int noteIndex = ((12 * (log(freq / 440) / log(2))) + 69).round() % 12;
    return notes[noteIndex];
  }

  void _startListening() async {
    if (_isListening) return;

    setState(() {
      _detectedNotes.clear();
      _isListening = true;
    });

    await _flutterFft.startRecorder();

    _recorderSubscription = _flutterFft.onRecorderStateChanged!.listen((data) {
      if (data.length >= 2) {
        double freq = data[1] != null ? (data[1] as num).toDouble() : 0.0;
        if (freq > 0) {
          String note = frequencyToNoteName(freq);
          if (_detectedNotes.isEmpty || _detectedNotes.last != note) {
            setState(() {
              _detectedNotes.add(note);
            });
          }
        }
      }
    });

    // Stop listening automatically after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      _stopListening();
    });
  }

  void _stopListening() async {
    if (!_isListening) return;

    await _flutterFft.stopRecorder();
    await _recorderSubscription?.cancel();

    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Melody Note Listener'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isListening ? null : _startListening,
              child: Text(
                  _isListening ? 'Listening...' : 'Start Listening (10 sec)'),
            ),
            const SizedBox(height: 20),
            const Text('Detected Notes:', style: TextStyle(fontSize: 20)),
            Expanded(
              child: ListView.builder(
                itemCount: _detectedNotes.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(_detectedNotes[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
