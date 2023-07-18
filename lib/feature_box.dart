import 'package:flutter/material.dart';
import 'package:stella/pallete.dart';

class FeatureBox extends StatelessWidget {
  const FeatureBox(
      {required this.color,
      required this.headerText,
      required this.descriptionText});
  final Color color;
  final String headerText;
  final String descriptionText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 35,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0).copyWith(
          left: 15,
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                headerText,
                style: TextStyle(
                  fontFamily: 'Cera Pro',
                  color: Pallete.blackColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                descriptionText,
                style: TextStyle(
                  fontFamily: 'Cera Pro',
                  color: Pallete.blackColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
