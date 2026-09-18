import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/unknown_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/src/imclient_channel.dart';

/// 平台通道边界解析测试。
///
/// 移动端原生（Android/iOS/鸿蒙）返回嵌套结构（conversation/content 为嵌套
/// 字段、发送者为 sender、接收者为 toUsers）；桌面端 SDK 返回扁平结构
/// （conversationType/target/line 位于顶层、发送者为 from、接收者为 to）。
/// 这些测试锁定两种 shape 的解析行为，防止再次出现"支持桌面端时改坏移动端"
/// 一类的回归（如 cff4fdc 引入的 toUsers 丢失）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = ImclientPlatform.instance;
  // 测试运行在桌面主机上，强制走 MethodChannel 路径以配合 mock
  // （默认桌面端会选择 FFI 实现并加载真实 SDK）。
  ImclientPlatform.debugChannelOverride =
      MethodChannelImclientChannel(platform.methodChannel);

  Future<void> mockChannel(Map<String, dynamic Function(MethodCall)> handlers) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (call) async {
      final handler = handlers[call.method];
      if (handler == null) {
        fail('unexpected method call: ${call.method}');
      }
      return handler(call);
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, null);
  });

  group('getMessages 消息解析', () {
    final conversation =
        Conversation(conversationType: ConversationType.Single, target: 'friendB');

    test('移动端嵌套 shape：sender/toUsers/嵌套 conversation', () async {
      await mockChannel({
        'getMessages': (_) => [
              {
                'messageId': 100,
                'messageUid': 1000,
                'sender': 'userA',
                'conversation': {'type': 0, 'target': 'friendB', 'line': 0},
                'toUsers': ['u1', 'u2'],
                'direction': 0,
                'status': 1,
                'serverTime': 123456,
                'content': {'type': 1, 'searchableContent': 'hello'},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      expect(messages, hasLength(1));
      final msg = messages.first;
      expect(msg.fromUser, 'userA');
      expect(msg.toUsers, ['u1', 'u2'], reason: '移动端 toUsers 字段不能丢失');
      expect(msg.conversation.target, 'friendB');
      expect(msg.conversation.conversationType, ConversationType.Single);
      expect(msg.serverTime, 123456);
    });

    test('桌面端扁平 shape：from/to/顶层 conversationType', () async {
      await mockChannel({
        'getMessages': (_) => [
              {
                'messageId': 5,
                'from': 'u9',
                'conversationType': 0,
                'target': 'friendB',
                'line': 0,
                'to': ['x'],
                'direction': 0,
                'status': 0,
                'timestamp': 1,
                'content': {'type': 1},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      final msg = messages.first;
      expect(msg.fromUser, 'u9');
      expect(msg.toUsers, ['x']);
      expect(msg.conversation.target, 'friendB');
    });

    test('桌面端消息完全缺失会话信息时，用请求参数回填', () async {
      await mockChannel({
        'getMessages': (_) => [
              {
                'messageId': 6,
                'from': 'u9',
                'direction': 0,
                'status': 0,
                'timestamp': 1,
                'content': {'type': 1},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      expect(messages.first.conversation.target, 'friendB');
    });

    test('嵌套 conversation 优先于顶层同名字段（防字段污染）', () async {
      await mockChannel({
        'getMessages': (_) => [
              {
                'messageId': 7,
                'sender': 's',
                'conversation': {'type': 0, 'target': 'realTarget', 'line': 0},
                'target': 'strayTarget',
                'direction': 0,
                'status': 0,
                'timestamp': 1,
                'content': {'type': 1},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      expect(messages.first.conversation.target, 'realTarget',
          reason: '顶层杂散 target 不能污染嵌套的会话信息');
    });

    test('无 conversationType 时顶层 target 不得被误读成会话', () async {
      await mockChannel({
        'getMessages': (_) => [
              {
                'messageId': 8,
                'sender': 's',
                'target': 'strayTarget',
                'direction': 0,
                'status': 0,
                'timestamp': 1,
                'content': {'type': 1},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      expect(messages.first.conversation.target, 'friendB',
          reason: '应回填请求会话，而不是读取顶层杂散字段');
    });

    test('messageId 为 -1 的占位消息被丢弃', () async {
      await mockChannel({
        'getMessages': (_) => [
              {'messageId': -1},
              {
                'messageId': 9,
                'sender': 's',
                'conversation': {'type': 0, 'target': 'friendB', 'line': 0},
                'direction': 0,
                'status': 0,
                'timestamp': 1,
                'content': {'type': 1},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      expect(messages, hasLength(1));
      expect(messages.first.messageId, 9);
    });
  });

  group('getConversationInfos 会话列表解析', () {
    test('移动端嵌套 shape', () async {
      await mockChannel({
        'getConversationInfos': (_) => [
              {
                'conversation': {'type': 1, 'target': 'group1', 'line': 0},
                'timestamp': 111,
                'unreadCount': {'unread': 3},
              },
            ],
      });

      final infos = await platform
          .getConversationInfos([ConversationType.Single, ConversationType.Group], [0]);

      expect(infos, hasLength(1));
      expect(infos.first.conversation.target, 'group1');
      expect(infos.first.conversation.conversationType, ConversationType.Group);
      expect(infos.first.unreadCount.unread, 3);
    });

    test('桌面端扁平 shape，lastMessage 占位对象被过滤', () async {
      await mockChannel({
        'getConversationInfos': (_) => [
              {
                'conversationType': 1,
                'target': 'group1',
                'line': 0,
                'timestamp': 111,
                'lastMessage': {'messageId': -1},
                'unreadCount': {'unread': 2},
              },
            ],
      });

      final infos =
          await platform.getConversationInfos([ConversationType.Group], [0]);

      expect(infos, hasLength(1));
      expect(infos.first.conversation.target, 'group1');
      expect(infos.first.conversation.conversationType, ConversationType.Group);
      expect(infos.first.lastMessage, isNull,
          reason: 'messageId<=0 的占位 lastMessage 应被过滤为 null');
    });
  });

  group('非法消息兜底', () {
    final conversation = Conversation(
        conversationType: ConversationType.Single, target: 'friendB');

    setUpAll(() async {
      // 只有注册过的类型才会走对应的解码器，这里注册文本/语音用于和未知消息对照。
      await mockChannel({'registerMessage': (_) => null});
      platform.registerMessage(textContentMeta);
      platform.registerMessage(soundContentMeta);
      await Future<void>.delayed(Duration.zero);
    });

    test('字段类型不对、枚举越界的消息降级成未知消息，不影响同批次的其他消息', () async {
      await mockChannel({
        'getMessages': (_) => [
              {
                // 每个字段的类型都不是 Dart 侧声明的类型
                'messageId': '31L',
                'messageUid': 3.0,
                'sender': 12345,
                'conversation': {'type': 99, 'target': 7, 'line': '0'},
                'toUsers': ['u1', 2, null],
                'direction': 99,
                'status': 99,
                'serverTime': '123456',
                'content': {
                  'type': 'x',
                  'mentionedType': '2',
                  'mentionedTargets': [1],
                  'mediaType': 99,
                  'binaryContent': '这不是合法的 base64!!',
                },
              },
              {
                'messageId': 32,
                'sender': 's',
                'conversation': {'type': 0, 'target': 'friendB', 'line': 0},
                'direction': 0,
                'status': 0,
                'timestamp': 1,
                'content': {'type': 1, 'searchableContent': 'hello'},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      expect(messages, hasLength(2), reason: '非法消息不能拖垮整批转换');
      final broken = messages.firstWhere((m) => m.messageId == 31);
      expect(broken.content, isA<UnknownMessageContent>());
      expect(broken.fromUser, '12345');
      expect(broken.toUsers, ['u1', '2']);
      expect(broken.conversation.conversationType, ConversationType.Single,
          reason: '越界的会话类型回落到默认值');
      expect(broken.serverTime, 123456);
      expect((messages.firstWhere((m) => m.messageId == 32).content
              as TextMessageContent)
          .text, 'hello');
    });

    test('消息不是 map 时被丢弃', () async {
      await mockChannel({
        'getMessages': (_) => [
              'not a message',
              {
                'messageId': 33,
                'sender': 's',
                'conversation': {'type': 0, 'target': 'friendB', 'line': 0},
                'direction': 0,
                'status': 0,
                'timestamp': 1,
                'content': {'type': 1},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      expect(messages, hasLength(1));
      expect(messages.first.messageId, 33);
    });

    test('已注册类型但内容非法时，降级成未知消息而不是抛异常', () async {
      // 语音消息(type 2)的 content 不是合法 JSON，SoundMessageContent.decode 会抛异常
      await mockChannel({
        'getMessages': (_) => [
              {
                'messageId': 34,
                'sender': 's',
                'conversation': {'type': 0, 'target': 'friendB', 'line': 0},
                'direction': 0,
                'status': 0,
                'timestamp': 1,
                'content': {'type': 2, 'content': '{不是合法 json'},
              },
            ],
      });

      final messages = await platform.getMessages(conversation, 0, 10);

      expect(messages, hasLength(1));
      expect(messages.first.content, isA<UnknownMessageContent>());
    });
  });
}
