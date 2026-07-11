import 'dart:math' as math;

import 'package:flutter/material.dart';
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

/// 微信 PC 风格的 @ 提醒浮层:键入 '@' 后浮层出现在输入栏上方,随后续键入
/// 就地过滤候选人(匹配显示名/拼音全拼/拼音首字母);上下键移动高亮并循环,
/// Enter/Tab 选中,Esc 关闭,鼠标悬停同步高亮、点击选中。无匹配时浮层自动隐藏。
///
/// 候选范围:群聊为群成员(群主/管理员额外有"所有人")+ 配置的 AI 机器人;
/// 单聊为配置的 AI 机器人(以及对方本身是机器人的场景),无候选时键入 '@' 只是普通文本。
///
/// @ 会话状态(开启/查询串/结束)由 [MessageInputBarController] 维护,
/// 本类只负责候选加载、过滤与浮层展示,通过 [handleKeyEvent] 消费导航按键。
class PcMentionOverlay {
  PcMentionOverlay({required this.inputBarController, required this.layerLink});

  final MessageInputBarController inputBarController;
  final LayerLink layerLink;

  static const double _rowHeight = 36;
  static const double _panelWidth = 280;
  static const int _maxVisibleRows = 6;

  OverlayState? _overlayState;
  OverlayEntry? _entry;
  final ScrollController _scrollController = ScrollController();

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

  bool get _sessionActive => inputBarController.hasMentionSession && inputBarController.focusNode.hasFocus;

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
      final List<GroupMember> members = await Imclient.getGroupMembers(conversation.target);
      final GroupMember me = members.firstWhere((m) => m.memberId == Imclient.currentUserId, orElse: () => GroupMember());
      withMentionAll = me.type == GroupMemberType.Owner || me.type == GroupMemberType.Manager;

      final List<String> memberIds = members.map((m) => m.memberId).where((id) => id != Imclient.currentUserId).toList();
      if (memberIds.isNotEmpty) {
        users.addAll(await Imclient.getUserInfos(memberIds, groupId: conversation.target));
      }
      // 配置的 AI 机器人即使不在群里也可以 @(沿用原选人页逻辑)
      for (final String robotId in Config.AI_ROBOTS) {
        if (robotId == Imclient.currentUserId || users.any((u) => u.userId == robotId)) {
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

    final List<_MentionCandidate> candidates = users.map(_MentionCandidate.fromUser).toList();
    if (withMentionAll) {
      candidates.insert(0, _MentionCandidate.allMembers(_allMembersLabel));
    }
    return candidates;
  }

  void _applyFilter({required bool resetHighlight}) {
    final String query = inputBarController.mentionQuery;
    _lastQuery = query;
    _filtered = query.isEmpty ? List.of(_candidates) : _candidates.where((c) => c.matches(query)).toList();
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
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.tab) {
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
    if (_entry == null) {
      _entry = OverlayEntry(builder: _buildPanel);
      _overlayState?.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  Widget _buildPanel(BuildContext context) {
    final double listHeight = math.min(_filtered.length, _maxVisibleRows) * _rowHeight + 8;
    return Positioned(
      width: _panelWidth,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(12, -4),
        child: Material(
          color: context.colors.popupBg,
          elevation: 6,
          shadowColor: context.colors.shadow,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
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
      ),
    );
  }
}

/// @ 候选项:预计算显示名的拼音检索串,避免每次键入重复转换。
class _MentionCandidate {
  _MentionCandidate._(this.user, this.display, this.isAllMembers)
      : _searchKey = '$display\n${PinyinHelper.getPinyinE(display, separator: '')}\n${PinyinHelper.getShortPinyin(display)}'.toLowerCase();

  factory _MentionCandidate.fromUser(UserInfo user) => _MentionCandidate._(user, MeshUserDisplay.getReadableName(user), false);

  /// "@所有人" 伪候选:userId 固定 '@all',发送时转成 mentionedType 2
  factory _MentionCandidate.allMembers(String label) => _MentionCandidate._(UserInfo('@all')..displayName = label, label, true);

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

  const _MentionRow({required this.candidate, required this.highlighted, required this.onHover, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: highlighted ? context.colors.accent : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              if (candidate.isAllMembers)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? context.colors.onAccent.withValues(alpha: 0.25)
                        : context.colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.campaign_outlined,
                      size: 16, color: highlighted ? context.colors.onAccent : context.colors.accent),
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
                  style: TextStyle(
                      fontSize: 13, color: highlighted ? context.colors.onAccent : context.colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
