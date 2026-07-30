import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:pinyin/pinyin.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/input_bar/message_input_bar_controller.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/theme/app_typography.dart';

/// 微信 PC 风格的 @ 提醒浮层:键入 '@' 后浮层贴着 '@' 出现在其正上方,底部有一个
/// 指向 '@' 的小箭头,浮层随 '@' 在输入框里的位置横竖两个方向浮动;随后续键入
/// 就地过滤候选人(匹配显示名/拼音全拼/拼音首字母);上下键移动高亮并循环,
/// Enter/Tab 选中,Esc 关闭,鼠标悬停同步高亮、点击选中。无匹配时浮层自动隐藏。
///
/// 候选范围:群聊为群成员(群主/管理员额外有"所有人")+ 配置的 AI 机器人;
/// 单聊为配置的 AI 机器人(以及对方本身是机器人的场景),无候选时键入 '@' 只是普通文本。
///
/// @ 会话状态(开启/查询串/结束)由 [MessageInputBarController] 维护,
/// 本类只负责候选加载、过滤与浮层展示,通过 [handleKeyEvent] 消费导航按键。
class PcMentionOverlay {
  PcMentionOverlay(
      {required this.inputBarController, required this.textFieldKey});

  final MessageInputBarController inputBarController;

  /// 输入框的 key,用来找到 [RenderEditable] 反查 '@' 的光标矩形。
  final GlobalKey textFieldKey;

  static const double _rowHeight = 36;
  static const double _panelWidth = 200;
  static const int _maxVisibleRows = 6;

  /// 底部指向 '@' 的小箭头。
  static const double _arrowWidth = 14;
  static const double _arrowHeight = 7;

  /// 箭头尖与 '@' 所在行行顶之间的空隙。
  static const double _anchorGap = 4;

  /// 浮层与窗口边缘的最小留白(贴边时把浮层推回窗口内)。
  static const double _windowMargin = 8;

  OverlayState? _overlayState;
  OverlayEntry? _entry;
  final ScrollController _scrollController = ScrollController();

  /// '@' 光标矩形左上角在 overlay 坐标系里的位置,即箭头尖要指向的点;
  /// null 表示还没拿到(渲染树未就绪),退回输入框左上角。
  Offset? _anchor;
  Size _overlaySize = Size.zero;

  List<_MentionCandidate> _candidates = [];
  List<_MentionCandidate> _filtered = [];
  int _highlight = 0;
  // 当前会话是否已发起候选加载;跨会话置回 false 触发重新加载(成员可能变化)
  bool _sessionPrepared = false;
  String _lastQuery = '';
  int _loadSeq = 0;
  String _allMembersLabel = '';

  void attach(BuildContext context) {
    _overlayState = Overlay.of(context, rootOverlay: true);
    _allMembersLabel = AppLocalizations.of(context)!.allMembers;
    inputBarController.addListener(_sync);
  }

  void dispose() {
    inputBarController.removeListener(_sync);
    _hide();
    _scrollController.dispose();
  }

  bool get _sessionActive =>
      inputBarController.hasMentionSession &&
      inputBarController.focusNode.hasFocus;

  void _sync() {
    if (!inputBarController.hasMentionSession) {
      _sessionPrepared = false;
      _hide();
      return;
    }
    // 失焦只隐藏浮层不结束会话,焦点回来(输入继续)时恢复
    if (!inputBarController.focusNode.hasFocus) {
      _hide();
      return;
    }
    if (!_sessionPrepared) {
      _sessionPrepared = true;
      _loadCandidates();
      return; // 候选就绪后在 _loadCandidates 里展示
    }
    _applyFilter(resetHighlight: inputBarController.mentionQuery != _lastQuery);
  }

  Future<void> _loadCandidates() async {
    final int seq = ++_loadSeq;
    final List<_MentionCandidate> loaded = await _buildCandidates();
    if (seq != _loadSeq || !_sessionActive) {
      return;
    }
    _candidates = loaded;
    _applyFilter(resetHighlight: true);
  }

  Future<List<_MentionCandidate>> _buildCandidates() async {
    final Conversation conversation = inputBarController.conversation;
    final List<UserInfo> users = [];
    bool withMentionAll = false;

    if (conversation.conversationType == ConversationType.Group) {
      final List<GroupMember> members =
          await Imclient.getGroupMembers(conversation.target);
      final GroupMember me = members.firstWhere(
          (m) => m.memberId == Imclient.currentUserId,
          orElse: () => GroupMember());
      withMentionAll = me.type == GroupMemberType.Owner ||
          me.type == GroupMemberType.Manager;

      final List<String> memberIds = members
          .map((m) => m.memberId)
          .where((id) => id != Imclient.currentUserId)
          .toList();
      if (memberIds.isNotEmpty) {
        users.addAll(await Imclient.getUserInfos(memberIds,
            groupId: conversation.target));
      }
      // 配置的 AI 机器人即使不在群里也可以 @(沿用原选人页逻辑)
      for (final String robotId in Config.AI_ROBOTS) {
        if (robotId == Imclient.currentUserId ||
            users.any((u) => u.userId == robotId)) {
          continue;
        }
        final UserInfo? robot = await Imclient.getUserInfo(robotId);
        if (robot != null) {
          users.add(robot);
        }
      }
    } else if (conversation.conversationType == ConversationType.Single) {
      // 单聊可以 @ 机器人(沿用原选人页逻辑):候选是配置的 AI 机器人;
      // 对方本身是机器人(type == 1)但不在配置里时也补进来
      for (final String robotId in Config.AI_ROBOTS) {
        if (robotId == Imclient.currentUserId) {
          continue;
        }
        final UserInfo? robot = await Imclient.getUserInfo(robotId);
        if (robot != null) {
          users.add(robot);
        }
      }
      if (!users.any((u) => u.userId == conversation.target)) {
        final UserInfo? peer = await Imclient.getUserInfo(conversation.target);
        if (peer != null && peer.type == 1) {
          users.add(peer);
        }
      }
    }

    final List<_MentionCandidate> candidates =
        users.map(_MentionCandidate.fromUser).toList();
    if (withMentionAll) {
      candidates.insert(0, _MentionCandidate.allMembers(_allMembersLabel));
    }
    return candidates;
  }

  void _applyFilter({required bool resetHighlight}) {
    final String query = inputBarController.mentionQuery;
    _lastQuery = query;
    _filtered = query.isEmpty
        ? List.of(_candidates)
        : _candidates.where((c) => c.matches(query)).toList();
    if (_filtered.isEmpty) {
      _hide();
      return;
    }
    if (resetHighlight || _highlight >= _filtered.length) {
      _highlight = 0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
    _show();
  }

  /// 浮层可见时消费导航按键;输入法组合中(中文候选未上屏)按键属于输入法。
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (_entry == null || _filtered.isEmpty || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (inputBarController.textEditingController.value.composing.isValid) {
      return KeyEventResult.ignored;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      if (event is KeyDownEvent) {
        _select(_filtered[_highlight]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      inputBarController.cancelMentionSession(); // 会话结束,_sync 收起浮层
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveHighlight(int delta) {
    _highlight = (_highlight + delta + _filtered.length) % _filtered.length;
    _ensureHighlightVisible();
    _entry?.markNeedsBuild();
  }

  void _ensureHighlightVisible() {
    if (!_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    final double top = _highlight * _rowHeight;
    final double bottom = top + _rowHeight;
    if (top < position.pixels) {
      _scrollController.jumpTo(top);
    } else if (bottom > position.pixels + position.viewportDimension) {
      _scrollController.jumpTo(bottom - position.viewportDimension);
    }
  }

  void _select(_MentionCandidate candidate) {
    inputBarController.completeMention(candidate.user); // 会话结束,_sync 收起浮层
  }

  void _show() {
    _updateAnchor();
    if (_entry == null) {
      _entry = OverlayEntry(builder: _buildPanel);
      _overlayState?.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  /// 反查 '@' 在屏幕上的位置。必须在 build 之外调用(这里是控制器回调里),
  /// 读到的是上一帧的排版:'@' 之后的键入只改查询串、不移动 '@',所以够用。
  void _updateAnchor() {
    final RenderObject? overlayObject =
        _overlayState?.context.findRenderObject();
    final RenderObject? fieldObject =
        textFieldKey.currentContext?.findRenderObject();
    if (overlayObject is! RenderBox ||
        fieldObject is! RenderBox ||
        !fieldObject.hasSize) {
      return;
    }
    _overlaySize = overlayObject.size;

    final RenderEditable? editable = _findRenderEditable(fieldObject);
    final int index = inputBarController.mentionAtIndex;
    if (editable == null || !editable.hasSize || index < 0) {
      // 退回输入框左上角:位置不精确但浮层仍在输入框附近,不会飞到窗口角上
      _anchor =
          overlayObject.globalToLocal(fieldObject.localToGlobal(Offset.zero));
      return;
    }
    // getLocalRectForCaret 已含输入框自身的滚动位移,localToGlobal 即得屏幕位置
    final Rect caret =
        editable.getLocalRectForCaret(TextPosition(offset: index));
    _anchor =
        overlayObject.globalToLocal(editable.localToGlobal(caret.topLeft));
  }

  static RenderEditable? _findRenderEditable(RenderObject root) {
    if (root is RenderEditable) {
      return root;
    }
    RenderEditable? found;
    root.visitChildren((RenderObject child) {
      found ??= _findRenderEditable(child);
    });
    return found;
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  Widget _buildPanel(BuildContext context) {
    final Offset? anchor = _anchor;
    if (anchor == null) {
      // 拿不到锚点(渲染树未就绪)就先不画,免得浮层跑到窗口角上
      return const SizedBox.shrink();
    }
    final double listHeight =
        math.min(_filtered.length, _maxVisibleRows) * _rowHeight + 8;

    // 水平居中对齐 '@',贴窗口边时整体推回窗口内(箭头仍留在 '@' 上方)
    final double maxLeft = math.max(
        _windowMargin, _overlaySize.width - _panelWidth - _windowMargin);
    final double left =
        (anchor.dx - _panelWidth / 2).clamp(_windowMargin, maxLeft).toDouble();
    // 箭头尖顶在 '@' 行上方,浮层整体再往上叠;顶部超出窗口时下压(极窄窗口才会发生)
    final double top = math.max(
        _windowMargin, anchor.dy - _anchorGap - _arrowHeight - listHeight);
    // 浮层被推回窗口内后箭头相对面板的位置随之改变,但不能顶到面板圆角上
    final double arrowCenter = (anchor.dx - left)
        .clamp(_arrowWidth / 2 + 6, _panelWidth - _arrowWidth / 2 - 6)
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: _panelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: context.colors.popupBg,
            elevation: 6,
            shadowColor: context.colors.shadow,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              // Column 的交叉轴约束是松的,面板宽度要自己定死
              width: _panelWidth,
              height: listHeight,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemExtent: _rowHeight,
                itemCount: _filtered.length,
                itemBuilder: (context, index) => _MentionRow(
                  candidate: _filtered[index],
                  highlighted: index == _highlight,
                  onHover: () {
                    if (_highlight != index) {
                      _highlight = index;
                      _entry?.markNeedsBuild();
                    }
                  },
                  onTap: () => _select(_filtered[index]),
                ),
              ),
            ),
          ),
          // 画在面板之后,盖住面板投影在这一小块上的暗色,箭头与面板连成一体
          Padding(
            padding: EdgeInsets.only(left: arrowCenter - _arrowWidth / 2),
            child: CustomPaint(
              size: const Size(_arrowWidth, _arrowHeight),
              painter: _MentionArrowPainter(context.colors.popupBg),
            ),
          ),
        ],
      ),
    );
  }
}

/// 浮层底部指向 '@' 的小三角。
class _MentionArrowPainter extends CustomPainter {
  const _MentionArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MentionArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// @ 候选项:预计算显示名的拼音检索串,避免每次键入重复转换。
class _MentionCandidate {
  _MentionCandidate._(this.user, this.display, this.isAllMembers)
      : _searchKey =
            '$display\n${PinyinHelper.getPinyinE(display, separator: '')}\n${PinyinHelper.getShortPinyin(display)}'
                .toLowerCase();

  factory _MentionCandidate.fromUser(UserInfo user) =>
      _MentionCandidate._(user, MeshUserDisplay.getReadableName(user), false);

  /// "@所有人" 伪候选:userId 固定 '@all',发送时转成 mentionedType 2
  factory _MentionCandidate.allMembers(String label) =>
      _MentionCandidate._(UserInfo('@all')..displayName = label, label, true);

  final UserInfo user;
  final String display;
  final bool isAllMembers;
  final String _searchKey;

  bool matches(String query) => _searchKey.contains(query.toLowerCase());
}

class _MentionRow extends StatelessWidget {
  final _MentionCandidate candidate;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _MentionRow(
      {required this.candidate,
      required this.highlighted,
      required this.onHover,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // 形态对齐消息右键菜单项(左右留白 + 圆角),但选中态用浅灰而非强调色
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: highlighted
                ? context.colors.cellHoverDesktop
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (candidate.isAllMembers)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.campaign_outlined,
                      size: 16, color: context.colors.accent),
                )
              else
                Portrait(
                  candidate.user.portrait ?? Config.defaultUserPortrait,
                  Config.defaultUserPortrait,
                  width: 26,
                  height: 26,
                  borderRadius: 4,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  candidate.display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sm.copyWith(color: context.colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
