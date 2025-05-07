
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/messages/conversation_notifier.dart';
import 'package:wfc_example/messages/input_bar/emoji_board.dart';
import 'package:wfc_example/messages/input_bar/plugin_board.dart';
import 'package:wfc_example/messages/input_bar/record_widget.dart';

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
typedef OnSoundRecordedCallback = void Function(String soundPath, int duration);

class MessageInputBar extends StatefulWidget {
  MessageInputBar(this._conversation, {ChatInputBarStatus chatInputBarStatus = ChatInputBarStatus.keyboardStatus, Key? key}) : _chatInputBarStatus = chatInputBarStatus, super(key: key);
  final Conversation _conversation;
  ChatInputBarStatus _chatInputBarStatus;

  @override
  State<StatefulWidget> createState() => MessageInputBarState();
}

class MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _textEditingController = TextEditingController();
  final List<String> emojis = ['😊','😨','😍','😳','😎','😭','😌','😵','😴','😢','😅','😡','😜','😀','😲','😟','😤','😞','😫','😣','😈','😉','😯','😕','😰','😋','😝','😓','😃','😂','😘','😒','😏','😶','😱','😖','😩','😔','😑','😚','😪','😇','🙊','👊','👎','☝','✌','😬','😷','🙈','👌','👏','✊','💪','😆','☺','🙉','👍','🙏','✋','☀','☕','⛄','📚','🎁','🎉','🍦','☁','❄','⚡','💰','🎂','🎓','🍖','☔','⛅','✏','💩','🎄','🍷','🎤','🏀','🀄','💣','📢','🌏','🍫','🎲','🏂','💡','💤','🚫','🌻','🍻','🎵','🏡','💢','📞','🚿','🍚','👪','👼','💊','🔫','🌹','🐶','💄','👫','👽','💋','🌙','🍉','🐷','💔','👻','👿','💍','🌲','🐴','👑','🔥','⭐','⚽','🕖','⏰','😁','🚀','⏳','🏡'];

  late CupertinoTextField _textField;
  final FocusNode _focusNode = FocusNode();
  late ConversationNotifier conversationNotifier;

  @override
  void initState() {
    super.initState();
    conversationNotifier = Provider.of<ConversationNotifier>(context, listen: false);
    _textField = CupertinoTextField(
      maxLines: 3,
      minLines: 1,
      controller: _textEditingController,
      focusNode: _focusNode,
      onSubmitted: (text){
        _onSendButton();
      }, onChanged: (text) {
        setState(() {

        });
      conversationNotifier.onInputBarTextChanged(text);
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
  }

  @override
  Widget build(BuildContext context) {
    double iconSize = 32;
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(width: 1, color: Color(0xFFDDDDDD)),
              left: BorderSide(width: 1, color: Color(0xFFDDDDDD)),
              right: BorderSide(width: 1, color: Color(0xFFDDDDDD)),
              bottom: BorderSide(width: 1, color: Color(0xFFDDDDDD)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              widget._chatInputBarStatus == ChatInputBarStatus.recordStatus ? IconButton(icon: Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize,), onPressed: _onKeyboardButton) :  IconButton(icon: Image.asset('assets/images/input/chat_input_bar_voice.png', width: iconSize, height: iconSize,), onPressed: _onVoiceButton),
              Expanded(
                child: widget._chatInputBarStatus == ChatInputBarStatus.recordStatus?
                RecordWidget(widget._conversation):Padding(padding: const EdgeInsets.fromLTRB(0, 5, 5, 5), child: _textField,),
              ),
              widget._chatInputBarStatus == ChatInputBarStatus.emojiStatus ? IconButton(icon: Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize,), onPressed: _onKeyboardButton) : IconButton(icon: Image.asset('assets/images/input/chat_input_bar_emoji.png', width: iconSize, height: iconSize,), onPressed: _onEmojiButton),
              _textEditingController.value.text.isNotEmpty && widget._chatInputBarStatus != ChatInputBarStatus.recordStatus && widget._chatInputBarStatus != ChatInputBarStatus.pluginStatus?
              ElevatedButton(onPressed: _onSendButton, child: const Text("发送"),) :
              IconButton(icon: Image.asset('assets/images/input/chat_input_bar_plugin.png', width: iconSize, height: iconSize,), onPressed: _onPluginButton),
            ],
          ),
        ),
        widget._chatInputBarStatus == ChatInputBarStatus.emojiStatus? EmojiBoard(emojis, pickerEmojiCallback: _onPickEmoji, delEmojiCallback: _onDelEmoji,):Container(),
        widget._chatInputBarStatus == ChatInputBarStatus.pluginStatus? PluginBoard(widget._conversation):Container(),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void resetStatus() {
    if(widget._chatInputBarStatus == ChatInputBarStatus.pluginStatus || widget._chatInputBarStatus == ChatInputBarStatus.emojiStatus) {
      setState(() {
        widget._chatInputBarStatus = ChatInputBarStatus.keyboardStatus;
      });
    }
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
      // widget.sendButtonTapedCallback(_textEditingController.value.text);
      conversationNotifier.onSendButtonTyped(widget._conversation, _textEditingController.value.text);
      setState(() {
        _textEditingController.clear();
      });
    }
  }

  void _onEmojiButton() {
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

  String getDraft() {
    return _textEditingController.text;
  }

  void setDrat(String draft) {
    setState(() {
      _textEditingController.text = draft;
      _textEditingController.selection = TextSelection(baseOffset: draft.length, extentOffset: draft.length);
    });
  }

  void _insertText(String myText) {
    final text = _textEditingController.text;
    final textSelection = _textEditingController.selection;
    final newText = text.replaceRange(
      textSelection.start,
      textSelection.end,
      myText,
    );
    final myTextLength = myText.length;

    setState(() {
      _textEditingController.text = newText;
      _textEditingController.selection = textSelection.copyWith(
        baseOffset: textSelection.start + myTextLength,
        extentOffset: textSelection.start + myTextLength,
      );
    });
  }

  void _backspace() {
    final text = _textEditingController.text;
    final textSelection = _textEditingController.selection;
    final selectionLength = textSelection.end - textSelection.start;

    // There is a selection.
    if (selectionLength > 0) {
      final newText = text.replaceRange(
        textSelection.start,
        textSelection.end,
        '',
      );
      setState(() {
        _textEditingController.text = newText;
        _textEditingController.selection = textSelection.copyWith(
          baseOffset: textSelection.start,
          extentOffset: textSelection.start,
        );
      });
      return;
    }

    // The cursor is at the beginning.
    if (textSelection.start == 0) {
      return;
    }

    // Delete the previous character
    int charSize = 1;
    if(textSelection.start > 1) {
      String sub = text.substring(textSelection.start-2, textSelection.start);
      if(emojis.contains(sub)) {
        charSize = 2;
      }
    }

    int newStart = textSelection.start - charSize;
    int newEnd = textSelection.start;
    final newText = text.replaceRange(
      newStart,
      newEnd,
      '',
    );
    setState(() {
      _textEditingController.text = newText;
      _textEditingController.selection = textSelection.copyWith(
        baseOffset: newStart,
        extentOffset: newStart,
      );
    });
  }

  void _onPickEmoji(String emoji) {
    _insertText(emoji);
  }

  void _onDelEmoji() {
    _backspace();
  }
}