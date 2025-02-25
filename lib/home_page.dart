import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:stella/feature_box.dart';
import 'package:stella/gemini_service.dart';
import 'package:stella/pallete.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final speechToText = SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  String lastWords = '';
  final GeminiService geminiService = GeminiService();
  String? generatedContent;
  String? generatedImageDescription;
  int start = 200;
  int delay = 200;
  bool isListening = false;
  bool isProcessing = false;
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    initSpeechToText();
    initTextToSpeech();
  }

  Future<void> initSpeechToText() async {
    await speechToText.initialize();
    setState(() {});
  }

  Future<void> initTextToSpeech() async {
    await flutterTts.setSharedInstance(true);
    await flutterTts.setLanguage('en-US');

    // Configure TTS settings for better voice
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.5);  // Slightly slower for better comprehension

    // Set up TTS callbacks
    flutterTts.setStartHandler(() {
      setState(() {
        isSpeaking = true;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> startListening() async {
    setState(() {
      isListening = true;
      lastWords = '';
    });

    await speechToText.listen(
      onResult: onSpeechResult,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  Future<void> stopListening() async {
    await speechToText.stop();
    setState(() {
      isListening = false;
    });
  }

  void onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      lastWords = result.recognizedWords;
    });
  }

  Future<void> systemSpeak(String content) async {
    if (content.isNotEmpty) {
      await flutterTts.speak(content);
    }
  }

  Future<void> processVoiceInput() async {
    if (lastWords.isEmpty) return;

    setState(() {
      isProcessing = true;
    });

    // Display user's query in the chat bubble temporarily
    setState(() {
      generatedContent = "You: \"$lastWords\"";
    });

    final response = await geminiService.handleUserMessage(lastWords);

    // Update the UI with the response
    setState(() {
      isProcessing = false;
      if (response.contains("artwork") || response.contains("Here's a description of")) {
        generatedImageDescription = response;
        generatedContent = null;
      } else {
        generatedContent = response;
        generatedImageDescription = null;
      }
    });

    // Speak the response
    await systemSpeak(response);
  }

  @override
  void dispose() {
    super.dispose();
    speechToText.stop();
    flutterTts.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Pallete.whiteColor,
        title: BounceInDown(
          child: const Text(
            "Stella",
            style: TextStyle(
              fontFamily: 'Cera Pro',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                generatedContent = null;
                generatedImageDescription = null;
                geminiService.clearHistory();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Virtual assistant animation with pulse effect
            ZoomIn(
              child: Pulse(
                infinite: isListening || isProcessing || isSpeaking,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: isListening
                              ? Pallete.assistantCircleColor.withOpacity(0.8)
                              : Pallete.assistantCircleColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Container(
                      height: 123,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/images/stella.png'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Status indicator (Listening, Processing, Speaking)
            AnimatedOpacity(
              opacity: isListening || isProcessing || isSpeaking ? 1.0 : 0.0,
              duration: Duration(milliseconds: 200),
              child: Container(
                margin: EdgeInsets.only(top: 10),
                child: Text(
                  isListening
                      ? "Listening..."
                      : isProcessing
                      ? "Processing..."
                      : isSpeaking
                      ? "Speaking..."
                      : "",
                  style: TextStyle(
                    color: Pallete.mainFontColor,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

            // Voice input text preview
            if (isListening && lastWords.isNotEmpty)
              FadeIn(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Pallete.firstSuggestionBoxColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    lastWords,
                    style: TextStyle(
                      color: Pallete.mainFontColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

            // Chat bubble
            FadeInRight(
              child: Visibility(
                visible: generatedImageDescription == null && generatedContent != null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 40).copyWith(
                    top: 20,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Pallete.borderColor,
                    ),
                    borderRadius: BorderRadius.circular(20).copyWith(
                      topLeft: Radius.zero,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      generatedContent == null
                          ? 'Hi there! I\'m Stella, your voice assistant. Tap the mic button and ask me anything.'
                          : generatedContent!,
                      style: TextStyle(
                        color: Pallete.mainFontColor,
                        fontSize: generatedContent == null || generatedContent!.startsWith("You: \"") ? 20 : 18,
                        fontFamily: "Cera Pro",
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Image description bubble
            if (generatedImageDescription != null)
              FadeInUp(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 40).copyWith(
                    top: 20,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Pallete.borderColor,
                    ),
                    borderRadius: BorderRadius.circular(20).copyWith(
                      topLeft: Radius.zero,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      generatedImageDescription!,
                      style: TextStyle(
                        color: Pallete.mainFontColor,
                        fontSize: 18,
                        fontFamily: "Cera Pro",
                      ),
                    ),
                  ),
                ),
              ),

            // Welcome message and features section
            SlideInLeft(
              child: Visibility(
                visible: generatedContent == null && generatedImageDescription == null,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.centerLeft,
                  margin: const EdgeInsets.only(top: 10, left: 22),
                  child: const Text(
                    'How can I help you today?',
                    style: TextStyle(
                      fontFamily: 'Cera Pro',
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Pallete.mainFontColor,
                    ),
                  ),
                ),
              ),
            ),

            // Features list
            Visibility(
              visible: generatedContent == null && generatedImageDescription == null,
              child: Column(
                children: [
                  SlideInLeft(
                    delay: Duration(milliseconds: start),
                    child: const FeatureBox(
                      color: Pallete.firstSuggestionBoxColor,
                      headerText: 'AI Conversations',
                      descriptionText:
                      'Ask me questions, get information, or just chat naturally with voice',
                    ),
                  ),
                  SlideInLeft(
                    delay: Duration(milliseconds: start + delay),
                    child: const FeatureBox(
                      color: Pallete.secondSuggestionBoxColor,
                      headerText: 'Image Descriptions',
                      descriptionText:
                      'Ask me to describe or imagine images and I\'ll create detailed visualizations',
                    ),
                  ),
                  SlideInLeft(
                    delay: Duration(milliseconds: start + 2 * delay),
                    child: const FeatureBox(
                      color: Pallete.thirdSuggestionBoxColor,
                      headerText: 'Voice Commands',
                      descriptionText:
                      'Just say "tell me a joke" or "what\'s the weather like" to get started',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ZoomIn(
        child: FloatingActionButton(
          backgroundColor: isListening
              ? Colors.red
              : isProcessing
              ? Colors.orange
              : Pallete.firstSuggestionBoxColor,
          onPressed: () async {
            // If already processing or speaking, don't do anything
            if (isProcessing || isSpeaking) return;

            if (isListening) {
              // Stop listening and process what was heard
              await stopListening();
              await processVoiceInput();
            } else {
              // Start listening for voice input
              if (await speechToText.hasPermission) {
                await startListening();
              } else {
                await initSpeechToText();
              }
            }
          },
          child: Icon(
            isListening
                ? Icons.stop
                : isProcessing
                ? Icons.hourglass_top
                : isSpeaking
                ? Icons.volume_up
                : Icons.mic,
            color: Pallete.whiteColor,
          ),
        ),
      ),
    );
  }
}