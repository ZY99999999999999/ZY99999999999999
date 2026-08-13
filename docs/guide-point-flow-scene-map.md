# 引导点场景地图（业务阅读版）

## 先看全貌

`guide-point-flow-v2` 当前共有 **84 条静态路由场景**。这里的“一条场景”指一次请求最终会命中的一套路由配置，而不是配置内并行执行的单个 scene。

| 业务场景簇 | 路由场景数 | 构成 |
|---|---:|---|
| 根兜底 | 1 | 未配置的 `req_type` |
| 订单 / 预估主链 | 25 | 4 个 req_type 默认场景 + 21 条 caller 专属场景 |
| 订单状态 / 缓存分流 | 13 | 11 个默认场景 + 2 条 caller 专属场景 |
| 地图 POI / 二次确认 | 21 | 21 个默认场景 |
| 拖拽 / 坐标选点 | 4 | 4 个默认场景 |
| 海豚 / 导航 | 7 | 5 个默认场景 + 2 条 caller 专属场景 |
| 智能小巴 / 线网 | 6 | 6 个默认场景 |
| 触发 / 离线 / 旧接口兼容 | 7 | 7 个默认场景 |
| **合计** | **84** | **58 个 req_type 默认 + 25 条 caller 专属 + 1 条根兜底** |

### 怎么读这张地图

1. 先根据 `req_type` 找到默认场景；
2. 若同一行下列出了 `caller_id` 专属场景，则 caller 精确命中时覆盖默认场景；
3. 未命中任何 req_type 时，走根兜底；
4. 同一条路由配置内的多个执行 scene 可以并行，随后合并；`caller_id` 本身不会并行执行。

> `caller_id=*` 的含义是“该 req_type 下没有命中 caller 专属配置时的默认路径”，不是“所有 caller 都执行”。

---

## 0. 根兜底（1 条）

| `req_type` | `caller_id` | 业务含义 | 实际执行 |
|---|---|---|---|
| 未知 | 任意 | 新/错误 req_type 未配置时的兜底 | `trip_union_ne` |

---

## 1. 订单 / 预估主链（25 条）

### 默认场景：4 条

| `req_type` | `caller_id` | 业务含义 | 默认执行链路 |
|---|---|---|---|
| `trip` | 除下方 13 个专属 caller 外 | 常规下车引导 | union 召回 + 步行/骑行 + 通用/个性化 MIS + 二次确认 |
| `pickup` | 除 `OrderRouteAPI`、`route-broker` 外 | 常规接驾引导 | pickup 召回 |
| `odpoint` | 除下方 4 个专属 caller 外 | 途经点引导 | union 召回 + 个性化 MIS |
| `carpool` | 除 `route-broker`、`carpool_route_matcher` 外 | 常规拼车 | 预估缓存 top 场景 |

### caller 专属场景：21 条

#### `trip`：13 条 caller 分流

| `req_type` | `caller_id` | 一句话说明 | 与 `trip` 默认链的主要差异 |
|---|---|---|---|
| `trip` | `OrderRouteAPI` | 订单下车 | 增加订单无违停 top 缓存、additional / link bind / 特征输出 union、POI 校验 |
| `trip` | `wanliu_order_created` | 订单创建消费 | 使用 RPC 缓存；使用特征输出 union；带步行/骑行 |
| `trip` | `wanliu_passenger_estimate_req` | 乘客预估 | additional + link bind + union + 步行/骑行 + MIS + dbck |
| `trip` | `route-broker` | 路由 broker | 使用 RPC 缓存、预估缓存；不走 link bind / union 主召回 |
| `trip` | `carpool_route_matcher` | 拼车匹配 | 缩减为 additional + dbck，并使用拼车订单缓存 |
| `trip` | `map_api` | 旧地图 API | 仅执行 `map_api_castle` |
| `trip` | `dolphin_api` | 海豚导航 | 切为海豚 bind、可停靠、dolphin/MIS、前缀拦截、远距/AOI 链 |
| `trip` | `DavinciNaviAPI` | Davinci 导航 | 海豚导航变体；不含前缀拦截 |
| `trip` | `NaviAPI_self_navi` | 自导航 | 海豚 bind / 可停靠 / dolphin / MIS 的精简链 |
| `trip` | `BicyclingNaviAPI` | 骑行导航 | additional + 骑行导航 + 门点 + 骑行 MIS |
| `trip` | `beatles_point2point` | 点到点 | union + 个性化 MIS |
| `trip` | `map_manta_anycar_subway_combine` | 任意车型 + 地铁 | additional + union + 多点 + MIS + dbck；重置 `m_type` |
| `trip` | `map_manta_bicycle_subway_combine` | 骑行 + 地铁 | additional + union + 多点 + 骑行 MIS |

#### `pickup`：2 条 caller 分流

| `req_type` | `caller_id` | 一句话说明 | 实际执行链路 |
|---|---|---|---|
| `pickup` | `OrderRouteAPI` | 订单接驾 | bind link + pickup + pickup 缓存 + 原始接驾 |
| `pickup` | `route-broker` | broker 接驾 | pickup 缓存 + 原始接驾 |

#### `odpoint`：4 条 caller 分流

| `req_type` | `caller_id` | 一句话说明 | 实际执行链路 |
|---|---|---|---|
| `odpoint` | `wanliu_passenger_estimate_req` | 预估途经点 | additional + link bind + union + MIS + dbck + POI 校验 |
| `odpoint` | `route-broker` | broker 途经点 | additional + link bind + MIS + 预估缓存 + dbck + POI 校验 |
| `odpoint` | `wanliu_order_created` | 订单途经点 | RPC 缓存 + additional + link bind + 特征输出 union + MIS + dbck |
| `odpoint` | `OrderRouteAPI` | 订单途经点 | 订单 top 缓存 + additional + link bind + union + MIS + dbck |

#### `carpool`：2 条 caller 分流

| `req_type` | `caller_id` | 一句话说明 | 实际执行链路 |
|---|---|---|---|
| `carpool` | `route-broker` | broker 拼车 | 预估 top 缓存 + additional + 通用/个性化 MIS + dbck |
| `carpool` | `carpool_route_matcher` | 拼车匹配 | 拼车订单 top 缓存 + additional + dbck |

---

## 2. 订单状态 / 缓存分流（13 条）

### 默认场景：11 条

| `req_type` | `caller_id` | 触发的业务状态 | 实际执行链路 |
|---|---|---|---|
| `trip_top1_park` | 除下方 2 个专属 caller 外 | 下车 top1 命中违停 | additional + link bind + union + 通用/个性化 MIS + dbck + POI 校验 |
| `estimate_real_time` | 任意 | 预估实时快速链 | RPC 缓存 + additional + link bind + 特征输出 union + 步行/骑行 + MIS + 预估缓存 |
| `passenger_estimate_trip_req` | 任意 | 写入乘客预估下车缓存 | additional + link bind + union + MIS + dbck，并写预估缓存 |
| `passenger_estimate_pickup_req` | 任意 | 写入乘客预估接驾缓存 | bind link + pickup，并写预估缓存 |
| `estimate_trip` | 任意 | 普通预估下车 | additional + link bind + union + MIS + dbck |
| `model_predict_cache` | 任意 | 非个性化模型点位预判 | RPC 缓存 + 通用 union + MIS + dbck + POI 校验 |
| `dbck_trip` | 任意 | 命中二次确认页 | 仅 `dbck_scene` |
| `dropoff_cell_link` | 任意 | cell + link 类型下车 | 仅 `cell_link_dropoff` |
| `dropoff_link_lng_lat` | 任意 | link 经纬度片段下车 | 仅 `link_lng_lat_dropoff` |
| `navi_park` | 任意 | 导航停车 | 仅订单 top 缓存场景 |
| `quad_express` | 任意 | 四轮快送取货转下车 | 订单无违停 top 缓存 + additional + link bind + 特征输出 union + MIS + dbck |

### `trip_top1_park` caller 专属场景：2 条

| `req_type` | `caller_id` | 一句话说明 | 主要差异 |
|---|---|---|---|
| `trip_top1_park` | `wanliu_passenger_estimate_req` | 预估链命中违停 | 预估版 trip 链，含步行/骑行 |
| `trip_top1_park` | `wanliu_order_created` | 订单链命中违停 | 订单特征输出 union + RPC 缓存 + 步行/骑行 |

---

## 3. 地图 POI / 二次确认（21 条）

| `req_type` | `caller_id` | 业务场景 | 实际执行链路 |
|---|---|---|---|
| `castle` | 任意 | 围栏点推荐 | POI 召回 + 孤岛召回 + 新围栏召回 |
| `park` | 任意 | 停车点推荐 | 停车 POI 召回 |
| `broad` | 任意 | 宽泛推荐 | 通用 POI 召回 |
| `station` | 任意 | 站点推荐 | 通用 POI 召回 |
| `multiple` | 任意 | 多点推荐 | 多点 POI 召回 |
| `mis` | 任意 | MIS + 模型兜底 | 个性化 MIS + 通用 MIS + 通用 POI 兜底 |
| `pure_mis` | 任意 | 纯 MIS | 个性化 MIS + 通用 MIS；无模型 POI 兜底 |
| `unreach` | 任意 | 不可达点处理 | 不可达 POI 召回 |
| `island` | 任意 | 孤岛处理 | 孤岛 POI 召回 |
| `far_away` | 任意 | 远距离下车 | 通用 POI + 远距 POI 召回 |
| `acc_far_away` | 任意 | 加速远距离下车 | 加速远距 POI 召回 |
| `scenic_area` | 任意 | 景区二次确认 | 景区场景 + 景区 MIS |
| `bus` | 任意 | 公交站二次确认 | 公交站 POI 召回 |
| `risk` | 任意 | 风险二次确认 | 风险 POI 召回 |
| `broad_area` | 任意 | 宽泛二次确认 | 宽泛二次确认场景 |
| `cpo` | 任意 | CPO 推荐 | CPO POI 召回 |
| `spatial` | 任意 | 空间选点 | 空间 POI 召回 |
| `endinfo` | 任意 | 终点信息展示 | 终点信息 POI 召回 |
| `second_page` | 任意 | 通用二次确认页 | 通用 POI 召回 |
| `default` | 任意 | 地图通用默认请求 | 通用 POI + 通用 MIS + 围栏 + dbck |
| `search_default` | 任意 | 搜索默认请求 | 通用 POI + 通用 MIS + 围栏 + dbck |

> 这 21 条均没有 caller 专属覆盖；同一 `req_type` 下 caller 不同，静态路由保持一致。

---

## 4. 拖拽 / 坐标选点（4 条）

| `req_type` | `caller_id` | 业务场景 | 实际执行链路 |
|---|---|---|---|
| `valet_driver` | 任意 | 代驾司机拖点 | didirgeo 反解 |
| `hac_drag` | 任意 | HAC 拖图选点 | didirgeo + 围栏 + 孤岛 + 可停靠 link + 空间召回 |
| `drag` | 任意 | 通用拖图选点 | didirgeo + 围栏 + 孤岛 + 可停靠 link + 空间召回 |
| `specify_coordinate` | 任意 | 指定坐标选点（vivo） | didirgeo + 围栏 + 孤岛 + 可停靠 link + 空间召回 |

> 三个通用拖拽类型 `hac_drag`、`drag`、`specify_coordinate` 使用同一套静态 scene 编排，但仍保留为 3 条独立场景，便于按请求语义、实验和日志区分。

---

## 5. 海豚 / 导航（7 条）

### 默认场景：5 条

| `req_type` | `caller_id` | 业务场景 | 实际执行链路 |
|---|---|---|---|
| `valet_driving` | 任意 | 代驾乘客侧引导 | 海豚 bind + 可停靠 union / personal MIS + 代驾场景 |
| `dolphin_poi_detail` | 任意 | 海豚 POI 详情 | 海豚最后一公里 bind + dolphin 召回 |
| `dolphin_point_rec` | 除下方 2 个专属 caller 外 | 海豚最后一公里推荐 | 最后一公里 bind / 可停靠 / MIS / dolphin / 远距 / AOI |
| `jw_trip` | 任意 | JW 引导 | `jw_union_ne` |
| `auto_drive_voyager` | 任意 | 自动驾驶 Voyager | Voyager 场景 + dbck |

### `dolphin_point_rec` caller 专属场景：2 条

| `req_type` | `caller_id` | 一句话说明 | 主要差异 |
|---|---|---|---|
| `dolphin_point_rec` | `dolphin_api` | 海豚 API 最后一公里 | 默认最后一公里链 + 指标 union |
| `dolphin_point_rec` | `textsearch` | 文本搜索接入海豚 | bind + 可停靠 personal MIS + dolphin/MIS；不走 last 版本链 |

---

## 6. 智能小巴 / 线网（6 条）

| `req_type` | `caller_id` | 业务场景 | 实际执行链路 |
|---|---|---|---|
| `minbus_bubble_station` | 任意 | 小巴气泡站点 | 小巴站点 + 围栏 MIS + 点位保护 |
| `minbus_bubble_station_expend` | 任意 | 小巴气泡站点扩召回 | 扩召回小巴站点 + 围栏 MIS |
| `intelligent_minbus_station` | 任意 | 智能小巴站点 | 保护点 + 智能小巴 + 定位点 + 围栏 MIS |
| `intelligent_minbus_express_station` | 任意 | 智能小巴快线 | 快线场景 + 快线围栏 MIS + 快线保护 |
| `scancode_minbus_station` | 任意 | 智能小巴扫码 | 扫码小巴场景 + 小巴保护 |
| `net_platform` | 任意 | 线网平台 | 线网场景 + 公交地铁场景 |

---

## 7. 触发 / 离线 / 旧接口兼容（7 条）

| `req_type` | `caller_id` | 业务场景 | 实际执行链路 |
|---|---|---|---|
| `trigger` | 任意 | 离线/触发型生成 | union、parkable、MIS、fusion、景区、公交、风险、宽泛等触发 scene |
| `offline_cluster_rec` | 任意 | 离线聚类召回 | `additional_scene` |
| `castle_old` | 任意 | 旧围栏 API | `map_api_castle` |
| `park_old` | 任意 | 旧停车 API | `map_api_park` |
| `broad_old` | 任意 | 旧宽泛 API | `map_api_broad_station` |
| `station_old` | 任意 | 旧站点 API | `map_api_broad_station` |
| `hint` | 任意 | 无 end_request_tag 的旧地图 API | `hint_scene` |

---

## 与运行时的关系

上面 84 条是从 `parameter.conf` 直接得出的**静态场景库**。代码还会把原始请求改写成最终 `req_type`，运行时场景库应补充如下映射：

| 原始条件 | 最终执行场景 |
|---|---|
| `caller_id=map_api` 且带 `end_request_tag` | `<end_request_tag>_old` |
| `caller_id=map_api` 且不带 `end_request_tag` | `hint` |
| 命中四轮快送实验 | `quad_express` |
| 命中实时预估实验且 `origin_caller_id` 非空 | `estimate_real_time` |
| 订单/预估消费命中二次确认、cell/link、违停 | `dbck_trip` / `dropoff_cell_link` / `dropoff_link_lng_lat` / `trip_top1_park` |

完整的配置字段、每条场景的 `scene_merge`、`union_processer`、降级链路与精确配置行号，见同目录的技术核对版 `guide-point-flow-static-scene-catalog.md`。

