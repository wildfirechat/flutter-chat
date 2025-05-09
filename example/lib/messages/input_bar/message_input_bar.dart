import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/messages/input_bar/emoji_board.dart';
import 'package:wfc_example/messages/input_bar/plugin_board.dart';
import 'package:wfc_example/messages/input_bar/record_widget.dart';

import 'message_input_bar_controller.dart';

class MessageInputBar extends StatelessWidget {
  final List<String> emojis = [
    '😊',
    '😨',
    '😍',
    '😳',
    '😎',
    '😭',
    '😌',
    '😵',
    '😴',
    '😢',
    '😅',
    '😡',
    '😜',
    '😀',
    '😲',
    '😟',
    '😤',
    '😞',
    '😫',
    '😣',
    '😈',
    '😉',
    '😯',
    '😕',
    '😰',
    '😋',
    '😝',
    '😓',
    '😃',
    '😂',
    '😘',
    '😒',
    '😏',
    '😶',
    '😱',
    '😖',
    '😩',
    '😔',
    '😑',
    '😚',
    '😪',
    '😇',
    '🙊',
    '👊',
    '👎',
    '☝',
    '✌',
    '😬',
    '😷',
    '🙈',
    '👌',
    '👏',
    '✊',
    '💪',
    '😆',
    '☺',
    '🙉',
    '👍',
    '🙏',
    '✋',
    '☀',
    '☕',
    '⛄',
    '📚',
    '🎁',
    '🎉',
    '🍦',
    '☁',
    '❄',
    '⚡',
    '💰',
    '🎂',
    '🎓',
    '🍖',
    '☔',
    '⛅',
    '✏',
    '💩',
    '🎄',
    '🍷',
    '🎤',
    '🏀',
    '🀄',
    '💣',
    '📢',
    '🌏',
    '🍫',
    '🎲',
    '🏂',
    '💡',
    '💤',
    '🚫',
    '🌻',
    '🍻',
    '🎵',
    '🏡',
    '💢',
    '📞',
    '🚿',
    '🍚',
    '👪',
    '👼',
    '💊',
    '🔫',
    '🌹',
    '🐶',
    '💄',
    '👫',
    '👽',
    '💋',
    '🌙',
    '🍉',
    '🐷',
    '💔',
    '👻',
    '👿',
    '💍',
    '🌲',
    '🐴',
    '👑',
    '🔥',
    '⭐',
    '⚽',
    '🕖',
    '⏰',
    '😁',
    '🚀',
    '⏳',
    '🏡'
  ];

  MessageInputBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    MessageInputBarController controller = Provider.of<MessageInputBarController>(context);
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
              controller.status == ChatInputBarStatus.recordStatus
                  ? IconButton(
                      icon: Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize), onPressed: controller.onKeyboardButton)
                  : IconButton(icon: Image.asset('assets/images/input/chat_input_bar_voice.png', width: iconSize, height: iconSize), onPressed: controller.onVoiceButton),
              Expanded(
                child: controller.status == ChatInputBarStatus.recordStatus
                    ? RecordWidget(controller.conversation)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(0, 5, 5, 5),
                        child: CupertinoTextField(
                          maxLines: 3,
                          minLines: 1,
                          controller: controller.textEditingController,
                          focusNode: controller.focusNode,
                          onSubmitted: (_) => controller.onSendButton(),
                          onChanged: controller.onTextChanged,
                        ),
                      ),
              ),
              controller.status == ChatInputBarStatus.emojiStatus
                  ? IconButton(
                      icon: Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize), onPressed: controller.onKeyboardButton)
                  : IconButton(icon: Image.asset('assets/images/input/chat_input_bar_emoji.png', width: iconSize, height: iconSize), onPressed: controller.onEmojiButton),
              controller.textEditingController.text.isNotEmpty &&
                      controller.status != ChatInputBarStatus.recordStatus &&
                      controller.status != ChatInputBarStatus.pluginStatus
                  ? ElevatedButton(onPressed: controller.onSendButton, child: const Text("发送"))
                  : IconButton(
                      icon: Image.asset('assets/images/input/chat_input_bar_plugin.png', width: iconSize, height: iconSize), onPressed: controller.onPluginButton),
            ],
          ),
        ),
        controller.status == ChatInputBarStatus.emojiStatus
            ? EmojiBoard(
                emojis,
                pickerEmojiCallback: (emoji) => controller.insertText(emoji),
                delEmojiCallback: () => controller.backspace(emojis),
              )
            : Container(),
        controller.status == ChatInputBarStatus.pluginStatus ? PluginBoard(controller.conversation) : Container(),
      ],
    );
  }
}
