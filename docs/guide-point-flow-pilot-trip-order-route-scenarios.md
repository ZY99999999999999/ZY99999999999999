# 引导点统一场景聚合试点：订单下车 `trip + OrderRouteAPI`

## 试点范围

这是全量场景库的第一个可执行聚合样例，不是只列一条路由。

| 项目 | 内容 |
|---|---|
| 服务 | `guide-point-flow-v2` |
| 路由场景 ID | `guide-point-flow-v2:trip:OrderRouteAPI` |
| RPC 接口 | `GetGuidePointList`（另有批量接口 `BatchGetGuidePointList`） |
| 路由条件 | `req_type=trip` 且 `caller_id=OrderRouteAPI` |
| 代码配置 | `parameter.conf` 中 caller 精确路由；优先于 `trip:*` 默认路由 |
| 代码执行能力 | `additional_scene`、`link_bind_scene`、下车 union、步行/骑行、通用/个性化 MIS、订单缓存、`dbck_scene`、POI 校验 |
| Case 来源 | `ModulesCaseNew/cases/guide_point_new/test_ai_guide_flow.py`、`test_guide_point.py`、`test_kflower_guide_point.py` |

> 聚合规则：只有“相同路由 + 相同关键输入语义 + 相同 response 期望”才合并。相同 `req_type/caller_id`、但 response 期望不同，必须保留为不同统一场景。

## 聚合后的统一验证场景

| 统一场景 ID | 请求条件（除路由外） | response 验证规则 | 对应 case | 是否可用最新日志重跑 |
|---|---|---|---|---|
| `GP-TRIP-ORDER-BASE-SINGLE` | 常规订单下车请求 | `error_code == 0`；`guide_point_list` 非空；每个点经纬度在中国范围；`link_ids` 非空且末位合法 | `test_ai_guide_flow.py::test_get_guide_point_list` | 是。通用断言，日志只需满足相同 RPC 路由和必要请求字段。 |
| `GP-TRIP-ORDER-BASE-BATCH` | 批量订单下车请求 | `error_code == 0`；返回条数等于请求条数；每个子响应点位非空、坐标/link 合法 | `test_ai_guide_flow.py::test_batch_get_guide_point_list` | 是。必须保留批量请求结构，不能拿单请求日志直接替换。 |
| `GP-TRIP-ORDER-TIMEOUT` | 订单导航超时参数场景 | `error_code == 0`；点位非空；首点 `link_ids` 非空 | `test_guide_point.py::test_OrderRouteAPI_trip_req_timeout`；`test_kflower_guide_point.py` 同名 case | 条件可用。日志筛选必须保留超时/最大点数等影响输入；字段名需由 IDL 结构化提取，不应依赖位置参数。 |
| `GP-TRIP-ORDER-OPEN-CITY` | 特定开城城市、订单下车 POI | `error_code == 0`；点位非空 | `test_guide_point.py::test_OrderRouteAPI_trip_wujiaqv`；`test_kflower_guide_point.py` 同名 case | 条件可用。不能用任意 `trip + OrderRouteAPI` 日志；需匹配该城市/POI 或等价开城标记。 |
| `GP-TRIP-ORDER-RERANK-SOURCE` | 命中更优点 rerank 的目的地条件 | `error_code == 0`；点位非空；首点 `data_source == "didi_dropoff"` | `test_guide_point.py::test_commom_rerank_better_point` | 仅条件可用。`data_source` 是业务期望，最新样本必须也满足 rerank 前置条件；否则不能将失败判为回归。 |
| `GP-TRIP-ORDER-CROSSROAD-NONE` | 不跨路的起终点几何/道路条件 | `error_code == 0`；每个点 `extend_map.cross_lane_num == 0`；`cross_road_level == "no"` | `test_guide_point.py::test_OrderRouteAPI_no_crossload` | 仅条件可用。需要将道路几何条件作为样本标签；不能只按路由抽取。 |
| `GP-TRIP-ORDER-CROSSROAD-HIGH` | 高等级跨路的起终点几何/道路条件 | `error_code == 0`；跨车道数满足阈值；`cross_road_level == "high"` | `test_guide_point.py::test_OrderRouteAPI_crossload_high_06`、`test_OrderRouteAPI_crossload_high_01` | 仅条件可用。两个 case 共享“高等级跨路”验证意图，但道路等级/阈值不同，样本标签必须保留细分。 |
| `GP-TRIP-ORDER-CROSSROAD-LOW` | 低等级跨路的道路条件 | `error_code == 0`；存在低等级且跨车道数小于 3 的点 | `test_guide_point.py::test_OrderRouteAPI_crossload_low` | 仅条件可用。当前 case 中最终 `assertEqual` 被注释，属于断言偏弱，不能作为强回归结论。 |
| `GP-TRIP-ORDER-CROSSROAD-EMPTY` | 推荐点过远、绑路失败条件 | `error_code == 0`；各点 `extend_map` 为 `None` | `test_guide_point.py::test_OrderRouteAPI_crossload_none` | 不用于常规最新日志替换。该 case 当前被 skip，且依赖异常几何条件，应单独保留为异常/降级样本。 |
| `GP-TRIP-ORDER-AOI-SHOW` | 目的地命中 AOI 且 AOI 建议状态为展示 | `error_code == 0`；点位非空；`recommend_info.fence_list` 非空；围栏 ID/多边形满足预期 | `test_guide_point.py::test_route_broker_aoi_status_effective` 中 `caller_id=OrderRouteAPI` 的第一段请求 | 仅条件可用。必须从日志记录 AOI 状态和目的地 POI；不能因 case 名叫 route_broker 就误归类为 route-broker。 |
| `GP-TRIP-ORDER-AOI-HIDE` | 目的地命中 AOI 但 AOI 建议状态为不展示 | `error_code == 0`；点位非空；`recommend_info == "{}"` | `test_guide_point.py::test_route_broker_aoi_status_effective` 中第二段 `OrderRouteAPI` 请求 | 仅条件可用。与 AOI-SHOW 路由相同、response 期望相反，必须是两个场景。 |

## 合并与去重结果

1. `test_ai_guide_flow.py` 的单请求/批量请求分别保留：response 结构不同，不能去重。
2. 两个仓库文件中同名的超时、开城 case 被标为同一业务验证意图，但保留两个物理 `case_id`，后续运行时可按执行环境选择。
3. 跨路 case 不按同一路由粗暴合并：`no`、`high`、`low`、`empty` 的 `extend_map` 期望不同。
4. AOI 展示与不展示属于同一路由下相反的 response 预期，必须拆成两个验证子场景。
5. 没有可解析 response 断言的 case 只记录为“路由命中候选”，不进入可重跑验证场景；例如只构造请求、仅打印结果或断言已注释的 case。

## 用于基础设施的机器数据口径

这张 Markdown 表只是 mentor 审阅版。实际的 `unified_scene_catalog` 中，每行应存：

```text
scene_id
service / interface
route_selector(req_type, caller_id, matched_route_config)
request_fingerprint(城市、POI/坐标、产品、实验、end_request_tag 等)
response_assertions(path, operator, expected)
assertion_reusability(generic / conditionally_reusable / fixture_only)
case_refs
log_sample_selector
```

`GP-TRIP-ORDER-BASE-*` 可以使用相同路由的最新线上样本做通用验证；其余场景必须先满足各自的输入/数据条件，才允许替换 case 点位。

## 当前边界

- 该试点证明了“路由 + response”如何聚合，但还没有接入 HDFS、Jenkins 或自动替换 case 数据。
- 当前 case 中存在一方法多次调用 RPC 的写法；生产实现需要以 `request_index` 或 `trace_id` 把某个 response 断言精确绑定到某次请求。
- 坐标、POI、订单、手机号等样本数据进入 HDFS 前必须按公司规范脱敏；本表未复写这些原始值。
