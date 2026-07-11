# photo_view 0.15.0(本地补丁版)

来源:pub.dev `photo_view: 0.15.0`,为实现微信式媒体预览手势打了两个补丁。
升级 photo_view 时需要把这两个补丁重新套用。

## 补丁 1:双指缩放以手势焦点为锚点

`lib/src/core/photo_view_core.dart` — `onScaleStart` / `onScaleUpdate`

原实现 `position = (P0 + F - F0) * details.scale`,缩放始终绕图片中心。
改为保持手势开始时位于双指中点下方的图像点始终跟随当前焦点:

```
P' = focal - (focalStart - P0) * details.scale
```

坐标统一换算到视口中心原点(使用 `details.localFocalPoint` 与
`scaleBoundaries.outerSize`)。纯平移(details.scale == 1)时行为与原实现一致。

## 补丁 2:双击定点放大 / 复位

- `lib/src/core/photo_view_gesture_detector.dart`:新增 `onDoubleTapDown`
  参数,用于拿到双击位置。
- `lib/src/core/photo_view_core.dart`:`onDoubleTap` 不再走
  `nextScaleState()`(绕中心循环缩放),改为:
  - 未放大时,以双击点为锚点放大到 `max(covering, 2 × initialScale)`
    (clamp 到 min/max);
  - 已放大时,动画回到初始大小并居中。
  - 通过 `scaleStateController.setInvisibly(...)` 同步缩放状态:跳过内部
    自动居中动画,但仍会推送 `outputScaleStateStream`,因此外层
    `scaleStateChangedCallback` 依然收到通知(chat 端靠它维护 isZoomed)。
