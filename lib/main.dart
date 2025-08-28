import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fft/flutter_fft.dart';

void main() {
  runApp(const MelodyToUkuleleTabApp());
}

class MelodyToUkuleleTabApp extends StatelessWidget {
  const MelodyToUkuleleTabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ukulele Tab Sheet',
      theme: ThemeData(
        primaryColor: const Color(0xFF4CAF50), // Primary Green
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Light Gray
        textTheme: const TextTheme(
          titleLarge:
              TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          bodyMedium: TextStyle(color: Color(0xFF333333), fontSize: 16),
        ),
      ),
      home: const MelodyToTabPage(),
    );
  }
}

class MelodyToTabPage extends StatefulWidget {
  const MelodyToTabPage({super.key});

  @override
  State<MelodyToTabPage> createState() => _MelodyToTabPageState();
}

class _MelodyToTabPageState extends State<MelodyToTabPage> {
  final FlutterFft _flutterFft = FlutterFft();

  static const Map<int, int> openStrings = {
    4: 67, // G4
    3: 60, // C4
    2: 64, // E4
    1: 69, // A4
  };
  static const int maxFret = 12;
  final Map<int, List<StringFret>> midiToStringFrets = {};

  List<TabNote> _tabNotes = [];
  double _currentFrequency = 0.0;
  int? _currentMidiNote;
  String _currentNoteName = '--';
  StreamSubscription? _recorderSubscription;

  Timer? _samplingTimer;
  double? _latestFrequency;
  bool _isListening = false;

  static const Duration windowDuration = Duration(milliseconds: 250);
  static const int maxTabNotes = 200;

  @override
  void initState() {
    super.initState();
    populateMidiToStringFrets();
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _flutterFft.stopRecorder();
    _samplingTimer?.cancel();
    super.dispose();
  }

  void populateMidiToStringFrets() {
    midiToStringFrets.clear();
    openStrings.forEach((stringNum, openMidi) {
      for (int fret = 0; fret <= maxFret; fret++) {
        int midiNote = openMidi + fret;
        midiToStringFrets.putIfAbsent(midiNote, () => []);
        midiToStringFrets[midiNote]!.add(StringFret(stringNum, fret));
      }
    });
  }

  Future<void> _startListening() async {
    await _flutterFft.startRecorder();
    _isListening = true;

    _recorderSubscription = _flutterFft.onRecorderStateChanged!.listen((data) {
      if (data.length >= 2) {
        double freq = (data[1] as num).toDouble();
        if (freq > 0) _latestFrequency = freq;
      }
    });

    _samplingTimer = Timer.periodic(windowDuration, (_) {
      if (_latestFrequency != null) {
        _processFrequency(_latestFrequency!);
      }
    });
    setState(() {});
  }

  Future<void> _stopListening() async {
    _isListening = false;
    _latestFrequency = null;
    _samplingTimer?.cancel();
    await _flutterFft.stopRecorder();
    _recorderSubscription?.cancel();
    setState(() {});
  }

  void _processFrequency(double freq) {
    int midi = _frequencyToMidi(freq);
    String noteName = _midiToNoteName(midi);

    final newNotes = _midiNoteToTabNotes(midi);
    if (newNotes.isNotEmpty) {
      setState(() {
        for (var note in newNotes) {
          // Only add the note if it's not the same as the last one
          if (_tabNotes.isEmpty ||
              _tabNotes.last.stringNum != note.stringNum ||
              _tabNotes.last.fret != note.fret) {
            _tabNotes.add(note);
          }

          if (_tabNotes.length > maxTabNotes) _tabNotes.removeAt(0);
        }

        _currentFrequency = freq;
        _currentMidiNote = midi;
        _currentNoteName = noteName;
      });
    } else {
      setState(() {
        _currentFrequency = freq;
        _currentMidiNote = midi;
        _currentNoteName = noteName;
      });
    }
  }

  int _frequencyToMidi(double freq) =>
      (69 + 12 * (log(freq / 440) / ln2)).round();

  String _midiToNoteName(int midiNote) {
    final notes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];
    final octave = (midiNote ~/ 12) - 1;
    return '${notes[midiNote % 12]}$octave';
  }

  List<TabNote> _midiNoteToTabNotes(int midiNote) {
    final positions = midiToStringFrets[midiNote];
    if (positions == null || positions.isEmpty) return [];

    int? preferredString =
        _tabNotes.isNotEmpty ? _tabNotes.last.stringNum : null;

    // Filter positions with fret <= 5
    final lowFretPositions = positions.where((pos) => pos.fret <= 5).toList();

    StringFret chosenPos;

    if (lowFretPositions.isNotEmpty) {
      // Try to pick the same string as last note
      if (preferredString != null) {
        chosenPos = lowFretPositions.firstWhere(
            (pos) => pos.stringNum == preferredString,
            orElse: () =>
                lowFretPositions.reduce((a, b) => a.fret < b.fret ? a : b));
      } else {
        // No previous string, pick lowest fret
        chosenPos = lowFretPositions.reduce((a, b) => a.fret < b.fret ? a : b);
      }
    } else {
      // No positions <= 5, pick lowest fret overall
      chosenPos = positions.reduce((a, b) => a.fret < b.fret ? a : b);
    }

    return [TabNote(chosenPos.stringNum, chosenPos.fret, DateTime.now())];
  }

  void _clearTabs() => setState(() => _tabNotes.clear());

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF4CAF50);
    const highlightOrange = Color(0xFFFFA726);
    const accentGray = Color(0xFF333333);
    const cardWhite = Color(0xFFFFFFFF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ukulele Tab Sheet'),
        centerTitle: true,
        backgroundColor: primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: cardWhite,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Column(
                  children: [
                    Text(_currentNoteName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                            )),
                    const SizedBox(height: 6),
                    Text(
                      _currentFrequency > 0
                          ? '${_currentFrequency.toStringAsFixed(2)} Hz'
                          : '-- Hz',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: highlightOrange,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GestureDetector(
                onTapDown: (details) {
                  final tapPos = details.localPosition;
                  final painter = UkuleleTabPainter(
                      _tabNotes, primaryGreen, highlightOrange, accentGray);
                  final rects = painter.getNoteRects();
                  for (int i = 0; i < rects.length; i++) {
                    if (rects[i].contains(tapPos)) {
                      setState(() => _tabNotes.removeAt(i));
                      break;
                    }
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentGray.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: CustomPaint(
                      painter: UkuleleTabPainter(
                          _tabNotes, primaryGreen, highlightOrange, accentGray),
                      size: Size(max(1000, _tabNotes.length * 50.0 + 300), 250),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _clearTabs,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Tab'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isListening ? null : _startListening,
                  child: const Text('Start Listening'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: highlightOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isListening ? _stopListening : null,
                  child: const Text('Stop Listening'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGray,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _isListening ? highlightOrange : accentGray,
        foregroundColor: Colors.white,
        icon: Icon(_isListening ? Icons.mic : Icons.mic_off),
        label: Text(_isListening ? 'Listening' : 'Stopped'),
        onPressed: _isListening ? _stopListening : _startListening,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// --- Models ---

class StringFret {
  final int stringNum;
  final int fret;
  StringFret(this.stringNum, this.fret);
}

class TabNote {
  final int stringNum;
  final int fret;
  final DateTime timestamp;
  TabNote(this.stringNum, this.fret, this.timestamp);
}

// --- Painter ---

class UkuleleTabPainter extends CustomPainter {
  final List<TabNote> tabNotes;
  final Color primary;
  final Color highlight;
  final Color accent;

  final double stringSpacing = 30;
  final double leftPadding = 60;
  final double topPadding = 30;
  final double noteSpacing = 50;
  final int notesPerRow = 16;
  final double groupSpacing = 30 * 4 + 50;
  final int totalStrings = 4;

  UkuleleTabPainter(this.tabNotes, this.primary, this.highlight, this.accent);

  List<Rect> getNoteRects() {
    List<Rect> rects = [];
    for (int i = 0; i < tabNotes.length; i++) {
      final note = tabNotes[i];
      int groupIndex = i ~/ notesPerRow;
      int stringIndex = totalStrings - note.stringNum;
      double y =
          topPadding + groupIndex * groupSpacing + stringIndex * stringSpacing;
      double x = leftPadding + (i % notesPerRow) * noteSpacing;
      rects.add(Rect.fromCenter(center: Offset(x, y), width: 30, height: 30));
    }
    return rects;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paintString = Paint()
      ..color = accent
      ..strokeWidth = 3;
    final highlightPaint = Paint()..color = highlight.withOpacity(0.25);

    final textPainter = TextPainter(
        textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    int totalGroups = (tabNotes.length / notesPerRow).ceil();
    totalGroups = totalGroups > 0 ? totalGroups : 1;

    // Draw strings
    for (int group = 0; group < totalGroups; group++) {
      double groupTop = topPadding + group * groupSpacing;
      for (int i = 0; i < totalStrings; i++) {
        double y = groupTop + i * stringSpacing;
        canvas.drawLine(
            Offset(leftPadding, y), Offset(size.width, y), paintString);

        final stringText = TextSpan(
          text: 'String ${totalStrings - i}',
          style: TextStyle(
              color: accent, fontWeight: FontWeight.w600, fontSize: 14),
        );
        textPainter.text = stringText;
        textPainter.layout();
        textPainter.paint(canvas, Offset(leftPadding - 35, y - 10));
      }
    }

    // Draw notes
    for (int i = 0; i < tabNotes.length; i++) {
      final note = tabNotes[i];
      int groupIndex = i ~/ notesPerRow;
      int stringIndex = totalStrings - note.stringNum;
      double y =
          topPadding + groupIndex * groupSpacing + stringIndex * stringSpacing;
      double x = leftPadding + (i % notesPerRow) * noteSpacing;

      if (i == tabNotes.length - 1)
        canvas.drawCircle(Offset(x, y), 14, highlightPaint);

      final fretText = TextSpan(
        text: '${note.fret}',
        style: TextStyle(
            color: primary, fontWeight: FontWeight.bold, fontSize: 18),
      );
      textPainter.text = fretText;
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant UkuleleTabPainter oldDelegate) {
    if (oldDelegate.tabNotes.length != tabNotes.length) return true;
    for (int i = 0; i < tabNotes.length; i++) {
      if (oldDelegate.tabNotes[i].stringNum != tabNotes[i].stringNum ||
          oldDelegate.tabNotes[i].fret != tabNotes[i].fret) return true;
    }
    return false;
  }
}
