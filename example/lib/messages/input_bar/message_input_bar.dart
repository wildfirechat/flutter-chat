import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:wfc_example/messages/input_bar/emoj_board.dart';
import 'package:wfc_example/messages/input_bar/plugin_board.dart';

enum ChatInputBarStatus {
  keyboardStatus,
  pluginStatus,
  emojiStatus,
  recordStatus,
  muteStatus,
  pttStatus
}

typedef OnSendButtonTapedCallback = void Function(String text);
typedef OnTextChangedCallback = void Function(String text);

class MessageInputBar extends StatefulWidget {
  MessageInputBar(this._conversation, this._sendButtonTapedCallback, this._textChangedCallback, this._pickerImageCallback, this._pickerFileCallback, this._pressCallBtnCallback, {ChatInputBarStatus chatInputBarStatus = ChatInputBarStatus.keyboardStatus, Key? key}) : _chatInputBarStatus = chatInputBarStatus, super(key: key);
  Conversation _conversation;
  ChatInputBarStatus _chatInputBarStatus;
  final OnSendButtonTapedCallback _sendButtonTapedCallback;
  final OnTextChangedCallback _textChangedCallback;
  final OnPickerImageCallback _pickerImageCallback;
  final OnPickerFileCallback _pickerFileCallback;
  final OnPressCallBtnCallback _pressCallBtnCallback;

  @override
  State<StatefulWidget> createState() => MessageInputBarState();
}

class MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _textEditingController = TextEditingController();

  late TextField _textField;
  late OutlinedButton _recordButton;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    _textField = TextField(
      controller: _textEditingController,
      focusNode: _focusNode,
      onSubmitted: (text){
        _onSendButton();
      }, onChanged: (text) {
        setState(() {

        });
        widget._textChangedCallback(text);
      },
    );
    _focusNode.requestFocus();
    _focusNode.addListener(() {
      if(_focusNode.hasFocus) {
       if(widget._chatInputBarStatus != ChatInputBarStatus.keyboardStatus) {
         setState(() {
           widget._chatInputBarStatus = ChatInputBarStatus.keyboardStatus;
         });
       }
      } else {

      }
    });

    _recordButton = OutlinedButton(onPressed: (){

    }, child: const Text("按下说话"));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(width: 1, color: Color(0xFFA1A1A1)),
              left: BorderSide(width: 1, color: Color(0xFFA1A1A1)),
              right: BorderSide(width: 1, color: Color(0xFFA1A1A1)),
              bottom: BorderSide(width: 1, color: Color(0xFFA1A1A1)),
            ),
          ),
          child: Row(
            children: [
              widget._chatInputBarStatus == ChatInputBarStatus.recordStatus ? IconButton(icon: const Icon(Icons.keyboard_alt_rounded), onPressed: _onKeyboardButton) :  IconButton(icon: const Icon(Icons.record_voice_over_rounded), onPressed: _onVoiceButton),
              Expanded(
                child: widget._chatInputBarStatus == ChatInputBarStatus.recordStatus?_recordButton:_textField,
              ),
              IconButton(icon: const Icon(Icons.emoji_emotions), onPressed: _onEmojButton),
              _textEditingController.value.text.isNotEmpty && widget._chatInputBarStatus != ChatInputBarStatus.recordStatus && widget._chatInputBarStatus != ChatInputBarStatus.pluginStatus?
              IconButton(icon: const Icon(Icons.send), onPressed: _onSendButton) :
              IconButton(icon: const Icon(Icons.add_circle_outline_rounded), onPressed: _onPluginButton),
            ],
          ),
        ),
        widget._chatInputBarStatus == ChatInputBarStatus.emojiStatus? EmojBoard():Container(),
        widget._chatInputBarStatus == ChatInputBarStatus.pluginStatus? PluginBoard(widget._pickerImageCallback, widget._pickerFileCallback, widget._pressCallBtnCallback):Container(),
      ],
    );
  }

  void resetStatus() {
    _focusNode.unfocus();
  }

  void _onPluginButton() {
    setState(() {
      if(widget._chatInputBarStatus == ChatInputBarStatus.pluginStatus) {
        if(!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
        widget._chatInputBarStatus = ChatInputBarStatus.keyboardStatus;
      } else {
        if(_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
        widget._chatInputBarStatus = ChatInputBarStatus.pluginStatus;
      }
    });
  }

  void _onSendButton() {
    if(_textEditingController.value.text.isNotEmpty) {
      widget._sendButtonTapedCallback(_textEditingController.value.text);
      _textEditingController.clear();
    }
  }

  void _onEmojButton() {
    setState(() {
      if(widget._chatInputBarStatus == ChatInputBarStatus.emojiStatus) {
        if(!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
        widget._chatInputBarStatus = ChatInputBarStatus.keyboardStatus;
      } else {
        if(_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
        widget._chatInputBarStatus = ChatInputBarStatus.emojiStatus;
      }
    });
  }

  void _onVoiceButton() {
    setState(() {
      widget._chatInputBarStatus = ChatInputBarStatus.recordStatus;
    });
  }

  void _onKeyboardButton() {
    setState(() {
      if(!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      widget._chatInputBarStatus = ChatInputBarStatus.keyboardStatus;
    });
  }
}