"""Export Clearway's NetworkX pickle into a portable Flutter routing asset.

This is a development-time converter only. The generated application loads the
JSON asset directly and does not contain or execute Python.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path(
    os.environ.get("CLEARWAY_SOURCE_ROOT", r"C:\projects\_other\Clearway")
)


def encode_rule(rule: dict | None, rules: list, rule_ids: dict[str, int]) -> int:
    if rule is None:
        return -1
    windows = []
    for days, start, end in rule["windows"]:
        day_mask = 0x7F if days is None else sum(1 << int(day) for day in days)
        windows.append([day_mask, int(start), int(end)])
    encoded = [0 if rule["mode"] == "closed" else 1, windows]
    key = json.dumps(encoded, separators=(",", ":"))
    if key not in rule_ids:
        rule_ids[key] = len(rules)
        rules.append(encoded)
    return rule_ids[key]


def rounded_stats(summary: dict) -> dict:
    return {key: value for key, value in summary.items() if key != "geometry"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument(
        "--output",
        type=Path,
        default=PROJECT_ROOT / "assets" / "routing" / "helsingborg.graph.json",
    )
    parser.add_argument(
        "--goldens",
        type=Path,
        default=PROJECT_ROOT / "test" / "fixtures" / "routing_goldens.json",
    )
    args = parser.parse_args()

    backend = args.source / "backend"
    sys.path.insert(0, str(backend))
    from app.routing import cost, router, stats
    from app.routing.graph import load_graph

    graph_path = args.source / "data" / "graph.pkl"
    rg = load_graph(graph_path)

    node_ids = list(rg.node_x)
    node_index = {node_id: index for index, node_id in enumerate(node_ids)}
    nodes = []
    for node_id in node_ids:
        flags = (
            int(rg.is_signal[node_id])
            | (int(rg.is_stop[node_id]) << 1)
            | (int(rg.is_crossing[node_id]) << 2)
            | (int(rg.is_mini_rbt[node_id]) << 3)
        )
        nodes.append(
            [
                float(rg.node_x[node_id]),
                float(rg.node_y[node_id]),
                flags,
                int(rg.rule_component.get(node_id, -1)),
            ]
        )

    rules: list = []
    rule_ids: dict[str, int] = {}
    edges = []
    place_accumulator: dict[str, list] = {}
    edge_tuples = list(rg.G.edges(keys=True))
    for eid in range(rg.n_edges):
        u, v, key = edge_tuples[eid]
        raw_names = rg.G.edges[u, v, key].get("name")
        names = raw_names if isinstance(raw_names, list) else [raw_names]
        clean_names = [str(name).strip() for name in names if name]
        edge_name = " / ".join(dict.fromkeys(clean_names))
        flat_coords = [
            coordinate
            for point in rg.e_coords[eid]
            for coordinate in (float(point[0]), float(point[1]))
        ]
        edges.append(
            [
                node_index[rg.e_tail[eid]],
                node_index[rg.e_head[eid]],
                float(rg.e_tt[eid]),
                float(rg.e_len[eid]),
                int(rg.e_round[eid]),
                float(rg.e_dep_bearing[eid]),
                float(rg.e_arr_bearing[eid]),
                encode_rule(rg.e_rule[eid], rules, rule_ids),
                flat_coords,
                edge_name,
            ]
        )
        midpoint = rg.e_coords[eid][len(rg.e_coords[eid]) // 2]
        for raw_name in names:
            if not raw_name:
                continue
            name = str(raw_name).strip()
            normalized = name.casefold()
            if normalized not in place_accumulator:
                place_accumulator[normalized] = [name, 0.0, 0.0, 0]
            entry = place_accumulator[normalized]
            entry[1] += float(midpoint[1])
            entry[2] += float(midpoint[0])
            entry[3] += 1

    places = [
        [entry[0], entry[1] / entry[3], entry[2] / entry[3]]
        for entry in place_accumulator.values()
    ]
    places.sort(key=lambda item: item[0].casefold())

    xs = list(rg.node_x.values())
    ys = list(rg.node_y.values())
    payload = {
        "version": 1,
        "region": "Helsingborg",
        "max_speed_mps": float(rg.max_speed_mps),
        "bounds": [min(xs), min(ys), max(xs), max(ys)],
        "nodes": nodes,
        "rules": rules,
        "edges": edges,
        "places": places,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))

    cases = [
        {
            "name": "screenshot_early",
            "origin": [56.04905, 12.69044],
            "destination": [56.04525, 12.69394],
            "weekday": 1,
            "minute": 69,
        },
        {
            "name": "screenshot_noon_restrictions",
            "origin": [56.04905, 12.69044],
            "destination": [56.04525, 12.69394],
            "weekday": 1,
            "minute": 720,
        },
        {
            "name": "central_comparison",
            "origin": [56.04423, 12.69561],
            "destination": [56.05274, 12.70492],
            "weekday": 2,
            "minute": 600,
        },
        {
            "name": "cross_city",
            "origin": [56.03410, 12.70920],
            "destination": [56.06580, 12.70410],
            "weekday": 4,
            "minute": 1020,
        },
    ]
    golden_cases = []
    for case in cases:
        origin_node = rg.nearest_node(case["origin"][1], case["origin"][0])
        destination_node = rg.nearest_node(
            case["destination"][1], case["destination"][0]
        )
        result = {**case, "routes": {}}
        for profile in ("fastest", "clearway"):
            path = router.route(
                rg,
                origin_node,
                destination_node,
                cost.PROFILES[profile],
                now=(case["weekday"], case["minute"]),
            )
            if path is None:
                result["routes"][profile] = None
                continue
            summary = stats.summarize(
                rg, path, origin_node, destination_node
            )
            result["routes"][profile] = {
                "origin_node": node_index[origin_node],
                "destination_node": node_index[destination_node],
                "path": path,
                "stats": rounded_stats(summary),
            }
        golden_cases.append(result)

    args.goldens.parent.mkdir(parents=True, exist_ok=True)
    with args.goldens.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(
            {"graph_version": 1, "cases": golden_cases},
            handle,
            ensure_ascii=False,
            separators=(",", ":"),
        )

    print(
        f"Exported {len(nodes)} nodes, {len(edges)} edges, "
        f"{len(rules)} rules and {len(places)} streets to {args.output} "
        f"({args.output.stat().st_size:,} bytes)"
    )
    print(f"Wrote {len(golden_cases)} golden cases to {args.goldens}")


if __name__ == "__main__":
    main()
