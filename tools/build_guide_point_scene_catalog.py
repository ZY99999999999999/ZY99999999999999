#!/usr/bin/env python3
"""Build a scene-primary, redacted review catalog from guide point cases.

The generated catalog deliberately does not use CV IDs as scene IDs.  A scene
is keyed by resolved route, request fingerprint and the complete normalized
response assertion set.  This makes a different expected response a different
scene even if the request route is identical.
"""

from __future__ import annotations

import ast
import hashlib
import json
import re
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


REPO = Path(__file__).resolve().parents[1]
CASE_ROOT = Path(
    "/Users/didi/Documents/Codex/2026-08-13/1-ai-req-type-caller-id/work/repos/ModulesCaseNew/cases/guide_point_new"
)
ROUTE_CATALOG = REPO / "docs/guide-point-flow-static-scene-catalog.md"
OUT_JSONL = REPO / "outputs/guide-point-flow-scene-primary-catalog.jsonl"
OUT_MD = REPO / "docs/guide-point-flow-scene-primary-catalog.md"

RPC_METHODS = {
    "GetGuidePointList",
    "BatchGetGuidePointList",
    "GetGeoGP",
    "BatchGetGeoGP",
}
REQUEST_CTORS = {
    "GuidePointRequest",
    "BatchGuidePointRequest",
    "GeoGPReq",
    "BatchGeoGPReq",
}
HINT_NAMES = {
    "cityid",
    "city_id",
    "req_timeout",
    "end_request_tag",
    "origin_caller_id",
    "engine_type",
    "product_id",
    "m_type",
}
ENUM_VALUES = {
    "OK",
    "no",
    "low",
    "high",
    "didi_dropoff",
    "dropoff_castle",
    "off_tollgate",
    "guide_point",
    "lib_island",
    "castle",
    "multiple",
    "unreach",
    "map_api",
    "mapapi",
    "OrderRouteAPI",
    "route-broker",
    "dolphin_api",
}


def sha(value: str, size: int = 10) -> str:
    return hashlib.sha256(value.encode()).hexdigest()[:size]


def node_text(node: ast.AST | None, env: dict[str, str], depth: int = 0) -> str:
    if node is None:
        return "None"
    if depth > 8:
        return ast.unparse(node)
    if isinstance(node, ast.Constant):
        return repr(node.value)
    if isinstance(node, ast.Name):
        return env.get(node.id, node.id)
    if isinstance(node, ast.Attribute):
        return f"{node_text(node.value, env, depth + 1)}.{node.attr}"
    if isinstance(node, ast.Subscript):
        return f"{node_text(node.value, env, depth + 1)}[{node_text(node.slice, env, depth + 1)}]"
    if isinstance(node, ast.UnaryOp):
        return ast.unparse(node)
    if isinstance(node, (ast.List, ast.Tuple, ast.Set)):
        return "[" + ", ".join(node_text(x, env, depth + 1) for x in node.elts[:4]) + "]"
    if isinstance(node, ast.Dict):
        return "{" + ", ".join(
            f"{node_text(k, env, depth + 1)}:{node_text(v, env, depth + 1)}"
            for k, v in list(zip(node.keys, node.values))[:4]
        ) + "}"
    return ast.unparse(node)


def literal(value: str) -> str:
    """Unquote scalar text only when it is an obvious literal."""
    if len(value) >= 2 and value[0] in "'\"" and value[-1] == value[0]:
        return value[1:-1]
    return value


def redacted(value: str) -> str:
    """Keep business enums but remove IDs, coordinates and personal-like literals."""
    def quote(match: re.Match[str]) -> str:
        raw = match.group(2)
        if (
            raw in ENUM_VALUES
            or raw in {"{}", "[]", ""}
            or (len(raw) <= 24 and re.fullmatch(r"[A-Za-z_]+", raw))
        ):
            return match.group(1) + raw + match.group(1)
        return f"<str:{sha(raw, 8)}>"

    value = re.sub(r"(['\"])(.*?)\1", quote, value)
    value = re.sub(r"(?<![\w.])-?\d{2,3}\.\d{4,}(?!\w)", lambda m: f"<coord:{sha(m.group(0), 8)}>", value)
    value = re.sub(r"(?<![\w.])\d{8,}(?!\w)", lambda m: f"<id:{sha(m.group(0), 8)}>", value)
    return re.sub(r"\s+", " ", value).strip()


def names_in(node: ast.AST) -> list[str]:
    """Return names in lexical AST order, not set order.

    Some assertions compare two responses (`res` and `res1`).  Set iteration
    made the prior extraction pick a response nondeterministically across
    Python processes, which in turn made scene IDs unstable.
    """
    seen: set[str] = set()
    ordered: list[str] = []
    for item in ast.walk(node):
        if isinstance(item, ast.Name) and item.id not in seen:
            seen.add(item.id)
            ordered.append(item.id)
    return ordered


def response_paths(node: ast.AST, aliases: dict[str, str]) -> list[str]:
    paths: set[str] = set()
    for item in ast.walk(node):
        if not isinstance(item, ast.Attribute):
            continue
        parts: list[str] = []
        cur: ast.AST = item
        while isinstance(cur, ast.Attribute):
            parts.append(cur.attr)
            cur = cur.value
        if isinstance(cur, ast.Name) and cur.id in aliases:
            paths.add(".".join([aliases[cur.id], *reversed(parts)]))
    return sorted(paths)


def parse_routes() -> dict[tuple[str, str], str]:
    routes: dict[tuple[str, str], str] = {}
    pattern = re.compile(r"`guide-point-flow-v2:([^:`]+):([^`]+)`")
    for req_type, caller_id in pattern.findall(ROUTE_CATALOG.read_text()):
        routes[(req_type, caller_id)] = f"{req_type}:{caller_id}"
    return routes


def resolve_route(req_type: str, caller_id: str, routes: dict[tuple[str, str], str]) -> tuple[str, str]:
    known_req_types = {item[0] for item in routes}
    if (
        req_type in {"?", "", "None"}
        or "[" in req_type
        or "." in req_type
        or req_type not in known_req_types
    ):
        return f"unresolved:{req_type}:{caller_id or '*'}", "unresolved"
    caller = caller_id or "*"
    if (req_type, caller) in routes:
        return routes[(req_type, caller)], "exact"
    if (req_type, "*") in routes:
        return routes[(req_type, "*")], "req_type_default"
    if ("*", "*") in routes:
        return routes[("*", "*")], "root_fallback"
    return f"unresolved:{req_type}:{caller}", "unresolved"


@dataclass
class RequestInfo:
    req_type: str = "?"
    caller_id: str = "?"
    shape: str = "single"
    hints: dict[str, str] = field(default_factory=dict)


@dataclass
class CallInfo:
    response_var: str
    method: str
    request: RequestInfo
    line: int
    assertions: list[str] = field(default_factory=list)
    response_fields: set[str] = field(default_factory=set)
    aliases: set[str] = field(default_factory=set)


class FunctionScanner:
    def __init__(self, source: Path, function: ast.FunctionDef):
        self.source = source
        self.function = function
        self.env: dict[str, str] = {}
        self.requests: dict[str, RequestInfo] = {}
        self.calls: list[CallInfo] = []
        self.aliases: dict[str, str] = {}
        self.skipped = any(self._decorator_skip(x) for x in function.decorator_list)

    @staticmethod
    def _decorator_skip(node: ast.AST) -> bool:
        text = ast.unparse(node).replace('"', "'").lower()
        # unittest.skipUnless(globalVar.g_case_level >= 0, ...) is the normal
        # enablement mechanism in this repository, not a disabled case.
        return (
            ".skip(" in text
            or ".skipif(true" in text
            or ".skipunless(false" in text
            or "== 'skip'" in text
        )

    def hints(self) -> dict[str, str]:
        return {
            name: literal(value)
            for name, value in self.env.items()
            if name in HINT_NAMES and value not in {"None", "?"}
        }

    def request_from_call(self, call: ast.Call) -> RequestInfo | None:
        if not isinstance(call.func, ast.Name) or call.func.id not in REQUEST_CTORS:
            return None
        ctor = call.func.id
        args = call.args
        if ctor == "GuidePointRequest":
            req = node_text(args[17], self.env) if len(args) > 17 else "?"
            caller = node_text(args[19], self.env) if len(args) > 19 else "?"
            city = node_text(args[13], self.env) if len(args) > 13 else "?"
            hints = self.hints()
            if city != "?":
                hints["city_id"] = literal(city)
            for keyword in call.keywords:
                if keyword.arg in HINT_NAMES:
                    hints[keyword.arg] = literal(node_text(keyword.value, self.env))
            return RequestInfo(literal(req), literal(caller), "single", hints)
        if ctor == "BatchGuidePointRequest":
            req = node_text(args[1], self.env) if len(args) > 1 else "?"
            caller = node_text(args[3], self.env) if len(args) > 3 else "?"
            return RequestInfo(literal(req), literal(caller), "batch", self.hints())
        if ctor == "GeoGPReq":
            req = node_text(args[1], self.env) if len(args) > 1 else "?"
            caller = node_text(args[2], self.env) if len(args) > 2 else "?"
            return RequestInfo(literal(req), literal(caller), "single", self.hints())
        if ctor == "BatchGeoGPReq":
            req = node_text(args[1], self.env) if len(args) > 1 else "?"
            caller = node_text(args[2], self.env) if len(args) > 2 else "?"
            return RequestInfo(literal(req), literal(caller), "batch", self.hints())
        return None

    def assignment(self, stmt: ast.Assign | ast.AnnAssign) -> None:
        value = stmt.value
        if value is None:
            return
        targets = stmt.targets if isinstance(stmt, ast.Assign) else [stmt.target]
        names = [x.id for x in targets if isinstance(x, ast.Name)]
        if not names:
            return
        request = self.request_from_call(value) if isinstance(value, ast.Call) else None
        for name in names:
            self.env[name] = node_text(value, self.env)
            if request:
                self.requests[name] = request
        if isinstance(value, ast.Call) and isinstance(value.func, ast.Attribute) and value.func.attr in RPC_METHODS:
            method = value.func.attr
            req = RequestInfo()
            if value.args:
                argument = value.args[0]
                if isinstance(argument, ast.Name) and argument.id in self.requests:
                    req = self.requests[argument.id]
                else:
                    parsed = self.request_from_call(argument) if isinstance(argument, ast.Call) else None
                    if parsed:
                        req = parsed
            for name in names:
                call = CallInfo(name, method, req, stmt.lineno, aliases={name})
                self.calls.append(call)
                self.aliases[name] = name

    def latest_call_for(self, node: ast.AST) -> CallInfo | None:
        used = names_in(node)
        candidates: list[str] = []
        for name in used:
            if name in self.aliases:
                candidates.append(self.aliases[name])
        for response_var in reversed(candidates):
            for call in reversed(self.calls):
                if call.response_var == response_var:
                    return call
        return None

    def assertion(self, call: ast.Call) -> None:
        if not isinstance(call.func, ast.Attribute):
            return
        if not (call.func.attr.startswith("assert") or call.func.attr == "checkResponseErrno"):
            return
        target = self.latest_call_for(call)
        if not target:
            return
        raw = ast.unparse(call)
        target.assertions.append(raw)
        target.response_fields.update(response_paths(call, self.aliases))

    def alias_from_iter(self, target: ast.AST, iterable: ast.AST) -> None:
        if not isinstance(target, ast.Name):
            return
        call = self.latest_call_for(iterable)
        if call:
            self.aliases[target.id] = call.response_var
            call.aliases.add(target.id)

    def walk_block(self, statements: list[ast.stmt]) -> None:
        for stmt in statements:
            if isinstance(stmt, (ast.Assign, ast.AnnAssign)):
                self.assignment(stmt)
            elif isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Call):
                self.assertion(stmt.value)
            elif isinstance(stmt, ast.For):
                self.alias_from_iter(stmt.target, stmt.iter)
                self.walk_block(stmt.body)
                self.walk_block(stmt.orelse)
            elif isinstance(stmt, ast.If):
                self.walk_block(stmt.body)
                self.walk_block(stmt.orelse)
            elif isinstance(stmt, (ast.With, ast.AsyncWith)):
                self.walk_block(stmt.body)
            elif isinstance(stmt, ast.Try):
                self.walk_block(stmt.body)
                self.walk_block(stmt.orelse)
                self.walk_block(stmt.finalbody)
                for handler in stmt.handlers:
                    self.walk_block(handler.body)

    def scan(self) -> list[CallInfo]:
        self.walk_block(self.function.body)
        return self.calls


def reusability(assertions: list[str], status: str) -> str:
    if status != "verified":
        return status
    joined = "\n".join(assertions)
    if re.search(r"\d{8,}|\d{2,3}\.\d{4,}", joined):
        return "fixture_only"
    if any(value in joined for value in ENUM_VALUES - {"OK"}):
        return "conditionally_reusable"
    return "generic_reusable"


def scene_status(call: CallInfo, skipped: bool) -> str:
    if not call.assertions:
        return "no_response_assertion"
    if skipped:
        return "skipped_case"
    return "verified"


def build() -> list[dict[str, Any]]:
    routes = parse_routes()
    by_key: dict[str, dict[str, Any]] = {}
    test_files = sorted(CASE_ROOT.glob("test_*.py"))
    for path in test_files:
        tree = ast.parse(path.read_text(), filename=str(path))
        for cls in [x for x in tree.body if isinstance(x, ast.ClassDef)]:
            for func in [x for x in cls.body if isinstance(x, ast.FunctionDef) and x.name.startswith("test_")]:
                scanner = FunctionScanner(path, func)
                for call in scanner.scan():
                    req_type = call.request.req_type
                    caller_id = call.request.caller_id
                    route, route_confidence = resolve_route(req_type, caller_id, routes)
                    status = scene_status(call, scanner.skipped)
                    normalized = sorted(redacted(x) for x in call.assertions)
                    raw_signature = "\n".join(sorted(call.assertions)) or "<no_response_assertion>"
                    fingerprint = {
                        "shape": call.request.shape,
                        **{key: redacted(str(value)) for key, value in sorted(call.request.hints.items())},
                    }
                    key_data = {
                        "route": route,
                        "method": call.method,
                        "request": fingerprint,
                        "assertions": raw_signature,
                        "status": status,
                    }
                    key = json.dumps(key_data, ensure_ascii=False, sort_keys=True)
                    scene_id = f"GPS-{sha(key, 12).upper()}"
                    name_route = re.sub(r"[^A-Za-z0-9]+", "_", route).strip("_").upper()
                    scene_name = f"{name_route}__{call.method.upper()}__{func.name.upper()}__{sha(raw_signature, 6).upper()}"
                    reference = f"{path.name}::{cls.name}::{func.name}@L{call.line}"
                    if scene_id not in by_key:
                        by_key[scene_id] = {
                            "scene_id": scene_id,
                            "scene_name": scene_name,
                            "service": "guide-point-flow-v2",
                            "interface": call.method,
                            "route_selector": route,
                            "route_match_confidence": route_confidence,
                            "request_fingerprint": fingerprint,
                            "response_assertions": normalized,
                            "response_fields": sorted(call.response_fields),
                            "assertion_reusability": reusability(call.assertions, status),
                            "status": status,
                            "case_refs": [],
                        }
                    by_key[scene_id]["case_refs"].append(reference)
    return sorted(by_key.values(), key=lambda row: (row["route_selector"], row["interface"], row["scene_id"]))


def compact_assertions(assertions: list[str]) -> str:
    if not assertions:
        return "—"
    text = "<br>".join(f"`{item}`" for item in assertions)
    return text if len(text) <= 520 else text[:517] + "…"


def write_outputs(scenes: list[dict[str, Any]]) -> None:
    OUT_JSONL.parent.mkdir(exist_ok=True)
    with OUT_JSONL.open("w") as handle:
        for scene in scenes:
            handle.write(json.dumps(scene, ensure_ascii=False, sort_keys=True) + "\n")

    totals = defaultdict(int)
    route_totals = defaultdict(int)
    for scene in scenes:
        totals[scene["status"]] += 1
        route_totals[scene["route_match_confidence"]] += 1
    raw_call_count = sum(len(scene["case_refs"]) for scene in scenes)
    rows = [
        "# guide-point-flow 场景主键目录（全量自动化 case 版）",
        "",
        "## 场景主键规则",
        "",
        "本文件以 `scene_id` 为主键，**不再使用 `CV-xxx` 作为场景 ID**。",
        "",
        "```text",
        "scene_id = hash(最终路由 + 接口 + 请求指纹 + 完整 response 断言 + 状态)",
        "```",
        "",
        "因此，同一路由中 `response` 的字段、操作符或期望值不同，都会成为不同的 `scene_id`。",
        "例如：`data_source == didi_dropoff` 与 `data_source == dropoff_castle`、AOI 展示与 `recommend_info == {}`、跨路 `high` 与 `no`，均不会合并。",
        "",
        "## 统计",
        "",
        f"- 静态扫描到的 RPC 调用：**{raw_call_count}** 次",
        f"- 场景主键数：**{len(scenes)}**",
        f"- 有 response 断言：**{totals['verified']}**",
        f"- 跳过 case：**{totals['skipped_case']}**",
        f"- 无 response 断言：**{totals['no_response_assertion']}**",
        f"- 路由精确命中：**{route_totals['exact']}**；req_type 默认命中：**{route_totals['req_type_default']}**；动态参数待解析：**{route_totals['unresolved']}**",
        "- 原始机器数据：`outputs/guide-point-flow-scene-primary-catalog.jsonl`",
        "",
        "## 全量场景明细",
        "",
        "`请求指纹`只输出可用于筛日志的非敏感条件；长数字 ID、精确坐标等已脱敏为哈希。原始断言可由 case 引用回查。",
        "",
        "| 场景主键 | 场景名称 | 最终路由 | 路由解析 | 接口 | 请求指纹 | response 断言（不同即不同场景） | 可复用性 | 状态 | case 证据 |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for scene in scenes:
        request = "<br>".join(f"`{k}={v}`" for k, v in scene["request_fingerprint"].items())
        cases = "<br>".join(f"`{case}`" for case in scene["case_refs"])
        rows.append(
            "| {id} | `{name}` | `{route}` | `{confidence}` | `{interface}` | {request} | {assertions} | `{reuse}` | `{status}` | {cases} |".format(
                id=scene["scene_id"],
                name=scene["scene_name"],
                route=scene["route_selector"],
                confidence=scene["route_match_confidence"],
                interface=scene["interface"],
                request=request or "—",
                assertions=compact_assertions(scene["response_assertions"]),
                reuse=scene["assertion_reusability"],
                status=scene["status"],
                cases=cases,
            )
        )
    rows.extend(
        [
            "",
            "## 自动重跑准入",
            "",
            "仅 `status=verified`、路由解析不是 `unresolved`，且 `assertion_reusability` 为 `generic_reusable` 或 `conditionally_reusable` 的场景可进入失败 case 重跑。",
            "`fixture_only`、`skipped_case`、`no_response_assertion` 和 `unresolved` 路由只能保留为覆盖证据或待改造 case，不能直接用线上日志替换。",
        ]
    )
    OUT_MD.write_text("\n".join(rows) + "\n")


if __name__ == "__main__":
    catalog = build()
    write_outputs(catalog)
    print(f"generated {len(catalog)} scene-primary records")
