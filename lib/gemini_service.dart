import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stella/secrets.dart';

class GeminiService {
  final List<Map<String, dynamic>> _conversationHistory = [];
  bool _isProcessing = false;

  // Property to check if currently processing a request
  bool get isProcessing => _isProcessing;

  Future<String> handleUserMessage(String prompt) async {
    if (prompt.isEmpty) {
      return "I didn't catch that. Could you please speak again?";
    }

    try {
      _isProcessing = true;

      // Detect command-like queries
      if (_isSystemCommand(prompt)) {
        final commandResponse = await _handleSystemCommand(prompt);
        _isProcessing = false;
        return commandResponse;
      }

      // Detect if user is asking for image generation
      final isArtRequest = await _detectArtRequest(prompt);

      if (isArtRequest) {
        final imageDescription = await _generateImageDescription(prompt);
        _updateHistory(prompt, 'user');
        _updateHistory("Here's a description of the artwork I imagined for you: \n$imageDescription", 'assistant');
        _isProcessing = false;
        return "Here's a description of the artwork I imagined for you: \n$imageDescription";
      } else {
        final response = await _generateTextResponse(prompt);
        _isProcessing = false;
        return response;
      }
    } catch (e) {
      _isProcessing = false;
      return "I'm having trouble connecting right now. Please check your internet connection and try again.";
    }
  }

  bool _isSystemCommand(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    return lowerPrompt.contains('set alarm') ||
        lowerPrompt.contains('remind me') ||
        lowerPrompt.contains('timer') ||
        lowerPrompt.contains('turn on') ||
        lowerPrompt.contains('turn off') ||
        lowerPrompt.contains('call');
  }

  Future<String> _handleSystemCommand(String prompt) async {
    final lowerPrompt = prompt.toLowerCase();

    if (lowerPrompt.contains('set alarm') || lowerPrompt.contains('timer')) {
      return "I'd set an alarm for you, but that functionality is still in development. Would you like me to remind you about something else?";
    } else if (lowerPrompt.contains('remind me')) {
      return "I'll remember that for you. Just note that reminders aren't saved between sessions yet.";
    } else if (lowerPrompt.contains('turn on') || lowerPrompt.contains('turn off')) {
      return "I don't have the ability to control your device settings or smart home devices yet.";
    } else if (lowerPrompt.contains('call')) {
      return "I can't make calls yet, but that feature is planned for a future update.";
    }

    return await _generateTextResponse(prompt);
  }

  Future<bool> _detectArtRequest(String prompt) async {
    final lowerPrompt = prompt.toLowerCase();

    // Quick local check for common image request phrases
    if (lowerPrompt.contains('draw') ||
        lowerPrompt.contains('show me a picture') ||
        lowerPrompt.contains('create an image') ||
        lowerPrompt.contains('generate an image')) {
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiAPIKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{
              "text": "Respond ONLY with 'yes' or 'no': Is this message requesting an image, picture, painting, or visual artwork? '$prompt'"
            }]
          }],
          "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 5
          }
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody.containsKey('candidates') &&
            responseBody['candidates'].isNotEmpty &&
            responseBody['candidates'][0].containsKey('content') &&
            responseBody['candidates'][0]['content'].containsKey('parts') &&
            responseBody['candidates'][0]['content']['parts'].isNotEmpty &&
            responseBody['candidates'][0]['content']['parts'][0].containsKey('text')) {

          final content = responseBody['candidates'][0]['content']['parts'][0]['text']
              .trim().toLowerCase();
          return content == 'yes';
        }
      }
      // Default to false if we couldn't properly check
      print("Art detection API call failed or returned unexpected structure");
      return false;
    } catch (e) {
      print("Exception in _detectArtRequest: $e");
      return false;
    }
  }

  Future<String> _generateTextResponse(String prompt) async {
    _updateHistory(prompt, 'user');

    // Gemini doesn't support the 'system' role, so we need to use a different approach
    // We'll add the context instruction as a 'user' message at the beginning of the conversation
    List<Map<String, dynamic>> requestContents = [];

    // Add context as a user message if this is the first message in the conversation
    if (_conversationHistory.length <= 1) {
      String contextInstruction = "You are Stella, a helpful voice assistant powered by Gemini. Keep responses conversational, brief and easy to listen to as they will be spoken aloud. Avoid visual formatting like bullet points or lists when possible. If you need to provide steps, present them in a natural conversational way.";

      requestContents.add({
        'role': 'user',
        'parts': [{'text': contextInstruction}]
      });

      // Add a mock response to set the assistant behavior
      requestContents.add({
        'role': 'model',
        'parts': [{'text': "I understand. I'm Stella, your voice assistant. I'll keep my responses conversational and easy to listen to. How can I help you today?"}]
      });
    }

    // Add the actual conversation history
    requestContents.addAll(_conversationHistory);

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiAPIKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": requestContents,
          "generationConfig": {
            "temperature": 0.7,
            "topP": 0.9,
            "maxOutputTokens": 800
          }
        }),
      );

      // Check for successful response
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // First check if there are error details in the response
        if (responseBody.containsKey('error')) {
          print("API Error: ${responseBody['error']['message']}");
          return "I'm having trouble processing that request. Error: ${responseBody['error']['message']}";
        }

        // Now check if the expected structure exists
        if (responseBody.containsKey('candidates') &&
            responseBody['candidates'].isNotEmpty &&
            responseBody['candidates'][0].containsKey('content') &&
            responseBody['candidates'][0]['content'].containsKey('parts') &&
            responseBody['candidates'][0]['content']['parts'].isNotEmpty &&
            responseBody['candidates'][0]['content']['parts'][0].containsKey('text')) {

          final content = responseBody['candidates'][0]['content']['parts'][0]['text'].trim();

          // Post-process the response for better speech output
          final processedResponse = _processResponseForSpeech(content);

          _updateHistory(processedResponse, 'model');  // Note: Using 'model' role for Gemini
          return processedResponse;
        } else {
          // Unexpected response structure
          print("Unexpected API response structure: $responseBody");
          return "I received an unusual response format. Would you mind trying again?";
        }
      } else {
        // Non-200 status code
        print("API Error Status: ${response.statusCode}, Body: ${response.body}");
        return "I couldn't process that request. Error code: ${response.statusCode}";
      }
    } catch (e) {
      print("Exception in _generateTextResponse: $e");
      return "I encountered an error while processing your request. Please try again.";
    }
  }
  String _processResponseForSpeech(String response) {
    // Replace URLs with simplified mentions
    response = response.replaceAll(RegExp(r'https?:\/\/[^\s]+'), "the link I mentioned");

    // Replace markdown formatting - Fix for the error by using different approach
    response = response.replaceAll(RegExp(r'\*\*'), ''); // Remove bold markers
    response = response.replaceAll(RegExp(r'\*'), '');   // Remove italic markers
    response = response.replaceAll(RegExp(r'```.*?```', dotAll: true), "the code example");

    // Remove excessive newlines and replace with single spaces
    response = response.replaceAll(RegExp(r'\n{2,}'), ' ');
    response = response.replaceAll(RegExp(r'\n'), ' ');

    return response;
  }

  Future<String> _generateImageDescription(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiAPIKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{
              "text": "Create a vivid, detailed description of an image based on: $prompt. Make it descriptive enough that someone could imagine it clearly, focusing on visual elements like colors, composition, subjects, style, and mood. Keep it under 150 words."
            }]
          }],
          "generationConfig": {
            "temperature": 0.9,
            "maxOutputTokens": 250
          }
        }),
      );

      if (response.statusCode == 200) {
        final description = jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'].trim();
        return description;
      }
      return "I couldn't generate a description for that image. Please try a different request.";
    } catch (e) {
      return "Image description service is currently unavailable. Please try again later.";
    }
  }

  void _updateHistory(String content, String role) {
    // Make sure we're using valid roles for Gemini API (user or model)
    String validRole = (role == 'assistant') ? 'model' : role;

    _conversationHistory.add({
      'role': validRole,
      'parts': [{'text': content}]
    });

    // Keep conversation history manageable (10 turns)
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeAt(0);
      _conversationHistory.removeAt(0);  // Remove in pairs to maintain conversation flow
    }
  }
  void clearHistory() {
    _conversationHistory.clear();
  }
}