# guide-point-flow 代码—Case 合并场景库（静态分析版）

> **阅读说明（2026-08-14 更新）**：本文件中的 `CV-xxx` 是按 response 字段集合抽取的**case 证据编号**，不再作为统一场景主键。同一路由下若 response 的操作符或期望值不同，可能落在同一 CV 中，仍必须拆分为不同场景。全量以“场景为主键”的目录见 [guide-point-flow-scene-primary-catalog.md](guide-point-flow-scene-primary-catalog.md)；本文件保留为 CV → 原始 case/assert 的追溯索引。

## 结论

原 `guide-point-flow-scene-map.md` **只符合 mentor 要求中的第一半**：它完整列出了 `parameter.conf` 中 84 条代码路由场景。它没有读取 case 的请求、response 断言，也没有输出“代码场景 → case 验证场景 → case ID”的映射，因此**单独使用不符合完整要求**。

本文件补上第二半：从 `cases/guide_point_new` 的 4 个 `test_*.py` 中静态抽取调用与 response 断言；按“接口 + 实际 req_type + 实际 caller_id + response 断言字段集合”聚类，并用服务代码同样的优先级回填到 84 条路由场景。

## 数据口径与边界

- 代码路由：`guide-point-flow-v2/conf/parameter.conf`，共 **84** 条（精确 `(req_type, caller_id)` → `req_type:*` → `*:*`）。全量配置见 [guide-point-flow-static-scene-catalog.md](guide-point-flow-static-scene-catalog.md)。
- Case：`ModulesCaseNew/cases/guide_point_new`，共 **270** 个 `test_*` 方法；抽到 **330** 次 RPC 调用、**190** 个 response 验证子场景；**243** 个 case 含 response 字段断言。
- Case ID 必须带 `文件::类::方法@行号`：两份测试文件存在同名方法，不能只用 `test_xxx` 去重。
- 这是“静态代码事实”第一版。一个 case 若连续发起多个请求，response 断言按 **case 级** 关联到其调用；日志/数据平台落地时应继续记录 `request_index`、`trace_id`，把断言精确绑定到某一次响应。

### 正确的合并键

```text
RouteSceneKey      = service + interface + req_type + caller_id（或 caller 默认）
ValidationSceneKey = RouteSceneKey + response_validation_profile
response_validation_profile = response 字段 + 断言关系/期望 + 关键请求条件
```

因此，`trip + OrderRouteAPI` 不是一个 case 场景，而是一条**路由场景**；它下面可以同时有“成功非空”“来源为 didi_dropoff”“缓存/rerank 后首点正确”等多个验证子场景。它们不能因 `req_type/caller_id` 相同而被去重掉。

### response 维度说明

| 维度 | 从 case response 断言中识别的字段示例 |
|---|---|
| 协议/业务码 | `error_code`、`error_msg` |
| 返回结构/数量 | `guide_point_list`、`dest_gp.gp_list`、`response_list`、`res_list` |
| 坐标/链路合法性 | `lng`、`lat`、`link_ids` |
| 来源/类型 | `data_source`、`choose_x_srctag`、`category_code`、`m_type`、`point_assort` |
| 二次确认/围栏停车 | `dbck_trigger_type`、`castle_info`、`park_info`、`dbck_bottom_card` |
| 展示文案/名称 | `recommend_msg`、`list_tag_msg`、`notice_msg`、`bottom_card_msg`、`name` |
| 距离/路线 | `walk_dist`、`walk_time`、`eta_dist`、`geo`、`hot_route_info` |
| 反地理/起点信息 | `rgeo_result`、`ori_gp`、`ori_lng`、`ori_lat` |

## A. 84 条代码路由与 case 覆盖（全量）

`case 数`按静态调用计数：同一个 case 如调用两个接口会出现在两个验证子场景中。`仅执行`表示 case 到达了该路由、但没有可解析的 response 字段断言，不能把它当作功能已验证。

| # | 代码路由场景 | 代码场景簇 | case 数 | response 验证子场景 | 覆盖结论 |
|---:|---|---|---:|---|---|
| 1 | `*` + `*` | 根兜底 | 0 | — | 未发现对应 case |
| 2 | `trip` + `OrderRouteAPI` | 订单/预估基础链 | 49 | CV-001, CV-002, CV-008, CV-017, CV-020, CV-029, CV-048, CV-051, CV-061, CV-064, CV-079, CV-101, CV-113, CV-155, CV-178, CV-180, CV-189 | 部分有业务断言；部分仅执行 |
| 3 | `trip` + `wanliu_order_created` | 订单/预估基础链 | 2 | CV-058 | 有 response 验证（见 CV） |
| 4 | `trip` + `wanliu_passenger_estimate_req` | 订单/预估基础链 | 3 | CV-056, CV-160 | 有 response 验证（见 CV） |
| 5 | `trip` + `route-broker` | 订单/预估基础链 | 12 | CV-046, CV-065, CV-078, CV-100, CV-115, CV-144, CV-146, CV-159, CV-169 | 部分有业务断言；部分仅执行 |
| 6 | `trip` + `carpool_route_matcher` | 订单/预估基础链 | 0 | — | 未发现对应 case |
| 7 | `trip` + `map_api` | 订单/预估基础链 | 13 | CV-006, CV-016, CV-028, CV-050, CV-148, CV-150, CV-153, CV-172 | 部分有业务断言；部分仅执行 |
| 8 | `trip` + `dolphin_api` | 订单/预估基础链 | 4 | CV-052 | 有 response 验证（见 CV） |
| 9 | `trip` + `DavinciNaviAPI` | 订单/预估基础链 | 1 | CV-125 | 有 response 验证（见 CV） |
| 10 | `trip` + `NaviAPI_self_navi` | 订单/预估基础链 | 0 | — | 未发现对应 case |
| 11 | `trip` + `BicyclingNaviAPI` | 订单/预估基础链 | 1 | CV-123 | 有 response 验证（见 CV） |
| 12 | `trip` + `beatles_point2point` | 订单/预估基础链 | 0 | — | 未发现对应 case |
| 13 | `trip` + `map_manta_anycar_subway_combine` | 订单/预估基础链 | 2 | CV-054 | 有 response 验证（见 CV） |
| 14 | `trip` + `map_manta_bicycle_subway_combine` | 订单/预估基础链 | 3 | CV-055, CV-116 | 有 response 验证（见 CV） |
| 15 | `trip` + `*` | 订单/预估基础链 | 9 | CV-007, CV-015, CV-025, CV-033, CV-128 | 部分有业务断言；部分仅执行 |
| 16 | `pickup` + `OrderRouteAPI` | 订单/预估基础链 | 7 | CV-005, CV-112, CV-130, CV-135, CV-171 | 部分有业务断言；部分仅执行 |
| 17 | `pickup` + `route-broker` | 订单/预估基础链 | 4 | CV-145, CV-147, CV-168, CV-170 | 有 response 验证（见 CV） |
| 18 | `pickup` + `*` | 订单/预估基础链 | 2 | CV-071 | 有 response 验证（见 CV） |
| 19 | `odpoint` + `wanliu_passenger_estimate_req` | 订单/预估基础链 | 2 | CV-057 | 有 response 验证（见 CV） |
| 20 | `odpoint` + `route-broker` | 订单/预估基础链 | 1 | CV-132 | 有 response 验证（见 CV） |
| 21 | `odpoint` + `wanliu_order_created` | 订单/预估基础链 | 2 | CV-059 | 仅执行，缺 response 断言 |
| 22 | `odpoint` + `OrderRouteAPI` | 订单/预估基础链 | 3 | CV-060, CV-129 | 部分有业务断言；部分仅执行 |
| 23 | `odpoint` + `*` | 订单/预估基础链 | 0 | — | 未发现对应 case |
| 24 | `carpool` + `route-broker` | 订单/预估基础链 | 2 | CV-018 | 仅执行，缺 response 断言 |
| 25 | `carpool` + `carpool_route_matcher` | 订单/预估基础链 | 2 | CV-124, CV-138 | 有 response 验证（见 CV） |
| 26 | `carpool` + `*` | 订单/预估基础链 | 0 | — | 未发现对应 case |
| 27 | `valet_driving` + `*` | 海豚/导航 | 4 | CV-131 | 有 response 验证（见 CV） |
| 28 | `valet_driver` + `*` | 拖拽/坐标选点 | 3 | CV-117 | 有 response 验证（见 CV） |
| 29 | `hac_drag` + `*` | 拖拽/坐标选点 | 3 | CV-045, CV-136 | 有 response 验证（见 CV） |
| 30 | `drag` + `*` | 拖拽/坐标选点 | 16 | CV-010, CV-011, CV-041, CV-047, CV-097, CV-104, CV-105, CV-108, CV-109, CV-166, CV-167, CV-175 | 有 response 验证（见 CV） |
| 31 | `specify_coordinate` + `*` | 拖拽/坐标选点 | 2 | CV-140, CV-141 | 有 response 验证（见 CV） |
| 32 | `castle` + `*` | 地图 POI/通用召回 | 15 | CV-012, CV-013, CV-037, CV-049, CV-068, CV-121, CV-151, CV-156, CV-182 | 有 response 验证（见 CV） |
| 33 | `park` + `*` | 地图 POI/通用召回 | 6 | CV-014, CV-042, CV-110, CV-111 | 有 response 验证（见 CV） |
| 34 | `broad` + `*` | 地图 POI/通用召回 | 4 | CV-036, CV-074 | 有 response 验证（见 CV） |
| 35 | `station` + `*` | 地图 POI/通用召回 | 0 | — | 未发现对应 case |
| 36 | `multiple` + `*` | 地图 POI/通用召回 | 15 | CV-021, CV-022, CV-023, CV-024, CV-038, CV-075, CV-077, CV-103 | 部分有业务断言；部分仅执行 |
| 37 | `mis` + `*` | 地图 POI/通用召回 | 6 | CV-027, CV-034, CV-035 | 有 response 验证（见 CV） |
| 38 | `pure_mis` + `*` | 地图 POI/通用召回 | 0 | — | 未发现对应 case |
| 39 | `unreach` + `*` | 地图 POI/通用召回 | 2 | CV-043 | 有 response 验证（见 CV） |
| 40 | `island` + `*` | 地图 POI/通用召回 | 7 | CV-003, CV-004, CV-066, CV-174 | 有 response 验证（见 CV） |
| 41 | `far_away` + `*` | 地图 POI/通用召回 | 1 | CV-177 | 有 response 验证（见 CV） |
| 42 | `acc_far_away` + `*` | 地图 POI/通用召回 | 1 | CV-165 | 有 response 验证（见 CV） |
| 43 | `scenic_area` + `*` | 二次确认专项 | 1 | CV-184 | 有 response 验证（见 CV） |
| 44 | `bus` + `*` | 二次确认专项 | 2 | CV-186, CV-188 | 有 response 验证（见 CV） |
| 45 | `risk` + `*` | 二次确认专项 | 0 | — | 未发现对应 case |
| 46 | `broad_area` + `*` | 二次确认专项 | 0 | — | 未发现对应 case |
| 47 | `cpo` + `*` | 地图 POI/通用召回 | 2 | CV-106, CV-107 | 有 response 验证（见 CV） |
| 48 | `spatial` + `*` | 地图 POI/通用召回 | 0 | — | 未发现对应 case |
| 49 | `endinfo` + `*` | 地图 POI/通用召回 | 1 | CV-127 | 有 response 验证（见 CV） |
| 50 | `second_page` + `*` | 地图 POI/通用召回 | 0 | — | 未发现对应 case |
| 51 | `default` + `*` | 地图 POI/通用召回 | 4 | CV-040 | 有 response 验证（见 CV） |
| 52 | `auto_drive_voyager` + `*` | 海豚/导航 | 1 | CV-118 | 有 response 验证（见 CV） |
| 53 | `search_default` + `*` | 地图 POI/通用召回 | 2 | CV-039 | 有 response 验证（见 CV） |
| 54 | `trip_top1_park` + `wanliu_passenger_estimate_req` | 订单状态/缓存分流 | 7 | CV-032, CV-063, CV-114, CV-133 | 有 response 验证（见 CV） |
| 55 | `trip_top1_park` + `wanliu_order_created` | 订单状态/缓存分流 | 5 | CV-030, CV-076, CV-134 | 有 response 验证（见 CV） |
| 56 | `trip_top1_park` + `*` | 订单状态/缓存分流 | 0 | — | 未发现对应 case |
| 57 | `estimate_real_time` + `*` | 订单状态/缓存分流 | 0 | — | 未发现对应 case |
| 58 | `passenger_estimate_trip_req` + `*` | 订单状态/缓存分流 | 0 | — | 未发现对应 case |
| 59 | `trigger` + `*` | 触发/离线/兼容 | 26 | CV-009, CV-062, CV-067, CV-069, CV-092, CV-173, CV-176, CV-181, CV-183, CV-185, CV-187 | 有 response 验证（见 CV） |
| 60 | `castle_old` + `*` | 触发/离线/兼容 | 0 | — | 未发现对应 case |
| 61 | `park_old` + `*` | 触发/离线/兼容 | 0 | — | 未发现对应 case |
| 62 | `broad_old` + `*` | 触发/离线/兼容 | 0 | — | 未发现对应 case |
| 63 | `station_old` + `*` | 触发/离线/兼容 | 0 | — | 未发现对应 case |
| 64 | `hint` + `*` | 触发/离线/兼容 | 0 | — | 未发现对应 case |
| 65 | `offline_cluster_rec` + `*` | 触发/离线/兼容 | 6 | CV-026, CV-072, CV-073 | 部分有业务断言；部分仅执行 |
| 66 | `estimate_trip` + `*` | 订单状态/缓存分流 | 4 | CV-044, CV-090, CV-120 | 有 response 验证（见 CV） |
| 67 | `minbus_bubble_station` + `*` | 智能小巴/线网 | 9 | CV-119, CV-137, CV-139, CV-142, CV-157, CV-158 | 有 response 验证（见 CV） |
| 68 | `minbus_bubble_station_expend` + `*` | 智能小巴/线网 | 5 | CV-161, CV-162, CV-163, CV-164 | 有 response 验证（见 CV） |
| 69 | `navi_park` + `*` | 订单状态/缓存分流 | 4 | CV-093, CV-094, CV-095, CV-096 | 仅执行，缺 response 断言 |
| 70 | `dropoff_cell_link` + `*` | 订单状态/缓存分流 | 0 | — | 未发现对应 case |
| 71 | `dropoff_link_lng_lat` + `*` | 订单状态/缓存分流 | 0 | — | 未发现对应 case |
| 72 | `passenger_estimate_pickup_req` + `*` | 订单状态/缓存分流 | 1 | CV-143 | 有 response 验证（见 CV） |
| 73 | `dolphin_poi_detail` + `*` | 海豚/导航 | 1 | CV-122 | 有 response 验证（见 CV） |
| 74 | `dolphin_point_rec` + `dolphin_api` | 海豚/导航 | 8 | CV-019, CV-098 | 部分有业务断言；部分仅执行 |
| 75 | `dolphin_point_rec` + `textsearch` | 海豚/导航 | 2 | CV-053 | 有 response 验证（见 CV） |
| 76 | `dolphin_point_rec` + `*` | 海豚/导航 | 1 | CV-126 | 有 response 验证（见 CV） |
| 77 | `intelligent_minbus_station` + `*` | 智能小巴/线网 | 9 | CV-081, CV-082, CV-084, CV-085, CV-086, CV-089 | 有 response 验证（见 CV） |
| 78 | `intelligent_minbus_express_station` + `*` | 智能小巴/线网 | 7 | CV-087, CV-088, CV-091 | 有 response 验证（见 CV） |
| 79 | `scancode_minbus_station` + `*` | 智能小巴/线网 | 1 | CV-083 | 有 response 验证（见 CV） |
| 80 | `net_platform` + `*` | 智能小巴/线网 | 1 | CV-152 | 有 response 验证（见 CV） |
| 81 | `jw_trip` + `*` | 海豚/导航 | 1 | CV-154 | 有 response 验证（见 CV） |
| 82 | `model_predict_cache` + `*` | 订单状态/缓存分流 | 1 | CV-190 | 有 response 验证（见 CV） |
| 83 | `dbck_trip` + `*` | 订单状态/缓存分流 | 0 | — | 未发现对应 case |
| 84 | `quad_express` + `*` | 订单状态/缓存分流 | 1 | CV-179 | 仅执行，缺 response 断言 |

## B. Case response 验证子场景（全量聚类）

同一行表示：在相同接口、相同请求路由下，case 对 **同一组 response 字段**做断言。它是可用于筛 case 的最小目录项；case 名称/行号保留，避免“只看 req_type 就误合并”。`示例断言`是源码中的原始 response 断言摘录。

| 验证 ID | 映射代码路由 | 接口 | 实际 `req_type` | 实际 `caller_id` | response 验证维度 | response 字段（完整集合） | 对应 case ID |
|---|---|---|---|---|---|---|---|
| CV-001 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.error_code, res.guide_point_list, res.guide_point_list.lat, res.guide_point_list.link_ids, res.guide_point_list.lng | test_ai_guide_flow.py::AIGuideFlowTestCase::test_get_guide_point_list@L101 |
| CV-002 | #2 `trip:OrderRouteAPI` | `BatchGetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.error_code, res.response_list, res.response_list.guide_point_list, res.response_list.guide_point_list.lat, res.response_list.guide_point_list.link_ids, res.response_list.guide_point_list.lng | test_ai_guide_flow.py::AIGuideFlowTestCase::test_batch_get_guide_point_list@L134 |
| CV-003 | #40 `island:*` | `GetGeoGP` | `island` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.lat, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.lng, res.error_code | test_ai_guide_flow.py::AIGuideFlowTestCase::test_get_geo_gp@L176 |
| CV-004 | #40 `island:*` | `BatchGetGeoGP` | `island` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.lng | test_ai_guide_flow.py::AIGuideFlowTestCase::test_batch_get_geo_gp@L207 |
| CV-005 | #16 `pickup:OrderRouteAPI` | `GetGuidePointList` | `pickup` | `OrderRouteAPI` | 协议/业务码 | res.error_msg | test_kflower_guide_point.py::RewriteTestCase::test_pickup@L311<br>test_guide_point.py::RewriteTestCase::test_pickup@L317 |
| CV-006 | #7 `trip:map_api` | `GetGuidePointList` | `trip` | `map_api` | 协议/业务码、返回结构/数量 | res.error_msg, res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm@L351<br>test_guide_point.py::RewriteTestCase::test_secondconfirm@L394 |
| CV-007 | #15 `trip:*` | `GetGuidePointList` | `trip` | `` | 协议/业务码、返回结构/数量 | res.error_msg, res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm@L351<br>test_guide_point.py::RewriteTestCase::test_secondconfirm@L394 |
| CV-008 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_filter@L401<br>test_kflower_guide_point.py::RewriteTestCase::test_zhaohui@L420<br>test_kflower_guide_point.py::RewriteTestCase::test_ORA_result@L728<br>test_kflower_guide_point.py::RewriteTestCase::test_castle_target@L1521<br>test_guide_point.py::RewriteTestCase::test_newengine@L357<br>test_guide_point.py::RewriteTestCase::test_filter@L444<br>test_guide_point.py::RewriteTestCase::test_zhaohui@L463<br>test_guide_point.py::RewriteTestCase::test_ORA_result@L1202<br>test_guide_point.py::RewriteTestCase::test_castle_target@L2742<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_quad_express@L8206 |
| CV-009 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `map_api` | 协议/业务码、返回结构/数量、二次确认/围栏停车 | res.error_code, res.res_list, res.res_list.dbck_trigger_type | test_kflower_guide_point.py::RewriteTestCase::test_trigger_castle@L438<br>test_kflower_guide_point.py::RewriteTestCase::test_trigger_multiple@L987<br>test_kflower_guide_point.py::RewriteTestCase::test_trigger_multiple_door@L2939<br>test_kflower_guide_point.py::RewriteTestCase::test_trigger_multiple_bus@L2968<br>test_kflower_guide_point.py::RewriteTestCase::test_trigger_broad_new@L2999<br>test_guide_point.py::RewriteTestCase::test_trigger_castle@L481<br>test_guide_point.py::RewriteTestCase::test_trigger_multiple@L1843<br>test_guide_point.py::RewriteTestCase::test_trigger_multiple_door@L5756<br>test_guide_point.py::RewriteTestCase::test_trigger_multiple_bus@L5785<br>test_guide_point.py::RewriteTestCase::test_trigger_broad_new@L5816<br>test_guide_point.py::RewriteTestCase::test_trigger_vehicle_trigger@L8847 |
| CV-010 | #30 `drag:*` | `BatchGetGeoGP` | `drag` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.id.endswith, res.res_list.dest_gp.gp_list.id.split, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.ori_gp | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_drag@L533<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_drag@L906 |
| CV-011 | #30 `drag:*` | `GetGeoGP` | `drag` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.id.endswith, res.res_list.dest_gp.gp_list.id.split, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.ori_gp | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_drag@L533<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_drag@L906 |
| CV-012 | #32 `castle:*` | `GetGeoGP` | `castle` | `map_api` | 协议/业务码、返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.ori_gp | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_castle@L605<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_castle@L1070 |
| CV-013 | #32 `castle:*` | `BatchGetGeoGP` | `castle` | `map_api` | 协议/业务码、返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.ori_gp | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_castle@L605<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_castle@L1070 |
| CV-014 | #33 `park:*` | `BatchGetGeoGP` | `park` | `map_api` | 协议/业务码、返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.ori_gp | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_castle@L605<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_castle@L1070 |
| CV-015 | #15 `trip:*` | `GetGuidePointList` | `trip` | `None` | 返回结构/数量、坐标/链路合法性 | res.guide_point_list, res.guide_point_list.lat, res.guide_point_list.lng, res.guide_point_list.poi_name, res.guide_point_list.uid | test_kflower_guide_point.py::RewriteTestCase::test_tiananmen@L662<br>test_guide_point.py::RewriteTestCase::test_tiananmen@L1127 |
| CV-016 | #7 `trip:map_api` | `GetGuidePointList` | `trip` | `map_api` | 返回结构/数量、坐标/链路合法性 | res.guide_point_list, res.guide_point_list.lat, res.guide_point_list.lng, res.guide_point_list.poi_name, res.guide_point_list.uid | test_kflower_guide_point.py::RewriteTestCase::test_tiananmen@L662<br>test_guide_point.py::RewriteTestCase::test_tiananmen@L1127 |
| CV-017 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 返回结构/数量、坐标/链路合法性 | res.guide_point_list, res.guide_point_list.lat, res.guide_point_list.lng, res.guide_point_list.poi_name, res.guide_point_list.uid | test_kflower_guide_point.py::RewriteTestCase::test_tiananmen@L662<br>test_guide_point.py::RewriteTestCase::test_tiananmen@L1127 |
| CV-018 | #24 `carpool:route-broker` | `BatchGetGuidePointList` | `carpool` | `route-broker` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_ORA_result@L728<br>test_guide_point.py::RewriteTestCase::test_ORA_result@L1202 |
| CV-019 | #74 `dolphin_point_rec:dolphin_api` | `GetGuidePointList` | `dolphin_point_rec` | `dolphin_api` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_no_extend_no_park@L789<br>test_kflower_guide_point.py::RewriteTestCase::test_has_father_no_park@L820<br>test_guide_point.py::RewriteTestCase::test_extend_has_father_has_park@L1361<br>test_guide_point.py::RewriteTestCase::test_no_extend_no_park@L1418<br>test_guide_point.py::RewriteTestCase::test_has_father_no_park@L1449<br>test_guide_point.py::RewriteTestCase::test_fence_list@L1584<br>test_guide_point.py::RewriteTestCase::test_dolphin_gp_park@L2650 |
| CV-020 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码 | res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_trip_localsBackup@L957<br>test_kflower_guide_point.py::RewriteTestCase::test_island_rank@L1834<br>test_kflower_guide_point.py::RewriteTestCase::test_routebroker_trip_hit_castle@L3526<br>test_guide_point.py::RewriteTestCase::test_trip_localsBackup@L1813<br>test_guide_point.py::RewriteTestCase::test_island_rank@L3366<br>test_guide_point.py::RewriteTestCase::test_routebroker_trip_hit_castle@L6654<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_crossload_low@L6954 |
| CV-021 | #36 `multiple:*` | `GetGeoGP` | `multiple` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.name, res.dest_gp.gp_list.short_name, res.dest_gp.gp_list.type, res.dest_gp.park_info, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.short_name, res.res_list.dest_gp.gp_list.type, res.res_list.dest_gp.park_info, res.res_list.ori_gp | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_multiple@L1019<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_multiple@L1877 |
| CV-022 | #36 `multiple:*` | `BatchGetGeoGP` | `multiple` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.name, res.dest_gp.gp_list.short_name, res.dest_gp.gp_list.type, res.dest_gp.park_info, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.short_name, res.res_list.dest_gp.gp_list.type, res.res_list.dest_gp.park_info, res.res_list.ori_gp | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_multiple@L1019<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_multiple@L1877 |
| CV-023 | #36 `multiple:*` | `GetGeoGP` | `multiple` | `map_api` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_multiple_has_label_has_rec@L1082<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_multiple_has_label_has_rec@L1986 |
| CV-024 | #36 `multiple:*` | `GetGeoGP` | `multiple` | `map_api` | 返回结构/数量、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_multiple_has_label_no_rec@L1118<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_multiple_has_label_no_rec@L2022 |
| CV-025 | #15 `trip:*` | `GetGuidePointList` | `trip` | `anycar_subway_combine` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_bus_access@L1417<br>test_guide_point.py::RewriteTestCase::test_bus_access@L2548 |
| CV-026 | #65 `offline_cluster_rec:*` | `GetGuidePointList` | `offline_cluster_rec` | `anycar_subway_combine` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_bus_access@L1417<br>test_guide_point.py::RewriteTestCase::test_bus_access@L2548 |
| CV-027 | #37 `mis:*` | `GetGeoGP` | `mis` | `map_api` | 返回结构/数量、坐标/链路合法性、二次确认/围栏停车、展示文案/名称 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.lat, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.lng, res.dest_gp.gp_list.notice_msg, res.dest_gp.gp_list.poi_id, res.dest_gp.gp_list.poi_id.find, res.dest_gp.gp_list.recommend_msg | test_kflower_guide_point.py::RewriteTestCase::test_secondconfirm_webapp_mis@L1487<br>test_guide_point.py::RewriteTestCase::test_secondconfirm_webapp_mis@L2618 |
| CV-028 | #7 `trip:map_api` | `GetGuidePointList` | `trip` | `map_api` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_castle_target@L1521<br>test_guide_point.py::RewriteTestCase::test_castle_target@L2742 |
| CV-029 | #2 `trip:OrderRouteAPI` | `BatchGetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码 | res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_bindroad_hk@L1592<br>test_guide_point.py::RewriteTestCase::test_bindroad_hk@L2813 |
| CV-030 | #55 `trip_top1_park:wanliu_order_created` | `BatchGetGuidePointList` | `trip_top1_park` | `wanliu_order_created` | 协议/业务码 | res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_park_rerank@L1616<br>test_guide_point.py::RewriteTestCase::test_park_rerank@L2837 |
| CV-031 | 待解析/未配置 | `GetGuidePointList` | `?` | `?` | 返回结构/数量 | res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_enclosure_cover@L1666<br>test_guide_point.py::RewriteTestCase::test_enclosure_cover@L3198 |
| CV-032 | #54 `trip_top1_park:wanliu_passenger_estimate_req` | `BatchGetGuidePointList` | `trip_top1_park` | `wanliu_passenger_estimate_req` | 协议/业务码 | res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_island_rank@L1834<br>test_guide_point.py::RewriteTestCase::test_island_rank@L3366 |
| CV-033 | #15 `trip:*` | `GetGeoGP` | `trip` | `` | 返回结构/数量 | res.dest_gp, res.dest_gp.gp_list | test_kflower_guide_point.py::RewriteTestCase::test_mis_effecttime@L1864<br>test_guide_point.py::RewriteTestCase::test_mis_effecttime@L3542 |
| CV-034 | #37 `mis:*` | `GetGeoGP` | `mis` | `map_api` | 返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_mis_secondConfirm@L1890<br>test_guide_point.py::RewriteTestCase::test_mis_secondConfirm@L3583 |
| CV-035 | #37 `mis:*` | `GetGeoGP` | `mis` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_mis_secondConfirm_list_tag_msg@L1908<br>test_guide_point.py::RewriteTestCase::test_mis_secondConfirm_list_tag_msg@L3601 |
| CV-036 | #34 `broad:*` | `GetGeoGP` | `broad` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_broad_secondConfirm_list_tag_msg@L1926<br>test_guide_point.py::RewriteTestCase::test_broad_secondConfirm_list_tag_msg@L3619 |
| CV-037 | #32 `castle:*` | `GetGeoGP` | `castle` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_castle_secondConfirm_list_tag_msg@L1944<br>test_guide_point.py::RewriteTestCase::test_castle_secondConfirm_list_tag_msg@L3637 |
| CV-038 | #36 `multiple:*` | `GetGeoGP` | `multiple` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_multiple_secondConfirm_list_tag_msg@L1963<br>test_guide_point.py::RewriteTestCase::test_multiple_secondConfirm_list_tag_msg@L3656 |
| CV-039 | #53 `search_default:*` | `GetGeoGP` | `search_default` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.list_tag_msg, res.dest_gp.rgeo_result, res.dest_gp.rgeo_result.lat, res.dest_gp.rgeo_result.lng, res.dest_gp.rgeo_result.poi_id | test_kflower_guide_point.py::RewriteTestCase::test_search_default_secondConfirm_list_tag_msg@L1982<br>test_guide_point.py::RewriteTestCase::test_search_default_secondConfirm_list_tag_msg@L3675 |
| CV-040 | #51 `default:*` | `GetGeoGP` | `default` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_default_secondConfirm_list_tag_msg@L2003<br>test_kflower_guide_point.py::RewriteTestCase::test_default_secondConfirm_case@L3565<br>test_guide_point.py::RewriteTestCase::test_default_secondConfirm_list_tag_msg@L3696<br>test_guide_point.py::RewriteTestCase::test_default_secondConfirm_case@L6693 |
| CV-041 | #30 `drag:*` | `GetGeoGP` | `drag` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_drag_secondConfirm_list_tag_msg@L2022<br>test_guide_point.py::RewriteTestCase::test_drag_secondConfirm_list_tag_msg@L3715 |
| CV-042 | #33 `park:*` | `GetGeoGP` | `park` | `map_api` | 返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_park_secondConfirm_list_tag_msg@L2040<br>test_guide_point.py::RewriteTestCase::test_park_secondConfirm_list_tag_msg@L3733 |
| CV-043 | #39 `unreach:*` | `GetGeoGP` | `unreach` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_unreach_secondConfirm_list_tag_msg@L2060<br>test_guide_point.py::RewriteTestCase::test_unreach_secondConfirm_list_tag_msg@L3753 |
| CV-044 | #66 `estimate_trip:*` | `GetGeoGP` | `estimate_trip` | `map_api` | 返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_estimate_trip@L2100<br>test_guide_point.py::RewriteTestCase::test_estimate_trip@L3793 |
| CV-045 | #29 `hac_drag:*` | `GetGeoGP` | `hac_drag` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_hac_drag_secondConfirm_list_tag_msg@L2118<br>test_guide_point.py::RewriteTestCase::test_hac_drag_secondConfirm_list_tag_msg@L3811 |
| CV-046 | #5 `trip:route-broker` | `GetGuidePointList` | `trip` | `route-broker` | 返回结构/数量、来源/类型 | res.guide_point_list, res.guide_point_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_castle_old_fence_effective@L2137<br>test_guide_point.py::RewriteTestCase::test_castle_old_fence_effective@L3830 |
| CV-047 | #30 `drag:*` | `GetGeoGP` | `drag` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.list_tag_msg | test_kflower_guide_point.py::RewriteTestCase::test_castle_beijingxizhan_fence_effective@L2163<br>test_guide_point.py::RewriteTestCase::test_castle_beijingxizhan_fence_effective@L3856 |
| CV-048 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 返回结构/数量、来源/类型 | res.guide_point_list, res.guide_point_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_castle_tiananmen_fence_effective@L2205<br>test_kflower_guide_point.py::RewriteTestCase::test_castle_xiamen_fence_effective@L2265<br>test_kflower_guide_point.py::RewriteTestCase::test_castle_wuhan_fence_effective@L2289<br>test_guide_point.py::RewriteTestCase::test_castle_changzhou_fence_effective@L3897<br>test_guide_point.py::RewriteTestCase::test_castle_tiananmen_fence_effective@L3921<br>test_guide_point.py::RewriteTestCase::test_castle_fence_effective@L3982<br>test_guide_point.py::RewriteTestCase::test_castle_wuhan_fence_effective@L4007 |
| CV-049 | #32 `castle:*` | `GetGeoGP` | `castle` | `map_api` | 返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag | test_kflower_guide_point.py::RewriteTestCase::test_castle_secondConfirm_tiananmen@L2229<br>test_kflower_guide_point.py::RewriteTestCase::test_castle_secondConfirm_xiamen@L2247<br>test_guide_point.py::RewriteTestCase::test_castle_secondConfirm_tiananmen@L3945 |
| CV-050 | #7 `trip:map_api` | `GetGuidePointList` | `trip` | `map_api` | 协议/业务码、专项结果 | res.broadcast_able, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_map_api_trip@L2315<br>test_guide_point.py::RewriteTestCase::test_map_api_trip@L4049 |
| CV-051 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 返回结构/数量、专项结果 | res.guide_point_list, res.recommend_info | test_kflower_guide_point.py::RewriteTestCase::test_route_broker_aoi_effective@L2339<br>test_kflower_guide_point.py::RewriteTestCase::test_route_broker_aoi_status_effective@L2448<br>test_guide_point.py::RewriteTestCase::test_route_broker_aoi_effective@L4228<br>test_guide_point.py::RewriteTestCase::test_route_broker_aoi_status_effective@L4337 |
| CV-052 | #8 `trip:dolphin_api` | `GetGuidePointList` | `trip` | `dolphin_api` | 返回结构/数量、专项结果 | res.guide_point_list, res.recommend_info | test_kflower_guide_point.py::RewriteTestCase::test_dolphin_api_trip_aoi_effective@L2394<br>test_kflower_guide_point.py::RewriteTestCase::test_dolphin_api_trip_aoi_status_effective@L2503<br>test_guide_point.py::RewriteTestCase::test_dolphin_api_trip_aoi_effective@L4283<br>test_guide_point.py::RewriteTestCase::test_dolphin_api_trip_aoi_status_effective@L4390 |
| CV-053 | #75 `dolphin_point_rec:textsearch` | `GetGuidePointList` | `dolphin_point_rec` | `textsearch` | 返回结构/数量 | res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_textsearch_dolphin_point_rec@L2554<br>test_guide_point.py::RewriteTestCase::test_textsearch_dolphin_point_rec@L4441 |
| CV-054 | #13 `trip:map_manta_anycar_subway_combine` | `GetGeoGP` | `trip` | `map_manta_anycar_subway_combine` | 协议/业务码、返回结构/数量 | res.dest_gp, res.dest_gp.gp_list, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_map_manta_anycar_subway_combine_trip@L2576<br>test_guide_point.py::RewriteTestCase::test_map_manta_anycar_subway_combine_trip@L4463 |
| CV-055 | #14 `trip:map_manta_bicycle_subway_combine` | `GetGeoGP` | `trip` | `map_manta_bicycle_subway_combine` | 协议/业务码、返回结构/数量 | res.dest_gp, res.dest_gp.gp_list, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_map_manta_anycar_subway_combine_trip@L2576<br>test_guide_point.py::RewriteTestCase::test_map_manta_anycar_subway_combine_trip@L4463 |
| CV-056 | #4 `trip:wanliu_passenger_estimate_req` | `GetGuidePointList` | `trip` | `wanliu_passenger_estimate_req` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_wanliu_passenger_estimate_req_trip@L2604<br>test_guide_point.py::RewriteTestCase::test_wanliu_passenger_estimate_req_trip@L4608 |
| CV-057 | #19 `odpoint:wanliu_passenger_estimate_req` | `GetGuidePointList` | `odpoint` | `wanliu_passenger_estimate_req` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_wanliu_passenger_estimate_req_odpoint@L2626<br>test_guide_point.py::RewriteTestCase::test_wanliu_passenger_estimate_req_odpoint@L4630 |
| CV-058 | #3 `trip:wanliu_order_created` | `GetGuidePointList` | `trip` | `wanliu_order_created` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_wanliu_order_created_trip@L2648<br>test_guide_point.py::RewriteTestCase::test_wanliu_order_created_trip@L4681 |
| CV-059 | #21 `odpoint:wanliu_order_created` | `GetGuidePointList` | `odpoint` | `wanliu_order_created` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_wanliu_order_created_odpoint@L2671<br>test_guide_point.py::RewriteTestCase::test_wanliu_order_created_odpoint@L4704 |
| CV-060 | #22 `odpoint:OrderRouteAPI` | `GetGuidePointList` | `odpoint` | `OrderRouteAPI` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_wanliu_order_created_odpoint@L2671<br>test_guide_point.py::RewriteTestCase::test_wanliu_order_created_odpoint@L4704 |
| CV-061 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.error_code, res.guide_point_list, res.guide_point_list.link_ids | test_kflower_guide_point.py::RewriteTestCase::test_OrderRouteAPI_trip_req_timeout@L2710<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_trip_req_timeout@L4922 |
| CV-062 | #59 `trigger:*` | `GetGeoGP` | `trigger` | `mapapi` | 协议/业务码、二次确认/围栏停车 | res.dbck_trigger_type, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_mis_secondConfirm_trigger@L2735<br>test_guide_point.py::RewriteTestCase::test_mis_secondConfirm_trigger@L4947 |
| CV-063 | #54 `trip_top1_park:wanliu_passenger_estimate_req` | `GetGuidePointList` | `trip_top1_park` | `wanliu_passenger_estimate_req` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_route_broker_trip_wujiaqv@L2768<br>test_guide_point.py::RewriteTestCase::test_route_broker_trip_wujiaqv@L4980 |
| CV-064 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list | test_kflower_guide_point.py::RewriteTestCase::test_OrderRouteAPI_trip_wujiaqv@L2795<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_trip_wujiaqv@L5007 |
| CV-065 | #5 `trip:route-broker` | `GetGuidePointList` | `trip` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.category_code, res.guide_point_list.data_source, res.guide_point_list.link_ids | test_kflower_guide_point.py::RewriteTestCase::test_route_broker_trip_linkids@L2820<br>test_guide_point.py::RewriteTestCase::test_route_broker_trip_linkids@L5214 |
| CV-066 | #40 `island:*` | `BatchGetGeoGP` | `island` | `map_api` | 协议/业务码、返回结构/数量、展示文案/名称 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg | test_kflower_guide_point.py::RewriteTestCase::test_guide_point_island_endinfo@L2867<br>test_kflower_guide_point.py::RewriteTestCase::test_guide_point_island_endinfo_one@L2892<br>test_guide_point.py::RewriteTestCase::test_guide_point_island_endinfo@L5678<br>test_guide_point.py::RewriteTestCase::test_guide_point_island_endinfo_one@L5703 |
| CV-067 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `map_api` | 返回结构/数量、来源/类型、二次确认/围栏停车 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.choose_x_srctag, res.res_list.dest_gp.gp_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict@L3027 |
| CV-068 | #32 `castle:*` | `BatchGetGeoGP` | `castle` | `mapapi` | 返回结构/数量、来源/类型、二次确认/围栏停车 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.choose_x_srctag, res.res_list.dest_gp.gp_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict@L3027 |
| CV-069 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `map_api` | 返回结构/数量、来源/类型、二次确认/围栏停车 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict_recall@L3066<br>test_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict@L5843<br>test_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict_recall@L5884 |
| CV-070 | 待解析/未配置 | `BatchGetGeoGP` | `?` | `mapapi` | 返回结构/数量、来源/类型、二次确认/围栏停车 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source | test_kflower_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict_recall@L3066 |
| CV-071 | #18 `pickup:*` | `GetGuidePointList` | `pickup` | `wanliu_passenger_estimate_req` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.error_code, res.error_msg, res.guide_point_list, res.guide_point_list.link_ids | test_kflower_guide_point.py::RewriteTestCase::test_wanliu_passenger_estimate_req_pickup@L3108<br>test_guide_point.py::RewriteTestCase::test_wanliu_passenger_estimate_req_pickup@L5985 |
| CV-072 | #65 `offline_cluster_rec:*` | `GetGeoGP` | `offline_cluster_rec` | `map_manta_anycar_subway_combine` | 协议/业务码、返回结构/数量、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.rgeo_result, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_map_manta_anycar_subway_combine_offline_cluster_rec@L3185<br>test_guide_point.py::RewriteTestCase::test_map_manta_anycar_subway_combine_offline_cluster_rec@L6062 |
| CV-073 | #65 `offline_cluster_rec:*` | `GetGeoGP` | `offline_cluster_rec` | `map_manta_bicycle_subway_combine` | 协议/业务码、返回结构/数量、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.rgeo_result, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_map_manta_anycar_subway_combine_offline_cluster_rec@L3185<br>test_guide_point.py::RewriteTestCase::test_map_manta_anycar_subway_combine_offline_cluster_rec@L6062 |
| CV-074 | #34 `broad:*` | `GetGeoGP` | `broad` | `map_api` | 协议/业务码、返回结构/数量、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.name, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_trigger_broad_assert_name@L3212<br>test_guide_point.py::RewriteTestCase::test_trigger_broad_assert_name@L6089 |
| CV-075 | #36 `multiple:*` | `GetGeoGP` | `multiple` | `map_api` | 协议/业务码、返回结构/数量、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.name, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_trigger_broad_assert_name@L3212<br>test_guide_point.py::RewriteTestCase::test_trigger_broad_assert_name@L6089 |
| CV-076 | #55 `trip_top1_park:wanliu_order_created` | `GetGuidePointList` | `trip_top1_park` | `wanliu_order_created` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.error_code, res.guide_point_list, res.guide_point_list.lng | test_kflower_guide_point.py::RewriteTestCase::test_island_rerank@L3274<br>test_guide_point.py::RewriteTestCase::test_island_rerank@L6243 |
| CV-077 | #36 `multiple:*` | `GetGeoGP` | `multiple` | `map_api` | 协议/业务码、返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.category_code, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source, res.error_code | test_kflower_guide_point.py::RewriteTestCase::test_DBCK_multiple_bus@L3490<br>test_guide_point.py::RewriteTestCase::test_DBCK_multiple_bus@L6459 |
| CV-078 | #5 `trip:route-broker` | `GetGuidePointList` | `trip` | `route-broker` | 无 response 字段断言 | — | test_kflower_guide_point.py::RewriteTestCase::test_extend_map_route_broker@L3585<br>test_guide_point.py::RewriteTestCase::test_extend_map_route_broker@L6712 |
| CV-079 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 返回结构/数量、坐标/链路合法性、来源/类型 | res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.lat, res.guide_point_list.link_id, res.guide_point_list.link_ids, res.guide_point_list.lng, res.guide_point_list.uid | test_kflower_guide_point.py::RewriteTestCase::test_extend_map_OrderRouteAPI@L3624<br>test_guide_point.py::RewriteTestCase::test_extend_map_OrderRouteAPI@L6751 |
| CV-080 | 待解析/未配置 | `GetGuidePointList` | `?` | `?` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.error_code, res.guide_point_list, res.guide_point_list.link_ids | test_kflower_guide_point.py::RewriteTestCase::test_di_count_small@L3673<br>test_guide_point.py::RewriteTestCase::test_di_count_small@L7371 |
| CV-081 | #77 `intelligent_minbus_station:*` | `BatchGetGeoGP` | `intelligent_minbus_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.walk_dist | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_station@L44 |
| CV-082 | #77 `intelligent_minbus_station:*` | `BatchGetGeoGP` | `intelligent_minbus_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.name | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_station_castle@L102 |
| CV-083 | #79 `scancode_minbus_station:*` | `BatchGetGeoGP` | `scancode_minbus_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.walk_dist | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_station_scancode@L166 |
| CV-084 | #77 `intelligent_minbus_station:*` | `BatchGetGeoGP` | `intelligent_minbus_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.m_type, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.walk_dist, res.res_list.dest_gp.rec_type | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_station_loc@L235 |
| CV-085 | #77 `intelligent_minbus_station:*` | `BatchGetGeoGP` | `intelligent_minbus_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.m_type, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.walk_dist, res.res_list.dest_gp.rec_type | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_station_loc_degrade@L356<br>test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_station_distance@L437 |
| CV-086 | #77 `intelligent_minbus_station:*` | `BatchGetGeoGP` | `intelligent_minbus_station` | `map_api` | 返回结构/数量 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_station_nostation@L389<br>test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_station_no_res@L413<br>test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_castle_filter_zero@L679 |
| CV-087 | #78 `intelligent_minbus_express_station:*` | `BatchGetGeoGP` | `intelligent_minbus_express_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.walk_dist | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_express_station@L471 |
| CV-088 | #78 `intelligent_minbus_express_station:*` | `BatchGetGeoGP` | `intelligent_minbus_express_station` | `map_api` | 返回结构/数量 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_zero_express_station@L532<br>test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_abnormal_lng_lat_express_station@L555<br>test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_express_expand_zero_station@L808 |
| CV-089 | #77 `intelligent_minbus_station:*` | `BatchGetGeoGP` | `intelligent_minbus_station` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.name | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_valid_person_link@L594 |
| CV-090 | #66 `estimate_trip:*` | `BatchGetGeoGP` | `estimate_trip` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_valid_personal_mis_link@L640 |
| CV-091 | #78 `intelligent_minbus_express_station:*` | `BatchGetGeoGP` | `intelligent_minbus_express_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.m_type, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.walk_dist | test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_express_expand_station@L723<br>test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_express_expand_station_larger_walk@L765<br>test_intelligent_minibus.py::TestIntelligentMinibus::test_intelligent_minbus_express_not_expand_station@L832 |
| CV-092 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `mapapi` | 协议/业务码、返回结构/数量、二次确认/围栏停车 | res.error_code, res.res_list, res.res_list.dbck_trigger_type | test_guide_point.py::RewriteTestCase::test_trigger_black@L600<br>test_guide_point.py::RewriteTestCase::test_guide_point_island@L5656<br>test_guide_point.py::RewriteTestCase::test_trigger_singel_poi_mis@L8177 |
| CV-093 | #69 `navi_park:*` | `GetGeoGP` | `navi_park` | `order_api` | 无 response 字段断言 | — | test_guide_point.py::RewriteTestCase::test_homecompark@L638 |
| CV-094 | #69 `navi_park:*` | `BatchGetGeoGP` | `navi_park` | `order_api` | 无 response 字段断言 | — | test_guide_point.py::RewriteTestCase::test_homecompark@L638 |
| CV-095 | #69 `navi_park:*` | `GetGeoGP` | `navi_park` | `map_api` | 无 response 字段断言 | — | test_guide_point.py::RewriteTestCase::test_homecompark@L638 |
| CV-096 | #69 `navi_park:*` | `BatchGetGeoGP` | `navi_park` | `map_api` | 无 response 字段断言 | — | test_guide_point.py::RewriteTestCase::test_homecompark@L638 |
| CV-097 | #30 `drag:*` | `BatchGetGeoGP` | `drag` | `map_api` | 返回结构/数量、坐标/链路合法性、二次确认/围栏停车 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.park_info, res.res_list.dest_gp.park_info.gp, res.res_list.dest_gp.park_info.gp.lat, res.res_list.dest_gp.park_info.gp.lng, res.res_list.dest_gp.park_info.park_detail | test_guide_point.py::RewriteTestCase::test_secondconfirm_drag_park_rec@L977 |
| CV-098 | #74 `dolphin_point_rec:dolphin_api` | `GetGuidePointList` | `dolphin_point_rec` | `dolphin_api` | 协议/业务码 | res.error_msg | test_guide_point.py::RewriteTestCase::test_dolphin_station@L1261 |
| CV-099 | 待解析/未配置 | `GetGuidePointList` | `trip_top1_park` | `?` | 协议/业务码 | res.error_msg | test_guide_point.py::RewriteTestCase::test_dolphin_station@L1261 |
| CV-100 | #5 `trip:route-broker` | `BatchGetGuidePointList` | `trip` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.response_list.guide_point_list, res.response_list.guide_point_list.data_source, res.response_list.guide_point_list.lat, res.response_list.guide_point_list.lng, res.response_list.guide_point_list.uid | test_guide_point.py::RewriteTestCase::test_rb_ddmq_seondconfirm@L1726 |
| CV-101 | #2 `trip:OrderRouteAPI` | `BatchGetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.response_list, res.response_list.guide_point_list, res.response_list.guide_point_list.data_source, res.response_list.guide_point_list.lat, res.response_list.guide_point_list.lng, res.response_list.guide_point_list.uid | test_guide_point.py::RewriteTestCase::test_ora_ddmq_seondconfirm@L1754 |
| CV-102 | 待解析/未配置 | `BatchGetGuidePointList` | `?` | `?` | 协议/业务码 | response.error_code | test_guide_point.py::RewriteTestCase::test_crm@L1792 |
| CV-103 | #36 `multiple:*` | `GetGeoGP` | `multiple` | `map_api` | 协议/业务码、返回结构/数量、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.list_tag_msg, res.error_code, res.ori_gp | test_guide_point.py::RewriteTestCase::test_secondconfirm_multiple_no_label_no_rec@L1939 |
| CV-104 | #30 `drag:*` | `BatchGetGeoGP` | `drag` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.dest_gp.park_info, res.dest_gp.park_info.icon_min_level, res.dest_gp.park_info.icon_text, res.dest_gp.park_info.icon_url, res.dest_gp.park_info.line_type, res.dest_gp.park_info.park_detail, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.dest_gp.park_info, res.res_list.dest_gp.park_info.icon_min_level, res.res_list.dest_gp.park_info.icon_text, res.res_list.dest_gp.park_info.icon_url, res.res_list.dest_gp.park_info.line_type, res.res_list.dest_gp.park_info.park_detail, res.res_list.ori_gp | test_guide_point.py::RewriteTestCase::test_secondconfirm_drag_unreach@L2320 |
| CV-105 | #30 `drag:*` | `GetGeoGP` | `drag` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.dest_gp.park_info, res.dest_gp.park_info.icon_min_level, res.dest_gp.park_info.icon_text, res.dest_gp.park_info.icon_url, res.dest_gp.park_info.line_type, res.dest_gp.park_info.park_detail, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.dest_gp.park_info, res.res_list.dest_gp.park_info.icon_min_level, res.res_list.dest_gp.park_info.icon_text, res.res_list.dest_gp.park_info.icon_url, res.res_list.dest_gp.park_info.line_type, res.res_list.dest_gp.park_info.park_detail, res.res_list.ori_gp | test_guide_point.py::RewriteTestCase::test_secondconfirm_drag_unreach@L2320 |
| CV-106 | #47 `cpo:*` | `GetGeoGP` | `cpo` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.lat, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.lng, res.dest_gp.gp_list.name, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.name, res.res_list.ori_gp | test_guide_point.py::RewriteTestCase::test_secondconfirm_cpo@L2886 |
| CV-107 | #47 `cpo:*` | `BatchGetGeoGP` | `cpo` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.lat, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.lng, res.dest_gp.gp_list.name, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.name, res.res_list.ori_gp | test_guide_point.py::RewriteTestCase::test_secondconfirm_cpo@L2886 |
| CV-108 | #30 `drag:*` | `GetGeoGP` | `drag` | `map_api` | 协议/业务码、二次确认/围栏停车、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.rgeo_result, res.dest_gp.rgeo_result.id, res.dest_gp.rgeo_result.poi_id, res.error_code | test_guide_point.py::RewriteTestCase::test_mapapi_drag_castle@L2947 |
| CV-109 | #30 `drag:*` | `BatchGetGeoGP` | `drag` | `map_api` | 协议/业务码、二次确认/围栏停车、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.rgeo_result, res.dest_gp.rgeo_result.id, res.dest_gp.rgeo_result.poi_id, res.error_code | test_guide_point.py::RewriteTestCase::test_mapapi_drag_castle@L2947 |
| CV-110 | #33 `park:*` | `GetGeoGP` | `park` | `map_api` | 协议/业务码、坐标/链路合法性、来源/类型、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.rgeo_result, res.dest_gp.rgeo_result.child_poi_list, res.dest_gp.rgeo_result.child_poi_list.category_code, res.dest_gp.rgeo_result.child_poi_list.lat, res.dest_gp.rgeo_result.child_poi_list.lng, res.dest_gp.rgeo_result.child_poi_list.name, res.dest_gp.rgeo_result.child_poi_list.poi_id, res.dest_gp.rgeo_result.id, res.dest_gp.rgeo_result.poi_id, res.error_code | test_guide_point.py::RewriteTestCase::test_dbck_child_poi@L2990 |
| CV-111 | #33 `park:*` | `BatchGetGeoGP` | `park` | `map_api` | 协议/业务码、坐标/链路合法性、来源/类型、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.rgeo_result, res.dest_gp.rgeo_result.child_poi_list, res.dest_gp.rgeo_result.child_poi_list.category_code, res.dest_gp.rgeo_result.child_poi_list.lat, res.dest_gp.rgeo_result.child_poi_list.lng, res.dest_gp.rgeo_result.child_poi_list.name, res.dest_gp.rgeo_result.child_poi_list.poi_id, res.dest_gp.rgeo_result.id, res.dest_gp.rgeo_result.poi_id, res.error_code | test_guide_point.py::RewriteTestCase::test_dbck_child_poi@L2990 |
| CV-112 | #16 `pickup:OrderRouteAPI` | `GetGuidePointList` | `pickup` | `OrderRouteAPI` | 返回结构/数量 | res.guide_point_list | test_guide_point.py::RewriteTestCase::test_pickup_picture@L3033 |
| CV-113 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.lat, res.guide_point_list.lng | test_guide_point.py::RewriteTestCase::test_highspeek_inout@L3070 |
| CV-114 | #54 `trip_top1_park:wanliu_passenger_estimate_req` | `GetGuidePointList` | `trip_top1_park` | `wanliu_passenger_estimate_req` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.lat, res.guide_point_list.lng | test_guide_point.py::RewriteTestCase::test_highspeek_inout@L3070<br>test_guide_point.py::RewriteTestCase::test_highspeek_inout_cover@L3095 |
| CV-115 | #5 `trip:route-broker` | `GetGuidePointList` | `trip` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.lat, res.guide_point_list.lng | test_guide_point.py::RewriteTestCase::test_highspeek_inout_cover@L3095 |
| CV-116 | #14 `trip:map_manta_bicycle_subway_combine` | `GetGuidePointList` | `trip` | `map_manta_bicycle_subway_combine` | 返回结构/数量 | res.guide_point_list | test_guide_point.py::RewriteTestCase::test_bicycle_travel_bus@L3396 |
| CV-117 | #28 `valet_driver:*` | `GetGeoGP` | `valet_driver` | `` | 协议/业务码、返回结构/数量、反地理/起点信息 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.rgeo_result, res.dest_gp.rgeo_result.poi_id, res.error_code | test_guide_point.py::RewriteTestCase::test_valetdriving_poi@L3420<br>test_guide_point.py::RewriteTestCase::test_valetdriving_rego_poi@L3439<br>test_guide_point.py::RewriteTestCase::test_valetdriving_null_rego_poi@L3458 |
| CV-118 | #52 `auto_drive_voyager:*` | `BatchGetGeoGP` | `auto_drive_voyager` | `map_api` | 协议/业务码、返回结构/数量 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list | test_guide_point.py::RewriteTestCase::test_auto_drive_voyager@L3477 |
| CV-119 | #67 `minbus_bubble_station:*` | `GetGeoGP` | `minbus_bubble_station` | `map_api` | 返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source | test_guide_point.py::RewriteTestCase::test_minibus@L3566 |
| CV-120 | #66 `estimate_trip:*` | `BatchGetGeoGP` | `estimate_trip` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.list_tag_msg | test_guide_point.py::RewriteTestCase::test_estimate_trip_secondConfirm_list_tag_msg@L3772 |
| CV-121 | #32 `castle:*` | `GetGeoGP` | `castle` | `map_api` | 返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.choose_x_srctag, res.dest_gp.gp_list.data_source | test_guide_point.py::RewriteTestCase::test_castle_secondConfirm_1@L3963 |
| CV-122 | #73 `dolphin_poi_detail:*` | `GetGeoGP` | `dolphin_poi_detail` | `map_api` | 协议/业务码、返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source, res.error_code | test_guide_point.py::RewriteTestCase::test_map_api_dolphin_poi_detail@L4031 |
| CV-123 | #11 `trip:BicyclingNaviAPI` | `GetGuidePointList` | `trip` | `BicyclingNaviAPI` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list | test_guide_point.py::RewriteTestCase::test_BicyclingNaviAPI_trip@L4071 |
| CV-124 | #25 `carpool:carpool_route_matcher` | `GetGuidePointList` | `carpool` | `carpool_route_matcher` | 协议/业务码、返回结构/数量、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.category_code | test_guide_point.py::RewriteTestCase::test_carpool_route_matcher_carpool@L4093 |
| CV-125 | #9 `trip:DavinciNaviAPI` | `GetGuidePointList` | `trip` | `DavinciNaviAPI` | 协议/业务码、返回结构/数量、专项结果 | res.error_code, res.guide_point_list, res.recommend_info | test_guide_point.py::RewriteTestCase::test_DavinciNaviAPI_trip@L4116 |
| CV-126 | #76 `dolphin_point_rec:*` | `GetGuidePointList` | `dolphin_point_rec` | `dubhe_edit_search_svr` | 协议/业务码、返回结构/数量、专项结果 | res.error_code, res.guide_point_list, res.recommend_info | test_guide_point.py::RewriteTestCase::test_dubhe_edit_search_svr_dolphin_point_rec@L4139 |
| CV-127 | #49 `endinfo:*` | `GetGeoGP` | `endinfo` | `mapapi` | 协议/业务码、二次确认/围栏停车、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.rgeo_result, res.dest_gp.rgeo_result.poi_id, res.error_code | test_guide_point.py::RewriteTestCase::test_mapapi_endinfo@L4163 |
| CV-128 | #15 `trip:*` | `GetGeoGP` | `trip` | `mapapi` | 协议/业务码、返回结构/数量、二次确认/围栏停车、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.rgeo_result, res.dest_gp.rgeo_result.id, res.error_code | test_guide_point.py::RewriteTestCase::test_endinfo_aoi_effective@L4184 |
| CV-129 | #22 `odpoint:OrderRouteAPI` | `GetGuidePointList` | `odpoint` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.category_code | test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_odpoint@L4487 |
| CV-130 | #16 `pickup:OrderRouteAPI` | `GetGuidePointList` | `pickup` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性 | res.error_code, res.guide_point_list, res.guide_point_list.lat, res.guide_point_list.link_ids, res.guide_point_list.lng | test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_pickup@L4510 |
| CV-131 | #27 `valet_driving:*` | `GetGuidePointList` | `valet_driving` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source | test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_valet_driving@L4536<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_valet_driving_dolp@L6150<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_valet_driving_dolp_off_island@L6193<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_valet_driving_dolp_poi_bind@L6218 |
| CV-132 | #20 `odpoint:route-broker` | `GetGuidePointList` | `odpoint` | `route-broker` | 协议/业务码、返回结构/数量、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source | test_guide_point.py::RewriteTestCase::test_routeBroker_odpoint@L4561 |
| CV-133 | #54 `trip_top1_park:wanliu_passenger_estimate_req` | `GetGuidePointList` | `trip_top1_park` | `wanliu_passenger_estimate_req` | 协议/业务码、返回结构/数量、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.category_code | test_guide_point.py::RewriteTestCase::test_wanliu_passenger_estimate_req_trip_top1_park@L4585 |
| CV-134 | #55 `trip_top1_park:wanliu_order_created` | `GetGuidePointList` | `trip_top1_park` | `wanliu_order_created` | 协议/业务码、返回结构/数量、来源/类型、二次确认/围栏停车 | res.castle_info, res.error_code, res.guide_point_list, res.guide_point_list.category_code | test_guide_point.py::RewriteTestCase::test_wanliu_order_created_trip_top1_park@L4652 |
| CV-135 | #16 `pickup:OrderRouteAPI` | `GetGuidePointList` | `pickup` | `OrderRouteAPI` | 无 response 字段断言 | — | test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_pickup_picture@L4742<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_quad_express@L8206 |
| CV-136 | #29 `hac_drag:*` | `GetGeoGP` | `hac_drag` | `map_api` | 协议/业务码、返回结构/数量、来源/类型、二次确认/围栏停车 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source, res.error_code | test_guide_point.py::RewriteTestCase::test_hac_drag_secondConfirm_calste@L4790 |
| CV-137 | #67 `minbus_bubble_station:*` | `GetGeoGP` | `minbus_bubble_station` | `map_api` | 协议/业务码、返回结构/数量、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source, res.error_code | test_guide_point.py::RewriteTestCase::test_minibus_guide_point@L4897<br>test_guide_point.py::RewriteTestCase::test_minibus_fliter_castal_mis@L7406<br>test_guide_point.py::RewriteTestCase::test_minibus_minbus_degrade@L7900 |
| CV-138 | #25 `carpool:carpool_route_matcher` | `GetGuidePointList` | `carpool` | `carpool_route_matcher` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list | test_guide_point.py::RewriteTestCase::test_carpool_route_matcher_carpool_wujiaqv@L5032 |
| CV-139 | #67 `minbus_bubble_station:*` | `GetGeoGP` | `minbus_bubble_station` | `map_api` | 返回结构/数量、来源/类型、距离/路线 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.hot_route_info, res.dest_gp.gp_list.hot_route_info.route_id, res.dest_gp.gp_list.hot_route_info.station_offset, res.dest_gp.gp_list.hot_route_info.time_range, res.dest_gp.gp_list.m_type | test_guide_point.py::RewriteTestCase::test_minibus_hot_route_info_dist@L5058<br>test_guide_point.py::RewriteTestCase::test_minibus_hot_route_info_time@L5137 |
| CV-140 | #31 `specify_coordinate:*` | `BatchGetGeoGP` | `specify_coordinate` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.id.endswith, res.res_list.dest_gp.gp_list.id.split, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.ori_gp | test_guide_point.py::RewriteTestCase::test_secondconfirm_specify_coordinate@L5239 |
| CV-141 | #31 `specify_coordinate:*` | `GetGeoGP` | `specify_coordinate` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、反地理/起点信息 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.dest_gp.gp_list.is_recommend_absorb, res.dest_gp.gp_list.name, res.dest_gp.gp_list.type, res.error_code, res.ori_gp, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.castle_info, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.id.endswith, res.res_list.dest_gp.gp_list.id.split, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.type, res.res_list.ori_gp | test_guide_point.py::RewriteTestCase::test_secondconfirm_specify_coordinate@L5239 |
| CV-142 | #67 `minbus_bubble_station:*` | `GetGeoGP` | `minbus_bubble_station` | `map_api` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、展示文案/名称 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.name, res.error_code | test_guide_point.py::RewriteTestCase::test_minibus_guide_point_rerank@L5313 |
| CV-143 | #72 `passenger_estimate_pickup_req:*` | `BatchGetGeoGP` | `passenger_estimate_pickup_req` | `poi_sendhistory` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.link_ids | test_guide_point.py::RewriteTestCase::test_sendhistory_estimate_rb_cache@L5341 |
| CV-144 | #5 `trip:route-broker` | `GetGuidePointList` | `trip` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.link_ids | test_guide_point.py::RewriteTestCase::test_sendhistory_estimate_rb_cache@L5341 |
| CV-145 | #17 `pickup:route-broker` | `GetGuidePointList` | `pickup` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.link_ids | test_guide_point.py::RewriteTestCase::test_sendhistory_estimate_rb_cache@L5341 |
| CV-146 | #5 `trip:route-broker` | `GetGuidePointList` | `trip` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、反地理/起点信息 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.link_ids, res.ori_lat, res.ori_lng | test_guide_point.py::RewriteTestCase::test_route_broker_hit_cache_mq@L5442 |
| CV-147 | #17 `pickup:route-broker` | `GetGuidePointList` | `pickup` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、反地理/起点信息 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.link_ids, res.ori_lat, res.ori_lng | test_guide_point.py::RewriteTestCase::test_route_broker_hit_cache_mq@L5442 |
| CV-148 | #7 `trip:map_api` | `GetGeoGP` | `trip` | `map_api` | 协议/业务码、返回结构/数量、二次确认/围栏停车 | res.dest_gp, res.dest_gp.castle_info, res.dest_gp.gp_list, res.error_code | test_guide_point.py::RewriteTestCase::test_aoi_with_lnt_lat@L5506<br>test_guide_point.py::RewriteTestCase::test_aoi_with_parent_poiid@L5546 |
| CV-149 | 待解析/未配置 | `GetGuidePointList` | `?` | `?` | 协议/业务码、返回结构/数量 | res.error_code, res.error_msg, res.guide_point_list | test_guide_point.py::RewriteTestCase::test_di_check_lat_lng@L5588 |
| CV-150 | #7 `trip:map_api` | `BatchGetGeoGP` | `trip` | `map_api` | 协议/业务码、返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.park_info, res.res_list.dest_gp.park_info.icon_text, res.res_list.dest_gp.park_info.line_type | test_guide_point.py::RewriteTestCase::test_guide_point_endinfo_drag_island@L5726 |
| CV-151 | #32 `castle:*` | `BatchGetGeoGP` | `castle` | `mapapi` | 返回结构/数量、来源/类型、二次确认/围栏停车 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source | test_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict@L5843<br>test_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict_recall@L5884 |
| CV-152 | #80 `net_platform:*` | `BatchGetGeoGP` | `net_platform` | `map_api` | 返回结构/数量、来源/类型 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source | test_guide_point.py::RewriteTestCase::test_net_platform@L5923 |
| CV-153 | #7 `trip:map_api` | `GetGuidePointList` | `trip` | `map_api` | 协议/业务码、返回结构/数量、专项结果 | res.error_code, res.error_msg, res.guide_point_list, res.guide_point_list.is_wl | test_guide_point.py::RewriteTestCase::test_order_interception@L5944 |
| CV-154 | #81 `jw_trip:*` | `GetGeoGP` | `jw_trip` | `map_api` | 返回结构/数量 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.poi_id | test_guide_point.py::RewriteTestCase::test_jw_trip@L6803 |
| CV-155 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list, res.guide_point_list.extend_map | test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_no_crossload@L6842<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_crossload_high_06@L6878<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_crossload_high_01@L6913<br>test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_crossload_none@L6992 |
| CV-156 | #32 `castle:*` | `GetGeoGP` | `castle` | `map_api` | 返回结构/数量 | res.dest_gp, res.dest_gp.gp_list | test_guide_point.py::RewriteTestCase::test_multiple_nearby_bind_link@L7026 |
| CV-157 | #67 `minbus_bubble_station:*` | `GetGeoGP` | `minbus_bubble_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.lat, res.dest_gp.gp_list.link_ids, res.dest_gp.gp_list.lng | test_guide_point.py::RewriteTestCase::test_minibus_link@L7044 |
| CV-158 | #67 `minbus_bubble_station:*` | `GetGeoGP` | `minbus_bubble_station` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型 | res.dest_gp, res.dest_gp.gp_list, res.dest_gp.gp_list.data_source, res.dest_gp.gp_list.link_ids | test_guide_point.py::RewriteTestCase::test_minibus_link_castle@L7063 |
| CV-159 | #5 `trip:route-broker` | `GetGuidePointList` | `trip` | `route-broker` | 返回结构/数量、来源/类型 | res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.poi_name | test_guide_point.py::RewriteTestCase::test_guide_ko_KR_poi_mis_and_naming@L7081 |
| CV-160 | #4 `trip:wanliu_passenger_estimate_req` | `GetGuidePointList` | `trip` | `wanliu_passenger_estimate_req` | 返回结构/数量、来源/类型 | res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.poi_name | test_guide_point.py::RewriteTestCase::test_guide_ko_KR_poi_mis_and_naming@L7081 |
| CV-161 | #68 `minbus_bubble_station_expend:*` | `BatchGetGeoGP` | `minbus_bubble_station_expend` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.walk_dist | test_guide_point.py::RewriteTestCase::test_minbus_expand_larger_radius_station@L7138 |
| CV-162 | #68 `minbus_bubble_station_expend:*` | `BatchGetGeoGP` | `minbus_bubble_station_expend` | `map_api` | 返回结构/数量 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list | test_guide_point.py::RewriteTestCase::test_minbus_zero_expand_station@L7192<br>test_guide_point.py::RewriteTestCase::test_minbus_expand_abnormal_less_filter_dist_station@L7267 |
| CV-163 | #68 `minbus_bubble_station_expend:*` | `BatchGetGeoGP` | `minbus_bubble_station_expend` | `map_api` | 返回结构/数量、来源/类型、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.walk_dist | test_guide_point.py::RewriteTestCase::test_minbus_expand_valid_direction_station@L7216 |
| CV-164 | #68 `minbus_bubble_station_expend:*` | `BatchGetGeoGP` | `minbus_bubble_station_expend` | `map_api` | 返回结构/数量、坐标/链路合法性、展示文案/名称、距离/路线 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.id, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.walk_dist | test_guide_point.py::RewriteTestCase::test_minbus_expand_castle_mis_station@L7313 |
| CV-165 | #42 `acc_far_away:*` | `BatchGetGeoGP` | `acc_far_away` | `map_api` | 返回结构/数量、来源/类型、展示文案/名称 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.choose_x_srctag, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.notice_msg | test_guide_point.py::RewriteTestCase::test_trigger_and_acc_far_away_nearby@L7462 |
| CV-166 | #30 `drag:*` | `BatchGetGeoGP` | `drag` | `map_api` | 协议/业务码、返回结构/数量、来源/类型、展示文案/名称 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.gp_list.short_name | test_guide_point.py::RewriteTestCase::test_guide_point_drag_language@L7516 |
| CV-167 | #30 `drag:*` | `BatchGetGeoGP` | `drag` | `map_api` | 协议/业务码、返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称 | res.error_code, res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.bottom_card_msg, res.res_list.dest_gp.gp_list.bottom_card_msg.caption, res.res_list.dest_gp.gp_list.bottom_card_msg.guidance_note, res.res_list.dest_gp.gp_list.bottom_card_msg.main_title, res.res_list.dest_gp.gp_list.bottom_card_msg.point_msg, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.park_info, res.res_list.dest_gp.park_info.icon_text, res.res_list.dest_gp.park_info.line_type | test_guide_point.py::RewriteTestCase::test_guide_point_island_reason_null@L7545 |
| CV-168 | #17 `pickup:route-broker` | `GetGuidePointList` | `pickup` | `route-broker` | 协议/业务码、返回结构/数量 | res.error_code, res.guide_point_list | test_guide_point.py::RewriteTestCase::test_rb_pickup@L7589 |
| CV-169 | #5 `trip:route-broker` | `GetGuidePointList` | `trip` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.link_ids | test_guide_point.py::RewriteTestCase::test_rb_ora_trip_and_pickup@L7616 |
| CV-170 | #17 `pickup:route-broker` | `GetGuidePointList` | `pickup` | `route-broker` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.link_ids | test_guide_point.py::RewriteTestCase::test_rb_ora_trip_and_pickup@L7616 |
| CV-171 | #16 `pickup:OrderRouteAPI` | `GetGuidePointList` | `pickup` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.link_ids | test_guide_point.py::RewriteTestCase::test_rb_ora_trip_and_pickup@L7616 |
| CV-172 | #7 `trip:map_api` | `BatchGetGeoGP` | `trip` | `map_api` | 返回结构/数量、来源/类型、二次确认/围栏停车 | res.res_list, res.res_list.dest_gp, res.res_list.dest_gp.dbck_bottom_card, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source | test_guide_point.py::RewriteTestCase::test_kflower_dbck_bottom_card@L7693 |
| CV-173 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `mapapi` | 返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.bottom_card_msg, res.res_list.dest_gp.gp_list.bottom_card_msg.caption, res.res_list.dest_gp.gp_list.bottom_card_msg.guidance_note, res.res_list.dest_gp.gp_list.bottom_card_msg.main_title, res.res_list.dest_gp.gp_list.bottom_card_msg.point_msg, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.park_info, res.res_list.dest_gp.park_info.icon_text, res.res_list.dest_gp.park_info.icon_url, res.res_list.dest_gp.park_info.line_type, res.res_list.dest_gp.park_info.park_detail | test_guide_point.py::RewriteTestCase::test_kflower_island_trigger_secondconfirm@L7733 |
| CV-174 | #40 `island:*` | `BatchGetGeoGP` | `island` | `map_api` | 返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.bottom_card_msg, res.res_list.dest_gp.gp_list.bottom_card_msg.caption, res.res_list.dest_gp.gp_list.bottom_card_msg.guidance_note, res.res_list.dest_gp.gp_list.bottom_card_msg.main_title, res.res_list.dest_gp.gp_list.bottom_card_msg.point_msg, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.park_info, res.res_list.dest_gp.park_info.icon_text, res.res_list.dest_gp.park_info.icon_url, res.res_list.dest_gp.park_info.line_type, res.res_list.dest_gp.park_info.park_detail | test_guide_point.py::RewriteTestCase::test_kflower_island_trigger_secondconfirm@L7733 |
| CV-175 | #30 `drag:*` | `BatchGetGeoGP` | `drag` | `map_api` | 返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.bottom_card_msg, res.res_list.dest_gp.gp_list.bottom_card_msg.caption, res.res_list.dest_gp.gp_list.bottom_card_msg.guidance_note, res.res_list.dest_gp.gp_list.bottom_card_msg.main_title, res.res_list.dest_gp.gp_list.bottom_card_msg.point_msg, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.park_info, res.res_list.dest_gp.park_info.icon_text, res.res_list.dest_gp.park_info.icon_url, res.res_list.dest_gp.park_info.line_type, res.res_list.dest_gp.park_info.park_detail | test_guide_point.py::RewriteTestCase::test_kflower_island_trigger_secondconfirm@L7733 |
| CV-176 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `mapapi` | 返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.choose_x_srctag, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg | test_guide_point.py::RewriteTestCase::test_kflower_far_away_trigger_secondconfirm@L7841 |
| CV-177 | #41 `far_away:*` | `BatchGetGeoGP` | `far_away` | `map_api` | 返回结构/数量、来源/类型、二次确认/围栏停车、展示文案/名称 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.choose_x_srctag, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg | test_guide_point.py::RewriteTestCase::test_kflower_far_away_trigger_secondconfirm@L7841 |
| CV-178 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型、专项结果 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.gid, res.guide_point_list.lat, res.guide_point_list.link_ids, res.guide_point_list.lng, res.guide_point_list.uid | test_guide_point.py::RewriteTestCase::test_ora_island_lib_lnt_lat_0_0@L8143 |
| CV-179 | #84 `quad_express:*` | `GetGuidePointList` | `quad_express` | `OrderRouteAPI` | 无 response 字段断言 | — | test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_quad_express@L8206 |
| CV-180 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、坐标/链路合法性、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source, res.guide_point_list.extend_map, res.guide_point_list.link_ids | test_guide_point.py::RewriteTestCase::test_OrderRouteAPI_ipsilateral@L8346 |
| CV-181 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `mapapi` | 返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg | test_guide_point.py::RewriteTestCase::test_castle_cpo_nanshan_secondfirm@L8518 |
| CV-182 | #32 `castle:*` | `BatchGetGeoGP` | `castle` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.lat, res.res_list.dest_gp.gp_list.link_ids, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.lng, res.res_list.dest_gp.gp_list.name, res.res_list.dest_gp.gp_list.notice_msg, res.res_list.dest_gp.gp_list.recommend_msg | test_guide_point.py::RewriteTestCase::test_castle_cpo_nanshan_secondfirm@L8518 |
| CV-183 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `mapapi` | 返回结构/数量、坐标/链路合法性、二次确认/围栏停车、展示文案/名称、距离/路线 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.eta_dist, res.res_list.dest_gp.gp_list.geo, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.gp_list.walk_dist, res.res_list.dest_gp.gp_list.walk_time, res.res_list.poi_list, res.res_list.poi_list.lat, res.res_list.poi_list.lng, res.res_list.poi_list.poi_id, res.res_list.poi_list.poi_type | test_guide_point.py::RewriteTestCase::test_scenic_area_subpoi_trigger_and_push_zhongshan_zhanyuan@L9185 |
| CV-184 | #43 `scenic_area:*` | `BatchGetGeoGP` | `scenic_area` | `map_api` | 返回结构/数量、坐标/链路合法性、二次确认/围栏停车、展示文案/名称、距离/路线 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.eta_dist, res.res_list.dest_gp.gp_list.geo, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.gp_list.walk_dist, res.res_list.dest_gp.gp_list.walk_time, res.res_list.poi_list, res.res_list.poi_list.lat, res.res_list.poi_list.lng, res.res_list.poi_list.poi_id, res.res_list.poi_list.poi_type | test_guide_point.py::RewriteTestCase::test_scenic_area_subpoi_trigger_and_push_zhongshan_zhanyuan@L9185 |
| CV-185 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `mapapi` | 返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、距离/路线 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.bottom_card_msg, res.res_list.dest_gp.gp_list.bottom_card_msg.guidance_note, res.res_list.dest_gp.gp_list.bottom_card_msg.main_title, res.res_list.dest_gp.gp_list.eta_dist, res.res_list.dest_gp.gp_list.geo, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.point_assort, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.gp_list.walk_dist, res.res_list.dest_gp.gp_list.walk_time, res.res_list.poi_list, res.res_list.poi_list.lat, res.res_list.poi_list.lng, res.res_list.poi_list.poi_id, res.res_list.poi_list.poi_type | test_guide_point.py::RewriteTestCase::test_bus_same_trigger_and_push_yiwu@L9274 |
| CV-186 | #44 `bus:*` | `BatchGetGeoGP` | `bus` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、距离/路线 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.bottom_card_msg, res.res_list.dest_gp.gp_list.bottom_card_msg.guidance_note, res.res_list.dest_gp.gp_list.bottom_card_msg.main_title, res.res_list.dest_gp.gp_list.eta_dist, res.res_list.dest_gp.gp_list.geo, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.point_assort, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.gp_list.walk_dist, res.res_list.dest_gp.gp_list.walk_time, res.res_list.poi_list, res.res_list.poi_list.lat, res.res_list.poi_list.lng, res.res_list.poi_list.poi_id, res.res_list.poi_list.poi_type | test_guide_point.py::RewriteTestCase::test_bus_same_trigger_and_push_yiwu@L9274 |
| CV-187 | #59 `trigger:*` | `BatchGetGeoGP` | `trigger` | `mapapi` | 返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、距离/路线 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.bottom_card_msg, res.res_list.dest_gp.gp_list.bottom_card_msg.guidance_note, res.res_list.dest_gp.gp_list.bottom_card_msg.main_title, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.eta_dist, res.res_list.dest_gp.gp_list.geo, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.point_assort, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.gp_list.walk_dist, res.res_list.dest_gp.gp_list.walk_time, res.res_list.poi_list, res.res_list.poi_list.lat, res.res_list.poi_list.lng, res.res_list.poi_list.poi_id, res.res_list.poi_list.poi_type | test_guide_point.py::RewriteTestCase::test_bus_same_trigger_and_push_xierqi_greater_2@L9366 |
| CV-188 | #44 `bus:*` | `BatchGetGeoGP` | `bus` | `map_api` | 返回结构/数量、坐标/链路合法性、来源/类型、二次确认/围栏停车、展示文案/名称、距离/路线 | res.res_list, res.res_list.dbck_trigger_type, res.res_list.dest_gp, res.res_list.dest_gp.gp_list, res.res_list.dest_gp.gp_list.bottom_card_msg, res.res_list.dest_gp.gp_list.bottom_card_msg.guidance_note, res.res_list.dest_gp.gp_list.bottom_card_msg.main_title, res.res_list.dest_gp.gp_list.data_source, res.res_list.dest_gp.gp_list.eta_dist, res.res_list.dest_gp.gp_list.geo, res.res_list.dest_gp.gp_list.is_recommend_absorb, res.res_list.dest_gp.gp_list.list_tag_msg, res.res_list.dest_gp.gp_list.point_assort, res.res_list.dest_gp.gp_list.recommend_msg, res.res_list.dest_gp.gp_list.walk_dist, res.res_list.dest_gp.gp_list.walk_time, res.res_list.poi_list, res.res_list.poi_list.lat, res.res_list.poi_list.lng, res.res_list.poi_list.poi_id, res.res_list.poi_list.poi_type | test_guide_point.py::RewriteTestCase::test_bus_same_trigger_and_push_xierqi_greater_2@L9366 |
| CV-189 | #2 `trip:OrderRouteAPI` | `GetGuidePointList` | `trip` | `OrderRouteAPI` | 协议/业务码、返回结构/数量、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source | test_guide_point.py::RewriteTestCase::test_commom_rerank_better_point@L9471 |
| CV-190 | #82 `model_predict_cache:*` | `GetGuidePointList` | `model_predict_cache` | `wanliu_order_created` | 协议/业务码、返回结构/数量、来源/类型 | res.error_code, res.guide_point_list, res.guide_point_list.data_source | test_guide_point.py::RewriteTestCase::test_model_predict_risk_cache_better_point@L9497 |

## C. response 断言的原始证据

本节让“response 聚类”可回溯：不是 AI 根据 case 名臆测场景，而是从 `assert*` 里的 response 字段和断言表达式抽取。每个验证子场景只列前 3 条去重后的断言；完整断言仍以对应 case 源码为准。

### CV-001：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertTrue(73 <= point.lng <= 135, f'点位经度 {point.lng} 不在中国境内')`

### CV-002：`BatchGetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertEqual(len(request_list), len(res.response_list))`
- `self.assertGreater(len(response.guide_point_list), 0)`

### CV-003：`GetGeoGP` / `island` / `map_api`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertTrue(73 <= point.lng <= 135, f'点位经度 {point.lng} 不在中国境内')`

### CV-004：`BatchGetGeoGP` / `island` / `map_api`

- `self.assertEqual(0, res.error_code)`
- `self.assertEqual(len(req_list), len(res.res_list))`
- `self.assertGreater(len(response.dest_gp.gp_list), 0)`

### CV-005：`GetGuidePointList` / `pickup` / `OrderRouteAPI`

- `self.assertEqual('OK', res.error_msg)`

### CV-006：`GetGuidePointList` / `trip` / `map_api`

- `self.assertEqual('OK', res.error_msg)`
- `self.assertTrue(len(res.guide_point_list) > 0)`

### CV-007：`GetGuidePointList` / `trip` / ``

- `self.assertEqual('OK', res.error_msg)`
- `self.assertTrue(len(res.guide_point_list) > 0)`

### CV-009：`BatchGetGeoGP` / `trigger` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual('castle', res.res_list[0].dbck_trigger_type)`
- `self.assertEqual(res.res_list[i].dbck_trigger_type == 'castle', 1)`

### CV-010：`BatchGetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list) > 0, 1)`
- `self.assertTrue(len(res.res_list[0].dest_gp.gp_list[i].id.split('_')) == 4)`

### CV-011：`GetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list) > 0, 1)`
- `self.assertTrue(len(res.res_list[0].dest_gp.gp_list[i].id.split('_')) == 4)`

### CV-012：`GetGeoGP` / `castle` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.ori_gp, None)`
- `self.assertEqual(len(res.dest_gp.castle_info) > 0, 1)`

### CV-013：`BatchGetGeoGP` / `castle` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.ori_gp, None)`
- `self.assertEqual(len(res.dest_gp.castle_info) > 0, 1)`

### CV-014：`BatchGetGeoGP` / `park` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.ori_gp, None)`
- `self.assertEqual(len(res.dest_gp.castle_info) > 0, 1)`

### CV-015：`GetGuidePointList` / `trip` / `None`

- `self.assertEqual(res.guide_point_list[0].uid, '8314157447236438749')`
- `self.assertEqual(len(res.guide_point_list[0].poi_name) > 0, 1)`
- `self.assertEqual(res.guide_point_list[0].lng, 118.718997)`

### CV-016：`GetGuidePointList` / `trip` / `map_api`

- `self.assertEqual(res.guide_point_list[0].uid, '8314157447236438749')`
- `self.assertEqual(len(res.guide_point_list[0].poi_name) > 0, 1)`
- `self.assertEqual(res.guide_point_list[0].lng, 118.718997)`

### CV-017：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(res.guide_point_list[0].uid, '8314157447236438749')`
- `self.assertEqual(len(res.guide_point_list[0].poi_name) > 0, 1)`
- `self.assertEqual(res.guide_point_list[0].lng, 118.718997)`

### CV-020：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`

### CV-021：`GetGeoGP` / `multiple` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertIsNone(res.ori_gp)`
- `self.assertNotEqual(len(res.dest_gp.castle_info), 0)`

### CV-022：`BatchGetGeoGP` / `multiple` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertIsNone(res.ori_gp)`
- `self.assertNotEqual(len(res.dest_gp.castle_info), 0)`

### CV-024：`GetGeoGP` / `multiple` / `map_api`

- `self.assertFalse(res.dest_gp.gp_list[i].is_recommend_absorb, '非top1不是引导点推荐的点')`
- `self.assertTrue(u'' == res.dest_gp.gp_list[i].list_tag_msg or json.loads(res.dest_gp.gp_list[i].list_tag_msg)['content'] == u'最多人选' or json.loads(res.dest_gp.gp_list[i].list_tag_msg)['content'] == u'经常下车')`
- `self.assertTrue(res.dest_gp.gp_list[i].is_recommend_absorb, 'top1是引导点推荐的点')`

### CV-027：`GetGeoGP` / `mis` / `map_api`

- `self.assertEqual(len(res.dest_gp.gp_list), 2)`
- `self.assertTrue(point.poi_id.find('2000000000000616228') != -1)`
- `self.assertTrue(point.lng > 116 and point.lng < 117)`

### CV-029：`BatchGetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`

### CV-030：`BatchGetGuidePointList` / `trip_top1_park` / `wanliu_order_created`

- `self.assertEqual(0, res.error_code)`

### CV-031：`GetGuidePointList` / `?` / `?`

- `self.assertEqual(len(res.guide_point_list), 0)`

### CV-032：`BatchGetGuidePointList` / `trip_top1_park` / `wanliu_passenger_estimate_req`

- `self.assertEqual(0, res.error_code)`

### CV-033：`GetGeoGP` / `trip` / ``

- `self.assertGreaterEqual(len(res.dest_gp.gp_list), 0)`

### CV-034：`GetGeoGP` / `mis` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 1)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_com_mis')`
- `self.assertIn('dropoff_dbck_com_mis', res.dest_gp.gp_list[0].choose_x_srctag)`

### CV-035：`GetGeoGP` / `mis` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_com_mis')`
- `self.assertIn('dropoff_dbck_com_mis', res.dest_gp.gp_list[0].choose_x_srctag)`

### CV-036：`GetGeoGP` / `broad` / `map_api`

- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('dropoff_dbck_recall_broad', res.dest_gp.gp_list[0].choose_x_srctag)`
- `self.assertNotIn('当前较少拥挤', res.dest_gp.gp_list[0].list_tag_msg)`

### CV-037：`GetGeoGP` / `castle` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 1)`
- `self.assertIn('dropoff_dbck', res.dest_gp.gp_list[0].choose_x_srctag)`
- `self.assertNotIn('当前较少拥挤', res.dest_gp.gp_list[0].list_tag_msg)`

### CV-038：`GetGeoGP` / `multiple` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertIn('dropoff_dbck_recall_multiple', res.dest_gp.gp_list[0].choose_x_srctag)`
- `self.assertNotIn('当前较少拥挤', res.dest_gp.gp_list[0].list_tag_msg)`

### CV-039：`GetGeoGP` / `search_default` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('dropoff_dbck_recall_searchdefault', res.dest_gp.gp_list[0].choose_x_srctag)`

### CV-040：`GetGeoGP` / `default` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('dropoff_dbck_recall_default', res.dest_gp.gp_list[0].choose_x_srctag)`

### CV-041：`GetGeoGP` / `drag` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('dropoff_dbck_recall_drag', res.dest_gp.gp_list[0].choose_x_srctag)`

### CV-042：`GetGeoGP` / `park` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 1)`
- `self.assertIn(res.dest_gp.gp_list[0].data_source, ['park_rerank', 'didi_dropoff', 'off_island'])`
- `self.assertIn('dropoff_dbck_recall_park', res.dest_gp.gp_list[0].choose_x_srctag)`

### CV-043：`GetGeoGP` / `unreach` / `map_api`

- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('dropoff_dbck_recall_unreach', res.dest_gp.gp_list[0].choose_x_srctag)`
- `self.assertNotIn('当前较少拥挤', res.dest_gp.gp_list[0].list_tag_msg)`

### CV-044：`GetGeoGP` / `estimate_trip` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[i].data_source, 'didi_dropoff')`

### CV-045：`GetGeoGP` / `hac_drag` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('dropoff_dbck_recall_hacdrag', res.dest_gp.gp_list[0].choose_x_srctag)`

### CV-046：`GetGuidePointList` / `trip` / `route-broker`

- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertNotEqual(res.guide_point_list[0].data_source, 'dropoff_castle')`

### CV-047：`GetGeoGP` / `drag` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertIn('dropoff_dbck_castle_drag', res.dest_gp.gp_list[0].choose_x_srctag)`
- `self.assertNotIn('当前较少拥挤', res.dest_gp.gp_list[0].list_tag_msg)`

### CV-048：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'dropoff_castle')`
- `self.assertEqual(res.guide_point_list[0].data_source, 'didi_dropoff')`

### CV-049：`GetGeoGP` / `castle` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 1)`
- `self.assertIn('dropoff_dbck_castle', res.dest_gp.gp_list[0].choose_x_srctag)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`

### CV-050：`GetGuidePointList` / `trip` / `map_api`

- `self.assertEqual(0, res.error_code)`
- `self.assertEqual(res.broadcast_able, 1)`

### CV-051：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertGreater(len(res.recommend_info), 10)`
- `self.assertTrue(json.loads(res.recommend_info)['fence_list'][0]['fence_id'] == '2000000000049309797' or json.loads(res.recommend_info)['fence_list'][0]['fence_id'] == '2000000000040209067')`

### CV-052：`GetGuidePointList` / `trip` / `dolphin_api`

- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertGreater(len(res.recommend_info), 10)`
- `self.assertTrue(json.loads(res.recommend_info)['fence_list'][0]['fence_id'] == '2000000000049309797' or json.loads(res.recommend_info)['fence_list'][0]['fence_id'] == '2000000000040209067')`

### CV-053：`GetGuidePointList` / `dolphin_point_rec` / `textsearch`

- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-054：`GetGeoGP` / `trip` / `map_manta_anycar_subway_combine`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`

### CV-055：`GetGeoGP` / `trip` / `map_manta_bicycle_subway_combine`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`

### CV-056：`GetGuidePointList` / `trip` / `wanliu_passenger_estimate_req`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 1)`

### CV-057：`GetGuidePointList` / `odpoint` / `wanliu_passenger_estimate_req`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 1)`

### CV-058：`GetGuidePointList` / `trip` / `wanliu_order_created`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-061：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertGreater(len(res.guide_point_list[0].link_ids), 0)`

### CV-062：`GetGeoGP` / `trigger` / `mapapi`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual('mis', res.dbck_trigger_type)`

### CV-063：`GetGuidePointList` / `trip_top1_park` / `wanliu_passenger_estimate_req`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-064：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-065：`GetGuidePointList` / `trip` / `route-broker`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'dropoff_additional')`

### CV-066：`BatchGetGeoGP` / `island` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertIn('推荐下车点', res.res_list[0].dest_gp.gp_list[0].recommend_msg)`
- `self.assertIn('目的地附近道路有通行限制，为您推荐适合的下车位置', res.res_list[0].dest_gp.gp_list[0].notice_msg)`

### CV-067：`BatchGetGeoGP` / `trigger` / `map_api`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'castle')`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertIn('dropoff_dbck_castle_castle_mapapicastlenew', res.res_list[0].dest_gp.gp_list[i].choose_x_srctag)`

### CV-068：`BatchGetGeoGP` / `castle` / `mapapi`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'castle')`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertIn('dropoff_dbck_castle_castle_mapapicastlenew', res.res_list[0].dest_gp.gp_list[i].choose_x_srctag)`

### CV-069：`BatchGetGeoGP` / `trigger` / `map_api`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'castle')`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[i].data_source, 'didi_dropoff')`

### CV-070：`BatchGetGeoGP` / `?` / `mapapi`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'castle')`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[i].data_source, 'didi_dropoff')`

### CV-071：`GetGuidePointList` / `pickup` / `wanliu_passenger_estimate_req`

- `self.assertEqual(0, res.error_code)`
- `self.assertEqual(res.error_msg, 'OK')`
- `self.assertEqual(len(res.guide_point_list), 1)`

### CV-072：`GetGeoGP` / `offline_cluster_rec` / `map_manta_anycar_subway_combine`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertNotEqual(res.dest_gp.rgeo_result, '')`

### CV-073：`GetGeoGP` / `offline_cluster_rec` / `map_manta_bicycle_subway_combine`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertNotEqual(res.dest_gp.rgeo_result, '')`

### CV-074：`GetGeoGP` / `broad` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertIn('图景嘉园', res.dest_gp.gp_list[0].name)`
- `self.assertIn('解放军总医院第八医学中心', res.dest_gp.gp_list[0].name)`

### CV-075：`GetGeoGP` / `multiple` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertIn('图景嘉园', res.dest_gp.gp_list[0].name)`
- `self.assertIn('解放军总医院第八医学中心', res.dest_gp.gp_list[0].name)`

### CV-076：`GetGuidePointList` / `trip_top1_park` / `wanliu_order_created`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertNotEqual(guide_point.lng, '0.0')`

### CV-077：`GetGeoGP` / `multiple` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertEqual(res.dest_gp.gp_list[0].category_code, '271013')`

### CV-079：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(len(res.guide_point_list), len(res1.guide_point_list))`
- `self.assertEqual(res.guide_point_list[i].lng, res1.guide_point_list[i].lng)`
- `self.assertEqual(res.guide_point_list[i].lat, res1.guide_point_list[i].lat)`

### CV-080：`GetGuidePointList` / `?` / `?`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertGreater(len(res.guide_point_list[0].link_ids), 0)`

### CV-081：`BatchGetGeoGP` / `intelligent_minbus_station` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertLessEqual(res.res_list[0].dest_gp.gp_list[i].walk_dist, 600)`
- `self.assertNotEqual(res.res_list[0].dest_gp.gp_list[i].id, '')`

### CV-082：`BatchGetGeoGP` / `intelligent_minbus_station` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 1)`
- `self.assertGreater(res.res_list[0].dest_gp.gp_list[1].lng, 0)`
- `self.assertGreater(res.res_list[0].dest_gp.gp_list[1].lat, 0)`

### CV-083：`BatchGetGeoGP` / `scancode_minbus_station` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertGreaterEqual(res.res_list[0].dest_gp.gp_list[i].walk_dist, pre_walk_dist)`
- `self.assertLessEqual(res.res_list[0].dest_gp.gp_list[i].walk_dist, 600)`

### CV-084：`BatchGetGeoGP` / `intelligent_minbus_station` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertEqual(res.res_list[0].dest_gp.rec_type, 'smartbus_loc')`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list), 6)`

### CV-085：`BatchGetGeoGP` / `intelligent_minbus_station` / `map_api`

- `self.assertEqual(res.res_list[0].dest_gp.rec_type, 'smartbus_degrade')`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[i].data_source, 'smartbus_offline_degrade')`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[i].m_type, 6)`

### CV-086：`BatchGetGeoGP` / `intelligent_minbus_station` / `map_api`

- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list), 0)`

### CV-087：`BatchGetGeoGP` / `intelligent_minbus_express_station` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertGreaterEqual(gp_list.walk_dist, pre_walk_dist)`
- `self.assertLessEqual(gp_list.walk_dist, 500)`

### CV-088：`BatchGetGeoGP` / `intelligent_minbus_express_station` / `map_api`

- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list), 0)`

### CV-089：`BatchGetGeoGP` / `intelligent_minbus_station` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertNotEqual(res.res_list[0].dest_gp.gp_list[i].id, '')`
- `self.assertNotEqual(res.res_list[0].dest_gp.gp_list[i].name, '')`

### CV-090：`BatchGetGeoGP` / `estimate_trip` / `map_api`

- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list), 1)`
- `self.assertNotEqual(res.res_list[0].dest_gp.gp_list[i].id, '')`
- `self.assertNotEqual(res.res_list[0].dest_gp.gp_list[i].name, '')`

### CV-091：`BatchGetGeoGP` / `intelligent_minbus_express_station` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertEqual(gp_list.id, '3886702674192629760_90000813065330')`
- `self.assertNotEqual(gp_list.name, '')`

### CV-092：`BatchGetGeoGP` / `trigger` / `mapapi`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(None, res.res_list[0].dbck_trigger_type)`
- `self.assertGreater(len(res.res_list), 0)`

### CV-097：`BatchGetGeoGP` / `drag` / `map_api`

- `self.assertEqual(len(res.res_list[0].dest_gp.park_info[0].park_detail) > 0, 1)`
- `self.assertEqual(res.res_list[0].dest_gp.park_info[0].gp.lng > 73, 1)`
- `self.assertEqual(res.res_list[0].dest_gp.park_info[0].gp.lng < 136, 1)`

### CV-098：`GetGuidePointList` / `dolphin_point_rec` / `dolphin_api`

- `self.assertEqual('OK', res.error_msg)`

### CV-099：`GetGuidePointList` / `trip_top1_park` / `?`

- `self.assertEqual('OK', res.error_msg)`

### CV-100：`BatchGetGuidePointList` / `trip` / `route-broker`

- `self.assertEqual(0, res.error_code)`
- `self.assertEqual(dst_uid, guide_point.uid)`
- `self.assertEqual(dst_lng, guide_point.lng)`

### CV-101：`BatchGetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertEqual(dst_uid, guide_point.uid)`
- `self.assertEqual(dst_lng, guide_point.lng)`

### CV-102：`BatchGetGuidePointList` / `?` / `?`

- `self.assertEqual(0, response.error_code)`

### CV-103：`GetGeoGP` / `multiple` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertIsNone(res.ori_gp)`
- `self.assertGreater(len(res.dest_gp.gp_list), 1)`

### CV-104：`BatchGetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list) > 0, 1)`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list[i].name) > 0, 1)`

### CV-105：`GetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list) > 0, 1)`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list[i].name) > 0, 1)`

### CV-106：`GetGeoGP` / `cpo` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.ori_gp, None)`
- `self.assertEqual(len(res.dest_gp.gp_list) > 0, 1)`

### CV-107：`BatchGetGeoGP` / `cpo` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.ori_gp, None)`
- `self.assertEqual(len(res.dest_gp.gp_list) > 0, 1)`

### CV-108：`GetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertTrue(res.dest_gp.rgeo_result.id != '')`
- `self.assertEqual(res.dest_gp.rgeo_result.poi_id, res.dest_gp.rgeo_result.id)`

### CV-109：`BatchGetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertTrue(res.dest_gp.rgeo_result.id != '')`
- `self.assertEqual(res.dest_gp.rgeo_result.poi_id, res.dest_gp.rgeo_result.id)`

### CV-110：`GetGeoGP` / `park` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.dest_gp.rgeo_result.id, '2000000000048861010')`
- `self.assertEqual(res.dest_gp.rgeo_result.poi_id, '2000000000048861010')`

### CV-111：`BatchGetGeoGP` / `park` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.dest_gp.rgeo_result.id, '2000000000048861010')`
- `self.assertEqual(res.dest_gp.rgeo_result.poi_id, '2000000000048861010')`

### CV-112：`GetGuidePointList` / `pickup` / `OrderRouteAPI`

- `self.assertGreater(len(guide_point_list), 0)`

### CV-113：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertTrue(res.guide_point_list[0].lat > 40.05 and res.guide_point_list[0].lat < 40.1)`
- `self.assertTrue(res.guide_point_list[0].lng > 116.32 and res.guide_point_list[0].lat < 116.33)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'off_tollgate')`

### CV-114：`GetGuidePointList` / `trip_top1_park` / `wanliu_passenger_estimate_req`

- `self.assertTrue(res.guide_point_list[0].lat > 40.05 and res.guide_point_list[0].lat < 40.1)`
- `self.assertTrue(res.guide_point_list[0].lng > 116.32 and res.guide_point_list[0].lat < 116.33)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'off_tollgate')`

### CV-115：`GetGuidePointList` / `trip` / `route-broker`

- `self.assertTrue(res.guide_point_list[0].lat > 40.05 and res.guide_point_list[0].lat < 40.1)`
- `self.assertTrue(res.guide_point_list[0].lng > 116.32 and res.guide_point_list[0].lat < 116.33)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'off_tollgate')`

### CV-116：`GetGuidePointList` / `trip` / `map_manta_bicycle_subway_combine`

- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-117：`GetGeoGP` / `valet_driver` / ``

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.dest_gp.gp_list), 0)`
- `self.assertGreater(len(res.dest_gp.rgeo_result.poi_id), 0)`

### CV-118：`BatchGetGeoGP` / `auto_drive_voyager` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`

### CV-119：`GetGeoGP` / `minbus_bubble_station` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'point_minbus')`

### CV-120：`BatchGetGeoGP` / `estimate_trip` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertIn(res.res_list[0].dest_gp.gp_list[0].data_source, ['didi_com_mis', 'didi_dropoff'])`
- `self.assertNotIn('当前较少拥挤', res.res_list[0].dest_gp.gp_list[0].list_tag_msg)`

### CV-121：`GetGeoGP` / `castle` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'dropoff_castle')`
- `self.assertIn('dropoff_dbck_castle', res.dest_gp.gp_list[0].choose_x_srctag)`

### CV-122：`GetGeoGP` / `dolphin_poi_detail` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'dolp_bind_poi')`

### CV-123：`GetGuidePointList` / `trip` / `BicyclingNaviAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreaterEqual(len(res.guide_point_list), 3)`

### CV-124：`GetGuidePointList` / `carpool` / `carpool_route_matcher`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].category_code, '282000')`

### CV-125：`GetGuidePointList` / `trip` / `DavinciNaviAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.recommend_info), 10)`
- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-126：`GetGuidePointList` / `dolphin_point_rec` / `dubhe_edit_search_svr`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.recommend_info), 10)`
- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-127：`GetGeoGP` / `endinfo` / `mapapi`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.dest_gp.castle_info[0]), 10)`
- `self.assertGreater(len(res.dest_gp.rgeo_result.poi_id), 0)`

### CV-128：`GetGeoGP` / `trip` / `mapapi`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreaterEqual(len(res.dest_gp.gp_list), 0)`
- `self.assertTrue(res.dest_gp.rgeo_result.id != '')`

### CV-129：`GetGuidePointList` / `odpoint` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].category_code, '281010')`

### CV-130：`GetGuidePointList` / `pickup` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].lng, 116.848381)`

### CV-131：`GetGuidePointList` / `valet_driving` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(guide_point.data_source, 'didi_dropoff')`

### CV-132：`GetGuidePointList` / `odpoint` / `route-broker`

- `self.assertEqual(0, res.error_code)`
- `self.assertEqual(len(res.guide_point_list), 1)`
- `self.assertTrue(res.guide_point_list[0].data_source == 'dropoff_additional' or res.guide_point_list[0].data_source == 'dropoff_poi_bind')`

### CV-133：`GetGuidePointList` / `trip_top1_park` / `wanliu_passenger_estimate_req`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].category_code, '281010')`

### CV-134：`GetGuidePointList` / `trip_top1_park` / `wanliu_order_created`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertGreater(len(res.castle_info[0]), 10)`

### CV-136：`GetGeoGP` / `hac_drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'didi_dropoff')`

### CV-137：`GetGeoGP` / `minbus_bubble_station` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'guide_point')`

### CV-138：`GetGuidePointList` / `carpool` / `carpool_route_matcher`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-139：`GetGeoGP` / `minbus_bubble_station` / `map_api`

- `self.assertGreater(len(res.dest_gp.gp_list), 0)`
- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'hot_route_point_minbus')`
- `self.assertIsNotNone(res.dest_gp.gp_list[0].hot_route_info[0].route_id)`

### CV-140：`BatchGetGeoGP` / `specify_coordinate` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list) > 0, 1)`
- `self.assertTrue(len(res.res_list[0].dest_gp.gp_list[i].id.split('_')) == 4)`

### CV-141：`GetGeoGP` / `specify_coordinate` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list) > 0, 1)`
- `self.assertTrue(len(res.res_list[0].dest_gp.gp_list[i].id.split('_')) == 4)`

### CV-142：`GetGeoGP` / `minbus_bubble_station` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreaterEqual(len(res.dest_gp.gp_list), 2)`
- `self.assertLessEqual(len(res.dest_gp.gp_list), 14)`

### CV-143：`BatchGetGeoGP` / `passenger_estimate_pickup_req` / `poi_sendhistory`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list[0].link_ids), 0)`

### CV-144：`GetGuidePointList` / `trip` / `route-broker`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list[0].link_ids), 0)`

### CV-145：`GetGuidePointList` / `pickup` / `route-broker`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list[0].link_ids), 0)`

### CV-146：`GetGuidePointList` / `trip` / `route-broker`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertNotEqual(res.guide_point_list[0].data_source, 'dropoff_additional')`

### CV-147：`GetGuidePointList` / `pickup` / `route-broker`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertNotEqual(res.guide_point_list[0].data_source, 'dropoff_additional')`

### CV-148：`GetGeoGP` / `trip` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreaterEqual(len(res.dest_gp.gp_list), 0)`
- `self.assertGreater(len(res.dest_gp.castle_info[0]), 10)`

### CV-149：`GetGuidePointList` / `?` / `?`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.error_msg, 'OK')`
- `self.assertNotEqual(len(res.guide_point_list), 0)`

### CV-150：`BatchGetGeoGP` / `trip` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.res_list[0].dest_gp.park_info[0].icon_text, '临时封闭')`
- `self.assertEqual(res.res_list[0].dest_gp.park_info[0].line_type, 'island')`

### CV-151：`BatchGetGeoGP` / `castle` / `mapapi`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'castle')`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[i].data_source, 'dropoff_castle')`

### CV-152：`BatchGetGeoGP` / `net_platform` / `map_api`

- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list), 1)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'bus_subway')`

### CV-153：`GetGuidePointList` / `trip` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.error_msg, 'OK')`
- `self.assertEqual(len(res.guide_point_list), 1)`

### CV-154：`GetGeoGP` / `jw_trip` / `map_api`

- `self.assertEqual(len(res.dest_gp.gp_list), 1)`
- `self.assertEqual(res.dest_gp.gp_list[0].poi_id, poi_id)`

### CV-155：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertEqual(int(res.guide_point_list[i].extend_map['cross_lane_num']), 0)`
- `self.assertEqual(res.guide_point_list[i].extend_map['cross_road_level'], 'no')`

### CV-156：`GetGeoGP` / `castle` / `map_api`

- `self.assertEqual(len(res.dest_gp.gp_list), 2)`

### CV-157：`GetGeoGP` / `minbus_bubble_station` / `map_api`

- `self.assertEqual(res.dest_gp.gp_list[0].data_source, 'guide_point')`
- `self.assertEqual(res.dest_gp.gp_list[0].lng, 116.27362)`
- `self.assertEqual(res.dest_gp.gp_list[0].lat, 40.065783)`

### CV-158：`GetGeoGP` / `minbus_bubble_station` / `map_api`

- `self.assertEqual(len(res.dest_gp.gp_list), 4)`
- `self.assertEqual(res.dest_gp.gp_list[i].data_source, 'dropoff_castle')`
- `self.assertNotEqual(res.dest_gp.gp_list[0].link_ids, [])`

### CV-159：`GetGuidePointList` / `trip` / `route-broker`

- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'didi_com_mis')`
- `self.assertEqual(res.guide_point_list[0].poi_name, '다이아몬드 빌딩 동남문')`

### CV-160：`GetGuidePointList` / `trip` / `wanliu_passenger_estimate_req`

- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'didi_com_mis')`
- `self.assertEqual(res.guide_point_list[0].poi_name, '다이아몬드 빌딩 동남문')`

### CV-161：`BatchGetGeoGP` / `minbus_bubble_station_expend` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertLessEqual(len(res.res_list[0].dest_gp.gp_list), 13)`
- `self.assertGreaterEqual(gp_list.walk_dist, pre_walk_dist)`

### CV-162：`BatchGetGeoGP` / `minbus_bubble_station_expend` / `map_api`

- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 1)`

### CV-163：`BatchGetGeoGP` / `minbus_bubble_station_expend` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertGreaterEqual(gp_list.walk_dist, 200)`
- `self.assertIn(gp_list.data_source, ['point_minbus'])`

### CV-164：`BatchGetGeoGP` / `minbus_bubble_station_expend` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertGreaterEqual(gp_list.walk_dist, pre_walk_dist)`
- `self.assertEqual(gp_list.walk_dist, 0)`

### CV-165：`BatchGetGeoGP` / `acc_far_away` / `map_api`

- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertIn('accfaraway', res.res_list[0].dest_gp.gp_list[i].choose_x_srctag)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'didi_dropoff')`

### CV-166：`BatchGetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'dropoff_drag')`
- `self.assertTrue(is_english_or_korean_strict(res.res_list[0].dest_gp.gp_list[0].name))`

### CV-167：`BatchGetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'dropoff_drag')`

### CV-168：`GetGuidePointList` / `pickup` / `route-broker`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.guide_point_list), 0)`

### CV-169：`GetGuidePointList` / `trip` / `route-broker`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.guide_point_list), 2)`
- `self.assertEqual('dropoff_dbck', res.guide_point_list[0].data_source)`

### CV-170：`GetGuidePointList` / `pickup` / `route-broker`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.guide_point_list), 2)`
- `self.assertEqual('dropoff_dbck', res.guide_point_list[0].data_source)`

### CV-171：`GetGuidePointList` / `pickup` / `OrderRouteAPI`

- `self.assertEqual(res.error_code, 0)`
- `self.assertEqual(len(res.guide_point_list), 2)`
- `self.assertEqual('dropoff_dbck', res.guide_point_list[0].data_source)`

### CV-172：`BatchGetGeoGP` / `trip` / `map_api`

- `self.assertEqual(res.res_list[0].dest_gp.dbck_bottom_card, 'https://dpubstatic.udache.com/static/dpubimg/dpNWfae-wXIHEFuGZp2L6.png')`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'lib_island')`

### CV-173：`BatchGetGeoGP` / `trigger` / `mapapi`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'island')`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('推荐下车点', res.res_list[0].dest_gp.gp_list[0].recommend_msg)`

### CV-174：`BatchGetGeoGP` / `island` / `map_api`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'island')`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('推荐下车点', res.res_list[0].dest_gp.gp_list[0].recommend_msg)`

### CV-175：`BatchGetGeoGP` / `drag` / `map_api`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'island')`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertIn('推荐下车点', res.res_list[0].dest_gp.gp_list[0].recommend_msg)`

### CV-176：`BatchGetGeoGP` / `trigger` / `mapapi`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'far_away')`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`

### CV-177：`BatchGetGeoGP` / `far_away` / `map_api`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'far_away')`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'didi_dropoff')`
- `self.assertGreater(len(res.res_list[0].dest_gp.gp_list), 0)`

### CV-178：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(0, res.error_code)`
- `self.assertTrue('didi_dropoff' == res.guide_point_list[0].data_source or 'lib_island' == res.guide_point_list[0].data_source)`

### CV-180：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(res.error_code, 0)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'didi_dropoff')`

### CV-181：`BatchGetGeoGP` / `trigger` / `mapapi`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'castle')`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list), 1)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'dropoff_castle')`

### CV-182：`BatchGetGeoGP` / `castle` / `map_api`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'castle')`
- `self.assertEqual(len(res.res_list[0].dest_gp.gp_list), 1)`
- `self.assertEqual(res.res_list[0].dest_gp.gp_list[0].data_source, 'dropoff_castle')`

### CV-183：`BatchGetGeoGP` / `trigger` / `mapapi`

- `self.assertTrue(res.res_list[0].dbck_trigger_type == 'scenic_area' or res.res_list[0].dbck_trigger_type == 'mis')`
- `self.assertTrue(len(poi.poi_id) > 0)`
- `self.assertIsNotNone(poi.lng)`

### CV-184：`BatchGetGeoGP` / `scenic_area` / `map_api`

- `self.assertTrue(res.res_list[0].dbck_trigger_type == 'scenic_area' or res.res_list[0].dbck_trigger_type == 'mis')`
- `self.assertTrue(len(poi.poi_id) > 0)`
- `self.assertIsNotNone(poi.lng)`

### CV-185：`BatchGetGeoGP` / `trigger` / `mapapi`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'bus')`
- `self.assertEqual(len(res.res_list[0].poi_list), 1)`
- `self.assertTrue(len(poi.poi_id) > 0)`

### CV-186：`BatchGetGeoGP` / `bus` / `map_api`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'bus')`
- `self.assertEqual(len(res.res_list[0].poi_list), 1)`
- `self.assertTrue(len(poi.poi_id) > 0)`

### CV-187：`BatchGetGeoGP` / `trigger` / `mapapi`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'bus')`
- `self.assertEqual(len(res.res_list[0].poi_list), 2)`
- `self.assertTrue(len(poi.poi_id) > 0)`

### CV-188：`BatchGetGeoGP` / `bus` / `map_api`

- `self.assertEqual(res.res_list[0].dbck_trigger_type, 'bus')`
- `self.assertEqual(len(res.res_list[0].poi_list), 2)`
- `self.assertTrue(len(poi.poi_id) > 0)`

### CV-189：`GetGuidePointList` / `trip` / `OrderRouteAPI`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'didi_dropoff')`

### CV-190：`GetGuidePointList` / `model_predict_cache` / `wanliu_order_created`

- `self.assertEqual(0, res.error_code)`
- `self.assertGreater(len(res.guide_point_list), 0)`
- `self.assertEqual(res.guide_point_list[0].data_source, 'didi_dropoff')`

## D. 需要人工/AI 复核的未解析项

以下不是“没有场景”，而是 case 通过全局变量、`exec`、列表构造或多请求复用，静态分析无法确定唯一的 `(req_type, caller_id)`。这些必须由 AI 读取上下文后给候选值，再由规则或人工确认；没有确认前不能拿来自动拉日志。

| 验证 ID | 接口 | 已知 req_type | 已知 caller_id | case ID |
|---|---|---|---|---|
| CV-031 | `GetGuidePointList` | `?` | `?` | test_kflower_guide_point.py::RewriteTestCase::test_enclosure_cover@L1666<br>test_guide_point.py::RewriteTestCase::test_enclosure_cover@L3198 |
| CV-070 | `BatchGetGeoGP` | `?` | `mapapi` | test_kflower_guide_point.py::RewriteTestCase::test_smis_and_castle_conflict_recall@L3066 |
| CV-080 | `GetGuidePointList` | `?` | `?` | test_kflower_guide_point.py::RewriteTestCase::test_di_count_small@L3673<br>test_guide_point.py::RewriteTestCase::test_di_count_small@L7371 |
| CV-099 | `GetGuidePointList` | `trip_top1_park` | `?` | test_guide_point.py::RewriteTestCase::test_dolphin_station@L1261 |
| CV-102 | `BatchGetGuidePointList` | `?` | `?` | test_guide_point.py::RewriteTestCase::test_crm@L1792 |
| CV-149 | `GetGuidePointList` | `?` | `?` | test_guide_point.py::RewriteTestCase::test_di_check_lat_lng@L5588 |

## E. 对场景库工程的落地含义

1. 日志拉取先按 `RouteSceneKey`：服务、接口、`req_type`、`caller_id`（以及必要的城市/产品/开关）。这保证拿到的是相同路由链。
2. 筛 case 不能只看 `req_type/caller_id`：再选 `ValidationSceneKey`，例如只挑包含 `dbck_trigger_type` 的二次确认 case，或只挑 `walk_dist/hot_route_info` 的智能小巴 case。
3. 合并/去重只合并完全相同的路由和验证 profile；不同 response 期望保留多个子场景。最终 HDFS 元数据至少存：`route_scene_id`、`validation_scene_id`、`case_ids`、`request_filter`、`response_assertions`、`source_commit`、`date`。
4. 失败 case 用最新点位重跑时，区分两种结论：原 case 的固定预期回归，以及“同路由 + 同验证维度”的最新场景数据验证；后者不应覆盖前者的失败结论。

## 本次结论

现在应该把两个文档一起当作“场景库输入”：静态路由清单回答“线上日志怎样筛”，本文件回答“筛到后由哪些 case、按什么 response 能力验证”。仅有前者不符合 mentor 所说的“case 验证场景聚类、合并、去重”。
