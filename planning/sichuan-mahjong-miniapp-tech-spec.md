# 四川麻将微信小程序技术架构设计 + 数据表设计 + 接口清单

## 1. 技术目标

目标是搭建一套适合四川麻将实时对局的小程序技术体系，满足以下要求：

- 服务端作为唯一权威，保证对局一致性
- 支持 4 人实时房间对战
- 支持断线重连与基础托管
- 支持战绩记录和后续规则扩展
- 支持从 MVP 平滑扩展到匹配场和运营活动

## 2. 总体架构

系统分为四层：

- 小程序客户端
- 网关与业务服务
- 游戏实时服务
- 数据与缓存层

建议架构如下：

1. 微信小程序前端
2. API 网关 / 应用服务
3. WebSocket 网关
4. 房间服务
5. 麻将规则引擎
6. 结算服务
7. 战绩服务
8. 用户服务
9. MySQL
10. Redis

## 3. 技术选型建议

### 3.1 前端

- 框架：微信原生小程序 或 Taro
- 语言：TypeScript
- 状态管理：轻量 store 或页面级状态
- 通信方式：
  - HTTP：登录、房间列表、战绩等非实时接口
  - WebSocket：房间状态、对局动作、广播消息

建议首版优先微信原生小程序 + TypeScript，原因是对接微信能力更直接，包体和运行时约束也更可控。

### 3.2 服务端

- 语言：Node.js + TypeScript
- 框架：NestJS 或 Fastify + 自定义模块化架构
- 通信：
  - HTTP 提供业务接口
  - WebSocket 提供实时对局消息

建议首版采用 `NestJS + WebSocket + TypeScript`，便于模块化拆分和长期维护。

### 3.3 存储层

- MySQL：持久化用户、房间、战绩、结算、日志
- Redis：在线状态、房间快照、会话缓存、锁

## 4. 核心架构原则

### 4.1 服务端权威

- 发牌、判胡、碰杠校验、结算全部在服务端完成
- 客户端不能提交“我胡了”的最终结果，只能提交“申请胡牌”
- 客户端展示数据必须来源于服务端广播或快照

### 4.2 对局状态机驱动

整个牌局通过状态机驱动，避免分散逻辑导致规则错乱。

建议状态枚举：

- `WAITING`
- `DEALING`
- `EXCHANGE_THREE`
- `CHOOSE_LACK`
- `PLAYING`
- `SETTLING_ROUND`
- `SETTLING_ROOM`
- `CLOSED`

### 4.3 操作日志可追溯

- 每次关键动作记录到操作日志
- 支持断线恢复
- 支持争议排查
- 支持后续回放扩展

## 5. 服务模块设计

### 5.1 用户服务 `user-service`

职责：

- 微信登录
- 用户信息同步
- 登录态校验
- 用户资产读取

### 5.2 房间服务 `room-service`

职责：

- 创建房间
- 加入房间
- 房间规则存储
- 座位分配
- 房间生命周期管理

### 5.3 对局服务 `game-service`

职责：

- 洗牌发牌
- 回合推进
- 可执行动作计算
- 状态广播
- 对局快照生成

### 5.4 规则引擎 `rule-engine`

职责：

- 牌型合法性校验
- 定缺限制判断
- 碰杠胡判定
- 听牌 / 胡牌判定
- 番型计算
- 结算分计算

### 5.5 结算服务 `settlement-service`

职责：

- 单局结算
- 总局结算
- 分数入账
- 战绩明细生成

### 5.6 连接服务 `gateway-service`

职责：

- WebSocket 连接管理
- 心跳
- 断线检测
- 重连恢复
- 消息转发

## 6. 实时消息设计

### 6.1 客户端到服务端消息

- `room.join`
- `room.leave`
- `room.ready`
- `game.start`
- `game.exchangeThree`
- `game.chooseLack`
- `game.discard`
- `game.action`
- `game.reconnect`
- `game.trusteeship`
- `ping`

### 6.2 服务端到客户端消息

- `room.joined`
- `room.playerChanged`
- `room.started`
- `game.dealt`
- `game.exchangeResult`
- `game.lackChosen`
- `game.turnChanged`
- `game.actionPrompt`
- `game.playerAction`
- `game.roundSettled`
- `game.roomSettled`
- `game.snapshot`
- `game.trusteeshipChanged`
- `pong`
- `error`

## 7. 对局流程设计

### 7.1 开局流程

1. 房主创建房间
2. 玩家加入房间
3. 满 4 人后房主点击开始
4. 服务端生成牌堆并发牌
5. 进入换三张
6. 进入定缺
7. 进入正式出牌阶段

### 7.2 出牌阶段流程

1. 当前玩家摸牌
2. 服务端计算该玩家可执行操作
3. 客户端展示出牌和可选操作
4. 玩家出牌
5. 服务端广播出牌结果
6. 服务端依次判断其余玩家是否可胡、碰、杠
7. 若有多个动作冲突，按优先级裁决
8. 完成动作后进入下一轮

### 7.3 优先级建议

- 胡 > 杠 > 碰 > 过
- 同优先级按座位顺序或规则配置判定

## 8. 数据表设计

以下为 MVP 阶段核心表。

### 8.1 `users`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 用户 ID |
| open_id | varchar(64) | 微信 openid |
| union_id | varchar(64) nullable | 微信 unionid |
| nickname | varchar(64) | 昵称 |
| avatar_url | varchar(255) | 头像 |
| gender | tinyint | 性别 |
| status | tinyint | 状态 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

索引建议：

- `uniq_open_id(open_id)`

### 8.2 `user_assets`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 主键 |
| user_id | bigint | 用户 ID |
| room_card | int | 房卡数 |
| gold | bigint | 金币 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

索引建议：

- `uniq_user_id(user_id)`

### 8.3 `rooms`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 房间主键 |
| room_no | varchar(16) | 房间号 |
| owner_user_id | bigint | 房主 |
| status | varchar(32) | 房间状态 |
| round_total | int | 总局数 |
| pay_mode | varchar(16) | 支付方式 |
| rule_config | json | 规则配置 |
| current_round | int | 当前局数 |
| started_at | datetime nullable | 开始时间 |
| ended_at | datetime nullable | 结束时间 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

索引建议：

- `uniq_room_no(room_no)`
- `idx_owner_user_id(owner_user_id)`

### 8.4 `room_players`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 主键 |
| room_id | bigint | 房间 ID |
| user_id | bigint | 用户 ID |
| seat_no | tinyint | 座位号 |
| is_owner | tinyint | 是否房主 |
| is_ready | tinyint | 是否准备 |
| is_online | tinyint | 是否在线 |
| total_score | int | 当前总分 |
| joined_at | datetime | 加入时间 |
| left_at | datetime nullable | 离开时间 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

索引建议：

- `uniq_room_user(room_id, user_id)`
- `uniq_room_seat(room_id, seat_no)`

### 8.5 `games`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 对局 ID |
| room_id | bigint | 房间 ID |
| round_no | int | 第几局 |
| dealer_seat_no | tinyint | 庄家座位 |
| status | varchar(32) | 对局状态 |
| current_turn_seat_no | tinyint nullable | 当前操作座位 |
| wall_count | int | 剩余牌数 |
| snapshot | json | 当前局面快照 |
| started_at | datetime | 开始时间 |
| ended_at | datetime nullable | 结束时间 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

索引建议：

- `idx_room_round(room_id, round_no)`

### 8.6 `game_players`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 主键 |
| game_id | bigint | 对局 ID |
| user_id | bigint | 用户 ID |
| seat_no | tinyint | 座位号 |
| hand_tiles | json | 手牌 |
| meld_tiles | json | 碰杠区 |
| discard_tiles | json | 弃牌区 |
| lack_suit | tinyint nullable | 定缺花色 |
| is_trusteeship | tinyint | 是否托管 |
| has_hu | tinyint | 是否已胡 |
| score_change | int | 本局分数变化 |
| detail_state | json | 补充状态 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

索引建议：

- `uniq_game_user(game_id, user_id)`

### 8.7 `game_actions`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 主键 |
| game_id | bigint | 对局 ID |
| round_no | int | 局号 |
| action_no | int | 动作序号 |
| user_id | bigint nullable | 操作用户 |
| seat_no | tinyint nullable | 操作座位 |
| action_type | varchar(32) | 动作类型 |
| action_payload | json | 动作内容 |
| created_at | datetime | 创建时间 |

索引建议：

- `idx_game_action(game_id, action_no)`

### 8.8 `game_settlements`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 主键 |
| game_id | bigint | 对局 ID |
| room_id | bigint | 房间 ID |
| round_no | int | 局号 |
| settlement_type | varchar(32) | 结算类型 |
| result_payload | json | 结算详情 |
| created_at | datetime | 创建时间 |

索引建议：

- `idx_room_round(room_id, round_no)`

### 8.9 `match_records`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 主键 |
| room_id | bigint | 房间 ID |
| user_id | bigint | 用户 ID |
| total_score | int | 总分 |
| rank_no | tinyint | 排名 |
| record_payload | json | 战绩详情 |
| created_at | datetime | 创建时间 |

索引建议：

- `idx_user_created(user_id, created_at)`

## 9. Redis 设计建议

### 9.1 键设计

- `ws:user:{userId}`：用户连接信息
- `room:{roomId}:snapshot`：房间快照
- `room:{roomId}:lock`：房间操作锁
- `game:{gameId}:action_seq`：动作序列号
- `user:{userId}:session`：登录会话

### 9.2 使用原则

- 高频状态放 Redis
- 最终结果入 MySQL
- 关键状态变更保持可恢复

## 10. HTTP 接口清单

以下接口面向小程序客户端。

### 10.1 登录与用户

#### `POST /api/auth/wechat-login`

请求参数：

```json
{
  "code": "wx_login_code",
  "userInfo": {
    "nickname": "玩家A",
    "avatarUrl": "https://example.com/avatar.png"
  }
}
```

响应示例：

```json
{
  "token": "jwt_token",
  "user": {
    "id": 1001,
    "nickname": "玩家A",
    "avatarUrl": "https://example.com/avatar.png"
  }
}
```

#### `GET /api/users/me`

用途：

- 获取当前用户信息

### 10.2 房间

#### `POST /api/rooms`

用途：

- 创建房间

请求参数：

```json
{
  "roundTotal": 8,
  "payMode": "OWNER",
  "ruleConfig": {
    "exchangeThree": true,
    "chooseLack": true,
    "allowDianPaoHu": true,
    "allowYiPaoDuoXiang": false
  }
}
```

#### `POST /api/rooms/join`

用途：

- 通过房间号加入

请求参数：

```json
{
  "roomNo": "825614"
}
```

#### `GET /api/rooms/{roomNo}`

用途：

- 查询房间信息

#### `POST /api/rooms/{roomId}/start`

用途：

- 房主开始对局

#### `POST /api/rooms/{roomId}/leave`

用途：

- 离开房间

### 10.3 战绩

#### `GET /api/records`

用途：

- 获取战绩列表

查询参数：

- `page`
- `pageSize`

#### `GET /api/records/{roomId}`

用途：

- 获取某场战绩详情

## 11. WebSocket 接口清单

连接后所有实时消息建议统一结构：

```json
{
  "event": "game.discard",
  "requestId": "req_001",
  "data": {}
}
```

### 11.1 `room.join`

请求：

```json
{
  "event": "room.join",
  "data": {
    "roomNo": "825614"
  }
}
```

### 11.2 `game.start`

请求：

```json
{
  "event": "game.start",
  "data": {
    "roomId": 2001
  }
}
```

### 11.3 `game.exchangeThree`

请求：

```json
{
  "event": "game.exchangeThree",
  "data": {
    "roomId": 2001,
    "tiles": [11, 12, 13]
  }
}
```

### 11.4 `game.chooseLack`

请求：

```json
{
  "event": "game.chooseLack",
  "data": {
    "roomId": 2001,
    "lackSuit": 3
  }
}
```

### 11.5 `game.discard`

请求：

```json
{
  "event": "game.discard",
  "data": {
    "roomId": 2001,
    "tile": 25
  }
}
```

### 11.6 `game.action`

用途：

- 碰、杠、胡、过统一动作接口

请求：

```json
{
  "event": "game.action",
  "data": {
    "roomId": 2001,
    "actionType": "PENG",
    "tile": 25
  }
}
```

### 11.7 `game.reconnect`

请求：

```json
{
  "event": "game.reconnect",
  "data": {
    "roomId": 2001
  }
}
```

响应：

- 返回 `game.snapshot`

## 12. 核心返回消息示例

### 12.1 `game.snapshot`

```json
{
  "event": "game.snapshot",
  "data": {
    "roomId": 2001,
    "gameId": 3001,
    "status": "PLAYING",
    "currentTurnSeatNo": 2,
    "wallCount": 53,
    "players": [],
    "lastDiscard": {
      "seatNo": 1,
      "tile": 25
    }
  }
}
```

### 12.2 `game.actionPrompt`

```json
{
  "event": "game.actionPrompt",
  "data": {
    "actions": ["PENG", "GANG", "PASS"],
    "targetTile": 25,
    "timeout": 10
  }
}
```

### 12.3 `game.roundSettled`

```json
{
  "event": "game.roundSettled",
  "data": {
    "roomId": 2001,
    "roundNo": 1,
    "results": []
  }
}
```

## 13. 服务端目录结构建议

```text
server/
  src/
    modules/
      auth/
      user/
      room/
      game/
      settlement/
      record/
      gateway/
    common/
    config/
    main.ts
miniapp/
  pages/
  components/
  services/
  store/
  utils/
```

## 14. 开发顺序建议

### 阶段一：规则先行

- 明确四川麻将标准规则文档
- 完成牌数据结构定义
- 完成胡牌与操作判定

### 阶段二：房间和状态机

- 完成房间创建和加入
- 完成状态机推进
- 完成 WebSocket 广播

### 阶段三：前端接入

- 完成大厅和房间页
- 完成对局页
- 接入实时消息

### 阶段四：稳定性建设

- 完成断线重连
- 完成托管逻辑
- 完成战绩查询

## 15. 风险点与建议

### 15.1 规则风险

- 四川麻将地方规则容易分歧，必须先冻结标准版本

### 15.2 一致性风险

- 多玩家同时抢操作时容易出现状态错乱，必须统一由服务端仲裁

### 15.3 合规风险

- 小程序棋牌类内容审核和商业化能力需要提前评估

## 16. 下一步输出建议

基于这份文档，下一步最值得继续补的内容是：

- 四川麻将规则说明书
- 对局状态机时序图
- MySQL 建表 SQL 初稿
- WebSocket 消息协议常量定义
- 后端模块脚手架
