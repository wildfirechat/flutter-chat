import 'package:flutter/material.dart';

class EmojBoard extends StatefulWidget {
  const EmojBoard({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => EmojBoardState();
}

class EmojBoardState extends State<EmojBoard> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(
        child: Text("emoj"),
      ),
    );
  }
}