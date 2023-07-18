import 'package:flutter/material.dart';
import 'package:stella/pallete.dart';

import 'home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stella',
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Pallete.whiteColor,
      ),
      home: HomePage(),
    );
  }
}
