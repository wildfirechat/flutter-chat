import 'package:flutter/material.dart';

class MessageTitle extends StatefulWidget {
  MessageTitle(this.title, {Key? key}) : super(key: key);

  String title;

  @override
  State<StatefulWidget> createState() => MessageTitleState();

}

class MessageTitleState extends State<MessageTitle> {
  bool disposed = true;
  void updateTitle(String title) {
    if(!disposed) {
      setState(() {
        widget.title = title;
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