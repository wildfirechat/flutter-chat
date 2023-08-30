import 'package:flutter/material.dart';

class MessageTitle extends StatefulWidget {
  MessageTitle(this.title, {Key? key}) : super(key: key);
  final MessageTitleState _state = MessageTitleState();
  String title;

  @override
  State<StatefulWidget> createState() {
    return _state;
  }

  void updateTitle(String title) {
    this.title = title;
    _state.updateTitle();
  }
}

class MessageTitleState extends State<MessageTitle> {
  bool disposed = true;
  void updateTitle() {
    if(!disposed) {
      setState(() {

      });
    }
  }

  @override
  Widget build(BuildContext context) {
    disposed = false;
    return Text(widget.title);
  }

  @override
  void dispose() {
    super.dispose();
    disposed = true;
  }
}