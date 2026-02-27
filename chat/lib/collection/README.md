# 群接龙功能

群接龙功能的 Flutter 实现，与 Android 端功能和 UI 对齐。

## 功能特性

- 发起群接龙（仅限群组）
- 设置接龙标题、描述、参与模板
- 设置接龙过期时间
- 参与接龙并填写内容
- 查看接龙详情和参与列表
- 修改或删除自己的参与记录
- 接龙消息在聊天列表中的展示

## 目录结构

```
collection/
├── collection.dart                 # 导出文件
├── collection_model.dart           # Collection 模型（CollectionEntry 从 imclient 导出）
├── collection_service.dart         # 接龙服务工具类（静态方法）
├── collection_detail_screen.dart   # 接龙详情页面
├── create_collection_screen.dart   # 创建接龙页面
├── collection_icon.dart            # 接龙图标组件
└── README.md                       # 本文件
```

## 配置方法

在 `chat/lib/config.dart` 中配置接龙服务地址：

```dart
// 接龙服务地址，如果需要接龙功能，请部署接龙服务并配置地址；如果不需要接龙功能，请置为 null
// 示例：http://192.168.1.81:8081
static String? COLLECTION_SERVER_ADDRESS = "https://jielong.wildfirechat.net";
```

**说明**:
- 如果 `COLLECTION_SERVER_ADDRESS` 为 `null` 或空字符串，接龙功能将不会显示在插件面板中
- 配置有效的地址后，群聊插件面板会自动显示接龙入口

## 使用方法

### 检查服务是否可用

```dart
if (CollectionService.isAvailable) {
  // 接龙服务可用
}
```

### 创建接龙

```dart
final collection = await CollectionService.create(
  groupId: 'groupId',
  title: '接龙标题',
  desc: '接龙描述',
  template: '姓名-电话',
  expireType: 1,
  expireAt: DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch,
);
```

### 获取接龙详情

```dart
final collection = await CollectionService.getCollection(collectionId, groupId);
```

### 参与接龙

```dart
await CollectionService.join(collectionId, groupId, '参与内容');
```

### 删除参与记录

```dart
await CollectionService.deleteEntry(collectionId, groupId);
```

### 关闭接龙

```dart
await CollectionService.close(collectionId, groupId);
```

## API 接口

接龙服务需要以下后端 API 支持：

### 创建接龙
```
POST /api/collections
Headers: { "authCode": "xxx" }
Body: {
  "groupId": "string",
  "title": "string",
  "description": "string?",
  "template": "string?",
  "expireType": 0|1,
  "expireAt": 0|timestamp,
  "maxParticipants": 0
}
```

### 获取接龙详情
```
POST /api/collections/{collectionId}/detail
Headers: { "authCode": "xxx" }
Body: {
  "groupId": "string"
}
```

### 参与接龙
```
POST /api/collections/{collectionId}/join
Headers: { "authCode": "xxx" }
Body: {
  "groupId": "string",
  "content": "string"
}
```

### 删除参与记录
```
POST /api/collections/{collectionId}/delete
Headers: { "authCode": "xxx" }
Body: {
  "groupId": "string"
}
```

### 关闭接龙
```
POST /api/collections/{collectionId}/close
Headers: { "authCode": "xxx" }
Body: {
  "groupId": "string"
}
```

## 认证方式

接龙服务使用 `getAuthCode` 获取认证码进行 API 调用：
- authCodeId = "collection"
- authCodeType = 2
- 认证码通过 HTTP Header `authCode` 传递

## 消息类型

接龙消息类型值为 `17`，定义在 `imclient/lib/message/collection_message_content.dart`。

## 图标说明

接龙图标使用自定义 Flutter Widget (`CollectionIcon`) 实现，与 Android 端 `ic_collection.xml` 样式保持一致。
