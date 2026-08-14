# guide-point-flow 拆分后的统一场景清单（评审版）

## 使用口径

本清单用于 mentor/leader 评审“场景是否拆对”，不是只列 84 条 `parameter.conf` 路由。

每一条可重跑的统一场景都应满足：

```text
接口 + 最终命中路由(req_type/caller_id) + 关键请求前置条件 + response 断言
```

- **已验证**：case 中存在 response 断言，可作为统一验证场景候选；
- **仅执行**：case 到达该路由但没有有效 response 断言，不能用于失败后自动重跑；
- **待补 case**：仅有代码路由，当前没有匹配 case；
- `CV-xxx` 是可追溯的 response 验证证据 ID。每条 CV 的 case 文件、行号和原始 assert，见 [代码—case 全量证据](guide-point-flow-code-case-scene-library.md)。

> 同一路由中 response 预期不同必须拆分；例如 AOI 展示/不展示、跨路 high/no、单请求/批量请求，均不是同一个统一场景。

## 1. 根兜底（1 条）

| 路由 | 拆分后的验证场景 | 结论 |
|---|---|---|
| `*:*` | `GP-FALLBACK-UNKNOWN-REQUEST`：未知 `req_type` 的错误码/兜底返回 | 待补 case |

## 2. 订单 / 预估主链（25 条）

| 路由 | 拆分后的验证场景（response 不同即不同场景） | 证据 / 结论 |
|---|---|---|
| `trip:OrderRouteAPI` | `GP-TRIP-ORDER-BASE-SINGLE`：`error_code=0`、点位非空、经纬度/link 合法；`GP-TRIP-ORDER-BASE-BATCH`：批量条数与子响应合法；`GP-TRIP-ORDER-TIMEOUT`：超时参数下返回合法；`GP-TRIP-ORDER-OPEN-CITY`：开城条件下非空；`GP-TRIP-ORDER-RERANK-SOURCE`：`data_source=didi_dropoff`；`GP-TRIP-ORDER-CROSSROAD-NONE`：`cross_lane_num=0`、`cross_road_level=no`；`GP-TRIP-ORDER-CROSSROAD-HIGH`：高等级跨路；`GP-TRIP-ORDER-CROSSROAD-LOW`：低等级跨路；`GP-TRIP-ORDER-CROSSROAD-EMPTY`：`extend_map=None`；`GP-TRIP-ORDER-AOI-SHOW`：围栏展示；`GP-TRIP-ORDER-AOI-HIDE`：`recommend_info={}` | 已验证；CV-001、002、017、020、029、048、051、061、064、079、101、113、155、178、180、189。`CROSSROAD-LOW` 当前断言被注释，仅作待补强候选；`CROSSROAD-EMPTY` 为 skip 的异常样本，不进入常规自动重跑。详见 [订单下车 11 个子场景](guide-point-flow-pilot-trip-order-route-scenarios.md)。 |
| `trip:wanliu_order_created` | `GP-TRIP-WANLIU-CREATED-BASE`：成功码 + 点位列表非空 | 已验证；CV-058 |
| `trip:wanliu_passenger_estimate_req` | `GP-TRIP-WANLIU-ESTIMATE-BASE`：成功码 + 点位列表非空；`GP-TRIP-WANLIU-ESTIMATE-SOURCE`：返回来源/类型符合预期 | 已验证；CV-056、160 |
| `trip:route-broker` | `GP-TRIP-RB-BASE`：成功码/非空；`GP-TRIP-RB-POINT-LINK-SOURCE`：坐标、link、`data_source/category_code`；`GP-TRIP-RB-RGEO`：反地理结果；`GP-TRIP-RB-BATCH`：批量关系 | 已验证；CV-046、065、100、115、144、146、159、169；CV-078 无断言不纳入重跑 |
| `trip:carpool_route_matcher` | 无有效 response 验证场景 | 待补 case |
| `trip:map_api` | `GP-TRIP-MAPAPI-BASE`：成功/非空；`GP-TRIP-MAPAPI-POINT-LEGAL`：坐标/POI 合法；`GP-TRIP-MAPAPI-AOI`：AOI/围栏结果；`GP-TRIP-MAPAPI-DBCK`：二次确认底卡；`GP-TRIP-MAPAPI-INTERCEPT`：专项拦截结果 | 已验证；CV-006、016、050、148、150、153、172；CV-028 无断言 |
| `trip:dolphin_api` | `GP-TRIP-DOLPHIN-AOI-SHOW`：AOI 展示；`GP-TRIP-DOLPHIN-AOI-HIDE`：AOI 不展示 | 已验证；CV-052；同一路由的正反预期应继续由 AST 按断言值拆开 |
| `trip:DavinciNaviAPI` | `GP-TRIP-DAVINCI-RECOMMEND`：成功码、点位非空、`recommend_info` 专项结果 | 已验证；CV-125 |
| `trip:NaviAPI_self_navi` | 无有效 response 验证场景 | 待补 case |
| `trip:BicyclingNaviAPI` | `GP-TRIP-BICYCLE-NAVI-BASE`：成功码 + 点位非空 | 已验证；CV-123 |
| `trip:beatles_point2point` | 无有效 response 验证场景 | 待补 case |
| `trip:map_manta_anycar_subway_combine` | `GP-TRIP-ANYCAR-SUBWAY-BASE`：成功码 + 点位列表非空 | 已验证；CV-054 |
| `trip:map_manta_bicycle_subway_combine` | `GP-TRIP-BICYCLE-SUBWAY-GEO`：Geo 接口成功/非空；`GP-TRIP-BICYCLE-SUBWAY-GUIDE`：Guide 接口非空 | 已验证；CV-055、116 |
| `trip:*` | `GP-TRIP-DEFAULT-BASE`：成功/非空；`GP-TRIP-DEFAULT-POINT-LEGAL`：坐标/POI 合法；`GP-TRIP-DEFAULT-GEO`：Geo 返回非空；`GP-TRIP-DEFAULT-ENDINFO-AOI`：AOI/二次确认结果 | 已验证；CV-007、015、033、128；CV-025 无断言 |
| `pickup:OrderRouteAPI` | `GP-PICKUP-ORDER-BASE`：`error_msg=OK` 或成功码；`GP-PICKUP-ORDER-NONEMPTY`：点位非空；`GP-PICKUP-ORDER-POINT-LINK-SOURCE`：坐标/link/来源合法 | 已验证；CV-005、112、130、171；CV-135 无断言 |
| `pickup:route-broker` | `GP-PICKUP-RB-BASE`：成功/非空；`GP-PICKUP-RB-POINT-LINK-SOURCE`：坐标/link/来源；`GP-PICKUP-RB-RGEO`：反地理结果 | 已验证；CV-145、147、168、170 |
| `pickup:*` | `GP-PICKUP-DEFAULT-ESTIMATE`：成功码、错误信息、点位/link 合法 | 已验证；CV-071 |
| `odpoint:wanliu_passenger_estimate_req` | `GP-ODPOINT-WANLIU-ESTIMATE-BASE`：成功码 + 点位列表非空 | 已验证；CV-057 |
| `odpoint:route-broker` | `GP-ODPOINT-RB-SOURCE`：成功码、非空、返回来源/类型 | 已验证；CV-132 |
| `odpoint:wanliu_order_created` | 无有效 response 验证场景 | 仅执行；CV-059 |
| `odpoint:OrderRouteAPI` | `GP-ODPOINT-ORDER-SOURCE`：成功码、非空、返回来源/类型 | 已验证；CV-129；CV-060 无断言 |
| `odpoint:*` | 无有效 response 验证场景 | 待补 case |
| `carpool:route-broker` | 无有效 response 验证场景 | 仅执行；CV-018 |
| `carpool:carpool_route_matcher` | `GP-CARPOOL-MATCHER-BASE`：成功码 + 点位非空；`GP-CARPOOL-MATCHER-CATEGORY`：`category_code` 等来源/类型结果 | 已验证；CV-124、138 |
| `carpool:*` | 无有效 response 验证场景 | 待补 case |

## 3. 拖拽 / 坐标选点（4 条）

| 路由 | 拆分后的验证场景 | 证据 / 结论 |
|---|---|---|
| `valet_driver:*` | `GP-VALET-DRIVER-RGEO-EXIST`：反地理 POI 存在；`GP-VALET-DRIVER-RGEO-EMPTY`：反地理结果为空时的兼容返回 | 已验证；CV-117 |
| `hac_drag:*` | `GP-HAC-DRAG-BASE-SOURCE-TAG`：点位非空、来源/展示标签；`GP-HAC-DRAG-CASTLE`：围栏/二次确认 | 已验证；CV-045、136 |
| `drag:*` | `GP-DRAG-BASE-SINGLE`；`GP-DRAG-BASE-BATCH`；`GP-DRAG-POINT-LINK-LEGAL`；`GP-DRAG-CASTLE-RGEO`；`GP-DRAG-PARK-INFO`；`GP-DRAG-LANGUAGE-MSG`；`GP-DRAG-ISLAND-BOTTOM-CARD` | 已验证；CV-010、011、041、047、097、104、105、108、109、166、167、175 |
| `specify_coordinate:*` | `GP-SPECIFY-COORDINATE-SINGLE`；`GP-SPECIFY-COORDINATE-BATCH`：均验证坐标/link、来源、围栏、展示、反地理结果 | 已验证；CV-140、141 |

## 4. 地图 POI / 通用召回（17 条）

| 路由 | 拆分后的验证场景 | 证据 / 结论 |
|---|---|---|
| `castle:*` | `GP-CASTLE-SINGLE`；`GP-CASTLE-BATCH`；`GP-CASTLE-LIST-TAG`；`GP-CASTLE-SOURCE`；`GP-CASTLE-CONFLICT-DBCK`；`GP-CASTLE-NEARBY-BIND` | 已验证；CV-012、013、037、049、068、121、151、156、182 |
| `park:*` | `GP-PARK-SINGLE-SOURCE`；`GP-PARK-BATCH`；`GP-PARK-CHILD-POI` | 已验证；CV-014、042、110、111 |
| `broad:*` | `GP-BROAD-LIST-TAG`；`GP-BROAD-NAME` | 已验证；CV-036、074 |
| `station:*` | 无有效 response 验证场景 | 待补 case |
| `multiple:*` | `GP-MULTIPLE-SINGLE`；`GP-MULTIPLE-BATCH`；`GP-MULTIPLE-LIST-TAG-NO-REC`；`GP-MULTIPLE-BUS-CATEGORY-SOURCE` | 已验证；CV-021、022、024、038、075、077、103；CV-023 无断言 |
| `mis:*` | `GP-MIS-SECOND-CONFIRM`；`GP-MIS-SOURCE`；`GP-MIS-LIST-TAG` | 已验证；CV-027、034、035 |
| `pure_mis:*` | 无有效 response 验证场景 | 待补 case |
| `unreach:*` | `GP-UNREACH-SOURCE-LIST-TAG` | 已验证；CV-043 |
| `island:*` | `GP-ISLAND-SINGLE-POINT-LEGAL`；`GP-ISLAND-BATCH-POINT-LEGAL`；`GP-ISLAND-ENDINFO-MSG`；`GP-ISLAND-SECOND-CONFIRM` | 已验证；CV-003、004、066、174 |
| `far_away:*` | `GP-FARAWAY-SECOND-CONFIRM`：来源、展示、围栏/停车结果 | 已验证；CV-177 |
| `acc_far_away:*` | `GP-ACC-FARAWAY-SOURCE-LIST-TAG` | 已验证；CV-165 |
| `cpo:*` | `GP-CPO-SINGLE-RGEO`；`GP-CPO-BATCH-RGEO` | 已验证；CV-106、107 |
| `spatial:*` | 无有效 response 验证场景 | 待补 case |
| `endinfo:*` | `GP-ENDINFO-DBCK-RGEO` | 已验证；CV-127 |
| `second_page:*` | 无有效 response 验证场景 | 待补 case |
| `default:*` | `GP-DEFAULT-LIST-TAG`；`GP-DEFAULT-SECOND-CONFIRM` | 已验证；CV-040 |
| `search_default:*` | `GP-SEARCH-DEFAULT-POINT-RGEO-LIST-TAG` | 已验证；CV-039 |

## 5. 二次确认专项（4 条）

| 路由 | 拆分后的验证场景 | 证据 / 结论 |
|---|---|---|
| `scenic_area:*` | `GP-SCENIC-AREA-SUBPOI`：子 POI、距离/路线；`GP-SCENIC-AREA-DBCK-MSG`：二次确认展示 | 已验证；CV-184 |
| `bus:*` | `GP-BUS-TRIGGER-PUSH-YIWU`；`GP-BUS-TRIGGER-PUSH-XIERQI`：来源、距离、底卡/展示信息不同，必须拆开 | 已验证；CV-186、188 |
| `risk:*` | 无有效 response 验证场景 | 待补 case |
| `broad_area:*` | 无有效 response 验证场景 | 待补 case |

## 6. 订单状态 / 缓存分流（13 条）

| 路由 | 拆分后的验证场景 | 证据 / 结论 |
|---|---|---|
| `trip_top1_park:wanliu_passenger_estimate_req` | `GP-TOP1PARK-ESTIMATE-BATCH`；`GP-TOP1PARK-ESTIMATE-OPEN-CITY`；`GP-TOP1PARK-ESTIMATE-SOURCE`；`GP-TOP1PARK-ESTIMATE-POINT-LEGAL` | 已验证；CV-032、063、114、133 |
| `trip_top1_park:wanliu_order_created` | `GP-TOP1PARK-CREATED-BATCH`；`GP-TOP1PARK-CREATED-ISLAND-RERANK`；`GP-TOP1PARK-CREATED-SOURCE-DBCK` | 已验证；CV-030、076、134 |
| `trip_top1_park:*` | 无有效 response 验证场景 | 待补 case |
| `estimate_real_time:*` | 无有效 response 验证场景 | 待补 case |
| `passenger_estimate_trip_req:*` | 无有效 response 验证场景 | 待补 case |
| `estimate_trip:*` | `GP-ESTIMATE-TRIP-SOURCE`；`GP-ESTIMATE-TRIP-LIST-TAG`；`GP-ESTIMATE-TRIP-POINT-LEGAL` | 已验证；CV-044、090、120 |
| `navi_park:*` | 无有效 response 验证场景 | 仅执行；CV-093、094、095、096 |
| `dropoff_cell_link:*` | 无有效 response 验证场景 | 待补 case |
| `dropoff_link_lng_lat:*` | 无有效 response 验证场景 | 待补 case |
| `passenger_estimate_pickup_req:*` | `GP-ESTIMATE-PICKUP-SENDHISTORY-CACHE`：成功、非空、坐标/link/来源 | 已验证；CV-143 |
| `model_predict_cache:*` | `GP-MODEL-PREDICT-CACHE-BETTER-POINT`：成功、非空、`data_source` | 已验证；CV-190 |
| `dbck_trip:*` | 无有效 response 验证场景 | 待补 case |
| `quad_express:*` | 无有效 response 验证场景 | 仅执行；CV-179 |

## 7. 海豚 / 导航（7 条）

| 路由 | 拆分后的验证场景 | 证据 / 结论 |
|---|---|---|
| `valet_driving:*` | `GP-VALET-DRIVING-SOURCE`：成功、非空、返回来源/类型 | 已验证；CV-131 |
| `dolphin_poi_detail:*` | `GP-DOLPHIN-POI-DETAIL-SOURCE`：成功、非空、返回来源/类型 | 已验证；CV-122 |
| `dolphin_point_rec:dolphin_api` | `GP-DOLPHIN-POINT-API-PROTOCOL`：`error_msg`；其余 case 无有效 response 断言 | CV-098 已验证；CV-019 仅执行 |
| `dolphin_point_rec:textsearch` | `GP-DOLPHIN-TEXTSEARCH-BASE`：点位列表非空 | 已验证；CV-053 |
| `dolphin_point_rec:*` | `GP-DOLPHIN-DEFAULT-RECOMMEND`：成功、非空、专项推荐结果 | 已验证；CV-126 |
| `jw_trip:*` | `GP-JW-TRIP-ONE-POINT`：点位数量/指定 POI；固定境外 POI 样本 | 已验证；CV-154；属于 `fixture_only` |
| `auto_drive_voyager:*` | `GP-VOYAGER-BATCH-BASE`：批量响应非空 | 已验证；CV-118 |

## 8. 智能小巴 / 线网（6 条）

| 路由 | 拆分后的验证场景 | 证据 / 结论 |
|---|---|---|
| `minbus_bubble_station:*` | `GP-MINBUS-BUBBLE-SOURCE`；`GP-MINBUS-BUBBLE-HOT-ROUTE-DIST`；`GP-MINBUS-BUBBLE-RERANK`；`GP-MINBUS-BUBBLE-LINK-REPAIR`；`GP-MINBUS-BUBBLE-CASTLE-LINK` | 已验证；CV-119、137、139、142、157、158 |
| `minbus_bubble_station_expend:*` | `GP-MINBUS-EXPAND-LARGE-RADIUS`；`GP-MINBUS-EXPAND-ZERO-RESULT`；`GP-MINBUS-EXPAND-VALID-DIRECTION`；`GP-MINBUS-EXPAND-CASTLE-MIS` | 已验证；CV-161、162、163、164 |
| `intelligent_minbus_station:*` | `GP-SMART-MINBUS-STATION`；`GP-SMART-MINBUS-CASTLE`；`GP-SMART-MINBUS-LOC`；`GP-SMART-MINBUS-LOC-DEGRADE`；`GP-SMART-MINBUS-NO-STATION`；`GP-SMART-MINBUS-PERSON-LINK` | 已验证；CV-081、082、084、085、086、089 |
| `intelligent_minbus_express_station:*` | `GP-SMART-MINBUS-EXPRESS`；`GP-SMART-MINBUS-EXPRESS-ZERO`；`GP-SMART-MINBUS-EXPRESS-EXPAND` | 已验证；CV-087、088、091 |
| `scancode_minbus_station:*` | `GP-SMART-MINBUS-SCANCODE`：站点、坐标、来源、距离 | 已验证；CV-083 |
| `net_platform:*` | `GP-NET-PLATFORM-SOURCE`：点位非空及来源/类型 | 已验证；CV-152 |

## 9. 触发 / 离线 / 兼容（7 条）

| 路由 | 拆分后的验证场景 | 证据 / 结论 |
|---|---|---|
| `trigger:*` | `GP-TRIGGER-CASTLE`；`GP-TRIGGER-MIS`；`GP-TRIGGER-ISLAND`；`GP-TRIGGER-FARAWAY`；`GP-TRIGGER-SCENIC`；`GP-TRIGGER-BUS-YIWU`；`GP-TRIGGER-BUS-XIERQI`。它们的 `dbck_trigger_type`、来源、展示、距离/路线预期不同，必须分别存储。 | 已验证；CV-009、062、067、069、092、173、176、181、183、185、187 |
| `offline_cluster_rec:*` | `GP-OFFLINE-ANYCAR-RGEO`；`GP-OFFLINE-BICYCLE-RGEO` | 已验证；CV-072、073；CV-026 无断言 |
| `castle_old:*` | 无有效 response 验证场景 | 待补 case |
| `park_old:*` | 无有效 response 验证场景 | 待补 case |
| `broad_old:*` | 无有效 response 验证场景 | 待补 case |
| `station_old:*` | 无有效 response 验证场景 | 待补 case |
| `hint:*` | 无有效 response 验证场景 | 待补 case |

## 10. 用于失败重跑的准入规则

只有标记为“已验证”的场景，才进入失败 case 的自动取数和重跑链路：

```text
失败 case
→ 定位场景 ID
→ 以 req_type + caller_id + 场景前置条件筛选 HDFS 最新日志
→ 替换请求中的易过期点位数据
→ 保持 response 断言不变
→ 重跑并分类结果
```

`仅执行` 和 `待补 case` 路由先进入覆盖缺口清单，不允许因为“能取到同 req_type/caller_id 的日志”就自动替换重跑。
