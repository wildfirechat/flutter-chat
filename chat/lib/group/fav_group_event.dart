/// 收藏群组(保存到通讯录)状态变更事件。SDK 不为 setFavGroup 发事件,
/// 应用层在 setFavGroup 成功后 fire 到 [Imclient.IMEventBus],
/// 供收藏群组列表(如 PC 联系人中栏)刷新。
class FavGroupUpdatedEvent {
  final String groupId;
  final bool isFav;

  FavGroupUpdatedEvent(this.groupId, this.isFav);
}
