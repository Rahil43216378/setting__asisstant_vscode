// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'splash_screen.dart';

 
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SettingsHelperApp());
}

class SettingsHelperApp extends StatelessWidget {
  const SettingsHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       debugShowCheckedModeBanner: false,
      title: 'Smart Settings Helper',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const HomePage(),

      
      );
         
    
      
  }
}

/// ---------- Splash: check consent ----------
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  bool? consentGiven;

  @override
  void initState() {
    super.initState();
    checkConsent();
  }

  Future<void> checkConsent() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? c = prefs.getBool('consent');
    setState(() {
      consentGiven = c;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (consentGiven == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (consentGiven == true) {
      return const HomePage();
    } else {
      return const ConsentPage();
    }
  }
}

/// ---------- Consent & Privacy Screen ----------
class ConsentPage extends StatelessWidget {
  const ConsentPage({Key? key}) : super(key: key);

  Future<void> giveConsent(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent', true);
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
  }

  Future<void> declineConsent(BuildContext context) async {
    // show limited mode option
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limited Access'),
        content: const Text('If you decline, the app will work in limited guidance-only mode without microphone. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            Navigator.pop(context);
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setBool('consent', false);
            if (!context.mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage(limitedMode: true)));
          }, child: const Text('Proceed Limited')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consent & Privacy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'Welcome to Smart Settings Helper.\n\n'
                  'This app listens only to your commands (voice or text) to help you reach the correct phone Settings screen. '
                  'No voice or text is sent to any server. All processing is local and data stays on your device. '
                  'We only open settings screens — we do not change system toggles silently. You will always confirm changes yourself.',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => giveConsent(context),
              child: const Text('I Agree — Enable App Features'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => declineConsent(context),
              child: const Text('I Decline (Limited Mode)'),
            )
          ],
        ),
      ),
    );
  }
}

/// ---------- Home Page (Main app) ----------
class HomePage extends StatefulWidget {
  final bool limitedMode;
  const HomePage({Key? key, this.limitedMode = false}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  late stt.SpeechToText _speech;
  bool _listening = false;
  String _lastWords = '';
  String _detectedLocale = 'en';
  bool _speechAvailable = false;
  bool _consent = true;

  // Simple keyword maps (extend these lists as you like)
  final Map<String, Map<String, String>> languageKeywords = {
    'en': {
      'wifi': 'wifi',
      'internet': 'wifi',
      'bluetooth': 'bluetooth',
      'location': 'location',
      'gps': 'location',
      'rotate': 'display',
      'brightness': 'display',
      'sound': 'sound',
      'volume': 'sound',
      'battery': 'battery',
      'storage': 'storage',
      'app': 'apps',
      'update': 'system_update',
      'clear cache': 'storage',
      'developer options': 'developer_options',
      'touch': 'display',
      'screen': 'display',
    },
    'hi': {
      'वाइफाई': 'wifi',
      'वाईफ़ाई': 'wifi',
      'wifi': 'wifi',
      'इंटरनेट': 'wifi',
      'ब्लूटूथ': 'bluetooth',
      'लोकेशन': 'location',
      'जीपीएस': 'location',
      'रोटेट': 'display',
      'ब्राइटनेस': 'display',
      'आवाज़': 'sound',
      'वॉल्यूम': 'sound',
      'बैटरी': 'battery',
      'स्टोरेज': 'storage',
      'ऐप': 'apps',
      'अपडेट': 'system_update',
      'क्लियर कैश': 'storage',
      'डेवेलपर': 'developer_options',
      'टच': 'display',
      'स्क्रीन': 'display',
    },
    // short samples for other langs; extend as needed
    'ja': { 'ワイファイ': 'wifi', 'ブルートゥース': 'bluetooth' },
    'ar': { 'واي': 'wifi', 'واي فاي': 'wifi', 'بلوتوث': 'bluetooth' },
    'ru': { 'вайфай': 'wifi', 'bluetooth': 'bluetooth' },
    'mr': { 'वायफाय': 'wifi' },
    'gu': { 'વાઈફાઇ': 'wifi' },
    'pa': { 'ਵਾਈਫਾਈ': 'wifi' },
    'ur': { 'وائی فائی': 'wifi' },
    'ne': { 'वाइफाइ': 'wifi' },
    'ta': { 'வைஃபை': 'wifi' },
    'te': { 'వైఫై': 'wifi' },
    'ml': { 'വൈഫൈ': 'wifi' },
    'sa': { 'वायफाय': 'wifi' },
  };

  final Map<String, Map<String, String>> guides = {
    'wifi': {
      'en': 'Open Wi-Fi settings. Toggle Wi-Fi off and on, pick a network and connect. If needed, forget & re-add.',
      'hi': 'Wi-Fi सेटिंग्स खोलें। Wi-Fi बंद करके फिर चालू करें, नेटवर्क चुनें और कनेक्ट करें। आवश्यकता हो तो forget करके फिर जोड़ें।'
    },
    'bluetooth': {
      'en': 'Open Bluetooth settings. Turn Bluetooth off/on, check paired devices and reconnect.',
      'hi': 'Bluetooth सेटिंग्स खोलें। Bluetooth बंद करके फिर चालू करें, paired devices चेक करें।'
    },
    'location': {
      'en': 'Open Location settings. Enable location/GPS or set high accuracy.',
      'hi': 'लोकेशन सेटिंग्स खोलें। लोकेशन (GPS) चालू करें या high accuracy चुनें।'
    },
    'display': {
      'en': 'Open Display settings. Adjust brightness or auto-rotate here.',
      'hi': 'Display सेटिंग्स खोलें। ब्राइटनेस बदलें या auto-rotate को ऑन/ऑफ करें।'
    },
    'sound': {
      'en': 'Open Sound settings. Adjust ring volume and Do Not Disturb.',
      'hi': 'Sound सेटिंग्स खोलें। रिंग वॉल्यूम और DND सेटिंग्स बदलें।'
    },
    'battery': {
      'en': 'Open Battery settings. Check battery saver and app battery usage.',
      'hi': 'Battery सेटिंग्स खोलें। Battery saver और app usage चेक करें।'
    },
    'storage': {
      'en': 'Open Storage settings. Clear cache or free up space.',
      'hi': 'Storage खोलें। Cache साफ करें या जगह खाली करें।'
    },
    'apps': {
      'en': 'Open Apps / App info. Select an app to change permissions or clear cache.',
      'hi': 'Apps खोलें। किसी app का permissions या cache यहाँ बदलें।'
    },
    'system_update': {
      'en': 'This might be solved by updating system software. Open System Update?',
      'hi': 'यह समस्या सिस्टम अपडेट से ठीक हो सकती है। System Update खोलें?'
    },
    'developer_options': {
      'en': 'Developer Options include animation and transition speeds (use with caution).',
      'hi': 'Developer Options में animation speed मिलती है — सावधानी से बदलें।'
    },
    'not_found': {
      'en': 'Feature not found on this device. It may be restricted by your phone model or Android version.',
      'hi': 'यह विकल्प आपके डिवाइस पर उपलब्ध नहीं है। यह आपके फोन या Android संस्करण पर निर्भर कर सकता है।'
    },
  };

  final Map<String, String> actionIntents = {
    'wifi': 'android.settings.WIFI_SETTINGS',
    'bluetooth': 'android.settings.BLUETOOTH_SETTINGS',
    'location': 'android.settings.LOCATION_SOURCE_SETTINGS',
    'display': 'android.settings.DISPLAY_SETTINGS',
    'sound': 'android.settings.SOUND_SETTINGS',
    'battery': 'android.settings.BATTERY_SETTINGS',
    'storage': 'android.settings.INTERNAL_STORAGE_SETTINGS',
    'apps': 'android.settings.APPLICATION_SETTINGS',
    'system_update': 'android.settings.SYSTEM_UPDATE_SETTINGS',
    'developer_options': 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    initSpeech();
    _loadConsentFlag();
  }

  Future<void> _loadConsentFlag() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? c = prefs.getBool('consent');
    setState(() {
      _consent = c ?? true;
    });
  }

  Future<void> initSpeech() async {
    try {
      bool available = await _speech.initialize(onError: (e) {}, onStatus: (s) {});
      setState(() {
        _speechAvailable = available;
      });
    } catch (e) {
      setState(() {
        _speechAvailable = false;
      });
    }
  }

  void startListening() async {
    if (!_speechAvailable || widget.limitedMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speech not available or microphone disabled.')));
      return;
    }
    setState(() => _listening = true);
    _lastWords = '';
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      localeId: null,
      onSoundLevelChange: null,
      cancelOnError: true,
      // options: usually none
    );
  }

  void stopListening() async {
    await _speech.stop();
    setState(() => _listening = false);
    if (_lastWords.isNotEmpty) {
      processInput(_lastWords);
    }
  }

  Future<void> processInput(String input) async {
    input = input.trim();
    if (input.isEmpty) return;

    String matchedAction = await matchActionForInput(input);
    if (matchedAction == 'not_found') {
      showGuideForAction('not_found', input);
      return;
    }

    if (matchedAction == 'system_update') {
      bool open = await showConfirmationDialog(
        title: guides['system_update']?['en'] ?? 'System update',
        message: guides['system_update']?['en'] ?? '',
        positiveLabel: 'Yes',
        negativeLabel: 'No (show alternatives)',
      );
      if (open) {
        await openSettingsFor(matchedAction);
      } else {
        showNoUpdateAlternatives(input);
      }
      return;
    }

    bool opened = await openSettingsFor(matchedAction);
    if (opened) {
      showGuideForAction(matchedAction, input);
    } else {
      showGuideForAction('not_found', input);
    }
  }

  void showNoUpdateAlternatives(String userInput) {
    final lang = _langOfInput(userInput);
    String tips = (lang == 'hi')
        ? 'कुछ कदम: अनावश्यक apps uninstall करें, cache clear करें (Storage), background apps कम करें, phone restart करें.'
        : 'Try: uninstall unused apps, clear cache (Storage), reduce background apps, restart device.';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(lang == 'hi' ? 'Quick fixes' : 'Quick fixes'),
        content: Text(tips),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(lang == 'hi' ? 'ठीक है' : 'OK')),
          TextButton(onPressed: () {
            Navigator.pop(context);
            openSettingsFor('storage');
          }, child: Text(lang == 'hi' ? 'Storage खोलो' : 'Open Storage')),
        ],
      ),
    );
  }

  void showGuideForAction(String actionKey, String input) {
    final lang = _langOfInput(input);
    String text = guides[actionKey]?[lang] ?? guides[actionKey]?['en'] ?? guides['not_found']!['en']!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
    // persistent bottom sheet
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang == 'hi' ? 'मार्गदर्शक' : 'Guide', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(text),
              const SizedBox(height: 12),
              Text(lang == 'hi' ? 'नोट: सिस्टम पर चेंज की पुष्टि आपसे मांगी जाएगी।' : 'Note: You will confirm changes on the system screen.'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(lang == 'hi' ? 'ठीक है' : 'Ok, got it')),
            ],
          ),
        ),
      ),
    );
  }

  String _langOfInput(String input) {
    if (input.characters.any((c) => RegExp(r'[\u0900-\u097F]').hasMatch(c))) return 'hi';
    if (input.characters.any((c) => RegExp(r'[\u0600-\u06FF]').hasMatch(c))) return 'ar';
    if (input.characters.any((c) => RegExp(r'[\u3040-\u30FF\u4E00-\u9FFF]').hasMatch(c))) return 'ja';
    if (input.characters.any((c) => RegExp(r'[\u0400-\u04FF]').hasMatch(c))) return 'ru';
    // other heuristics could be added
    return 'en';
  }

  Future<String> matchActionForInput(String input) async {
    final lowered = input.toLowerCase();
    final detectedLang = _langOfInput(input);
    // try detected language map
    final mapForLang = languageKeywords[detectedLang];
    if (mapForLang != null) {
      for (final k in mapForLang.keys) {
        if (lowered.contains(k.toLowerCase())) return mapForLang[k]!;
      }
    }
    // fallback english
    final enMap = languageKeywords['en']!;
    for (final k in enMap.keys) {
      if (lowered.contains(k.toLowerCase())) return enMap[k]!;
    }
    // try others
    for (final lang in languageKeywords.keys) {
      final m = languageKeywords[lang]!;
      for (final k in m.keys) {
        if (lowered.contains(k.toLowerCase())) return m[k]!;
      }
    }
    return 'not_found';
  }

  Future<bool> openSettingsFor(String actionKey) async {
    String action = actionIntents[actionKey] ?? 'android.settings.SETTINGS';
    try {
      final intent = AndroidIntent(action: action, flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK]);
      await intent.launch();
      return true;
    } catch (e) {
      try {
        final fallback = AndroidIntent(action: 'android.settings.SETTINGS', flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK]);
        await fallback.launch();
        return true;
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open settings on this device.')));
        }
        return false;
      }
    }
  }

  Future<bool> showConfirmationDialog({required String title, required String message, String positiveLabel = 'Yes', String negativeLabel = 'No'}) async {
    final bool? res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(negativeLabel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(positiveLabel)),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Settings Helper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Smart Settings Helper',
                applicationVersion: 'v1.0.0',
                children: const [
                  Text('Silent helper: listens to your voice or text and opens the right Settings screen. No data leaves your phone.'),
                ],
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            const Text('Type or speak your phone problem. The app will silently open the matching Settings screen and show short steps.', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g., My Wi-Fi not working / मेरा वाईफाई काम नहीं कर रहा',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      processInput(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTapDown: (_) {
                    if (!_listening) startListening();
                  },
                  onTapUp: (_) {
                    if (_listening) stopListening();
                  },
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: _listening ? Colors.red : Colors.teal,
                    child: Icon(_listening ? Icons.mic : Icons.mic_none, color: Colors.white),
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    final input = _controller.text.trim();
                    if (input.isNotEmpty) processInput(input);
                  },
                  child: const Text('Go to Setting'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    _controller.clear();
                    setState(() { _lastWords = ''; });
                  },
                  child: const Text('Clear'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                )
              ],
            ),
            const SizedBox(height: 14),
            if (_lastWords.isNotEmpty) Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recognized (preview):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_lastWords),
              ],
            ),
            const Expanded(child: SizedBox()),
            const Text('Tip: Speak in any supported language. App uses local keyword matching to keep your data private.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            const Text('Supported: English, Hindi, Japanese, Arabic, Russian, Marathi, Gujarati, Punjabi, Sanskrit, Urdu, Nepali, Tamil, Telugu, Malayalam (keywords-based)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}



