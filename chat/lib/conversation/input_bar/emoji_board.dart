import 'dart:ui';

import 'package:flutter/material.dart';


typedef OnPickerEmojiCallback = void Function(String emoji);
typedef OnDelEmojiCallback = void Function();

class EmojiBoard extends StatelessWidget{
  EmojiBoard(this.emojis, {Key? key, required this.pickerEmojiCallback, required this.delEmojiCallback}) : super(key: key);
  OnPickerEmojiCallback pickerEmojiCallback;
  OnDelEmojiCallback delEmojiCallback;
  List<String> emojis;

  @override
  Widget build(BuildContext context) {
    double boardHeight = 200;
    int lineCount = 8;
    double screenWidth =PlatformDispatcher.instance.views.first.physicalSize.width/PlatformDispatcher.instance.views.first.devicePixelRatio;
    double textSize = 28;
    double paddingSize = (screenWidth - textSize * lineCount)/lineCount/2;
    int lines = (boardHeight/(textSize+paddingSize*2)).toInt();
    double delSizeX = 48;
    double delSizeY = 38;
    double delPadding = 5;
    double delStartX = screenWidth - paddingSize -delSizeX + delPadding;
    double delStartY = (textSize + paddingSize + paddingSize) * (lines - 1) + paddingSize - (delSizeY - textSize)/2;

    return SizedBox(
      height: boardHeight,
      child: Stack(
        children: [
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: lineCount),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                child: Center(child: Text(emojis[index], style: TextStyle(fontSize: textSize),),),
                onTap: () => _onTapItem(index) ,
              );
            },
          ),
          GestureDetector(
            onTap: _onDel ,
            child: Container(
              margin: EdgeInsets.fromLTRB(delStartX, delStartY, 0, 0),
              padding: EdgeInsets.all(delPadding),
              color: const Color.fromARGB(255, 232, 232, 232),
              child: SizedBox(
                width: delSizeX- 2*delPadding,
                height: delSizeY - 2*delPadding,
                child: Image.asset('assets/images/input/del_emoji.png'),),
            ),
          )
        ],
      ),
    );
  }

  void _onDel() {
    delEmojiCallback();
  }

  void _onTapItem(int index) {
    pickerEmojiCallback(emojis[index]);
  }
}