from __future__ import annotations

import heapq
import math
import re
import sys
import uuid
from collections import defaultdict
from pathlib import Path


PCB = Path(
    r"D:\projects\GPR\Electronics-Competition\kicad\ProPrj_研电赛优利德显示屏与旋转编码器_2026-06-08.kicad_pcb"
)

STEP = 0.5
MIN_X, MAX_X = 2.0, 73.0
MIN_Y, MAX_Y = 2.0, 43.0
F_CU, B_CU = 0, 1


def uid() -> str:
    return str(uuid.uuid4())


def q(v: float) -> int:
    return round(v / STEP)


def uq(v: int) -> float:
    return round(v * STEP, 4)


def fmt(v: float) -> str:
    if abs(v - round(v)) < 1e-9:
        return str(int(round(v)))
    return f"{v:.4f}".rstrip("0").rstrip(".")


def block_at(text: str, start: int) -> tuple[int, int, str]:
    depth = 0
    for i in range(start, len(text)):
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return start, i + 1, text[start : i + 1]
    raise ValueError(f"unclosed block at {start}")


def iter_blocks(text: str, token: str):
    i = 0
    needle = f"({token}"
    while True:
        i = text.find(needle, i)
        if i < 0:
            return
        start, end, block = block_at(text, i)
        yield start, end, block
        i = end


def parse_at(block: str) -> tuple[float, float, float]:
    m = re.search(r"\(at\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)(?:\s+(-?\d+(?:\.\d+)?))?", block)
    if not m:
        return 0.0, 0.0, 0.0
    return float(m.group(1)), float(m.group(2)), float(m.group(3) or 0.0)


def rotate(x: float, y: float, deg: float) -> tuple[float, float]:
    rad = math.radians(deg)
    c, s = math.cos(rad), math.sin(rad)
    return x * c - y * s, x * s + y * c


def parse_board(text: str):
    pads = []
    for _, _, fp in iter_blocks(text, "footprint"):
        fpx, fpy, fpr = parse_at(fp)
        ref = re.search(r'\(property\s+"Reference"\s+"([^"]+)"', fp)
        ref = ref.group(1) if ref else "?"
        for _, _, pad in iter_blocks(fp, "pad"):
            pm = re.match(r'\(pad\s+"([^"]+)"\s+(\S+)', pad.strip())
            if not pm:
                continue
            pin, pad_type = pm.group(1), pm.group(2)
            net = re.search(r'\(net\s+(\d+)\s+"([^"]*)"\)', pad)
            if not net or int(net.group(1)) == 0:
                continue
            layers = []
            if '"*.Cu"' in pad or pad_type == "thru_hole":
                layers = [F_CU, B_CU]
            else:
                if '"F.Cu"' in pad:
                    layers.append(F_CU)
                if '"B.Cu"' in pad:
                    layers.append(B_CU)
            if not layers:
                continue
            px, py, _ = parse_at(pad)
            sx = sy = 1.0
            sm = re.search(r"\(size\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\)", pad)
            if sm:
                sx, sy = float(sm.group(1)), float(sm.group(2))
            rx, ry = rotate(px, py, fpr)
            pads.append(
                {
                    "ref": ref,
                    "pin": pin,
                    "x": fpx + rx,
                    "y": fpy + ry,
                    "layers": layers,
                    "net": int(net.group(1)),
                    "name": net.group(2),
                    "radius": max(sx, sy) / 2.0 + 0.35,
                    "pth": pad_type == "thru_hole",
                }
            )
    return pads


def key(ix: int, iy: int, layer: int) -> tuple[int, int, int]:
    return ix, iy, layer


def route_board(text: str):
    text = re.sub(r"\n\t\(segment [^\n]+\)", "", text)
    text = re.sub(r"\n\t\(via [^\n]+\)", "", text)

    pads = parse_board(text)
    by_net = defaultdict(list)
    for pad in pads:
        by_net[pad["net"]].append(pad)

    pad_occ = []
    for pad in pads:
        r = pad["radius"]
        for ix in range(q(pad["x"] - r), q(pad["x"] + r) + 1):
            for iy in range(q(pad["y"] - r), q(pad["y"] + r) + 1):
                x, y = uq(ix), uq(iy)
                if (x - pad["x"]) ** 2 + (y - pad["y"]) ** 2 <= r * r:
                    for layer in pad["layers"]:
                        pad_occ.append((ix, iy, layer, pad["net"]))

    occupied: dict[tuple[int, int, int], int] = {}

    def mark(ix: int, iy: int, layer: int, net: int, halo: int = 1):
        for dx in range(-halo, halo + 1):
            for dy in range(-halo, halo + 1):
                occupied[(ix + dx, iy + dy, layer)] = net

    def blocked(ix: int, iy: int, layer: int, net: int) -> bool:
        x, y = uq(ix), uq(iy)
        if x < MIN_X or x > MAX_X or y < MIN_Y or y > MAX_Y:
            return True
        for ox, oy, ol, onet in pad_occ:
            if ox == ix and oy == iy and ol == layer and onet != net:
                return True
        onet = occupied.get((ix, iy, layer))
        return onet is not None and onet != net

    def snap_cells(pad) -> list[tuple[int, int, int]]:
        return [(q(pad["x"]), q(pad["y"]), layer) for layer in pad["layers"]]

    def heuristic(ix: int, iy: int, targets: list[tuple[int, int, int]]) -> int:
        return min(abs(ix - tx) + abs(iy - ty) for tx, ty, _ in targets)

    def astar(net: int, starts, target_set):
        target_list = list(target_set)
        heap = []
        best = {}
        prev = {}
        for start in starts:
            if blocked(*start, net):
                continue
            best[start] = 0
            heapq.heappush(heap, (heuristic(start[0], start[1], target_list), 0, start))
        iterations = 0
        while heap and iterations < 300000:
            iterations += 1
            _, cost, cur = heapq.heappop(heap)
            if cost != best.get(cur):
                continue
            if cur in target_set:
                path = []
                k = cur
                while k is not None:
                    path.append(k)
                    k = prev.get(k)
                path.reverse()
                return path
            ix, iy, layer = cur
            for nx, ny, nl, step_cost in (
                (ix + 1, iy, layer, 1),
                (ix - 1, iy, layer, 1),
                (ix, iy + 1, layer, 1),
                (ix, iy - 1, layer, 1),
                (ix, iy, 1 - layer, 12),
            ):
                nxt = (nx, ny, nl)
                if blocked(nx, ny, nl, net):
                    continue
                new_cost = cost + step_cost
                if new_cost < best.get(nxt, 10**9):
                    best[nxt] = new_cost
                    prev[nxt] = cur
                    heapq.heappush(
                        heap,
                        (
                            new_cost + heuristic(nx, ny, target_list),
                            new_cost,
                            nxt,
                        ),
                    )
        return None

    segments = []
    vias = []
    failures = []

    def net_priority(item):
        net, terms = item
        name = terms[0]["name"]
        if name in ("GND", "VCC"):
            return 1000 if name == "GND" else 900
        return len(terms)

    for net, terms in sorted(by_net.items(), key=net_priority):
        if len(terms) < 2:
            continue
        # Start from the left-most terminal, usually H3, to make branches fan out.
        terms = sorted(terms, key=lambda p: (p["x"], p["y"]))
        tree = set(snap_cells(terms[0]))
        for ix, iy, layer in tree:
            mark(ix, iy, layer, net, halo=0)
        for term in terms[1:]:
            starts = snap_cells(term)
            path = astar(net, starts, tree)
            if not path:
                failures.append((net, term["name"], term["ref"], term["pin"]))
                continue
            tree.update(path)
            # Convert path into collinear runs and vias.
            run_start = path[0]
            prev = path[0]
            prev_dir = None
            for cur in path[1:]:
                if cur[2] != prev[2]:
                    if run_start != prev:
                        segments.append((run_start, prev, net))
                    vias.append((prev[0], prev[1], net))
                    mark(prev[0], prev[1], F_CU, net, halo=1)
                    mark(prev[0], prev[1], B_CU, net, halo=1)
                    run_start = cur
                    prev = cur
                    prev_dir = None
                    continue
                direction = (cur[0] - prev[0], cur[1] - prev[1], cur[2])
                if prev_dir is not None and direction != prev_dir:
                    segments.append((run_start, prev, net))
                    run_start = prev
                prev_dir = direction
                prev = cur
            if run_start != prev:
                segments.append((run_start, prev, net))
            for ix, iy, layer in path:
                mark(ix, iy, layer, net, halo=1)

    def segment_text(seg) -> str:
        start, end, net = seg
        layer = "F.Cu" if start[2] == F_CU else "B.Cu"
        return (
            f'\n\t(segment (start {fmt(uq(start[0]))} {fmt(uq(start[1]))}) '
            f'(end {fmt(uq(end[0]))} {fmt(uq(end[1]))}) (width 0.25) '
            f'(layer "{layer}") (net {net}) (uuid "{uid()}"))'
        )

    def via_text(via) -> str:
        ix, iy, net = via
        return (
            f'\n\t(via (at {fmt(uq(ix))} {fmt(uq(iy))}) (size 0.8) (drill 0.4) '
            f'(layers "F.Cu" "B.Cu") (net {net}) (uuid "{uid()}"))'
        )

    route_text = "".join(segment_text(seg) for seg in segments)
    route_text += "".join(via_text(via) for via in vias)
    text = re.sub(r"\n\)\s*$", route_text + "\n)\n", text)
    return text, {
        "pads": len(pads),
        "nets": len(by_net),
        "segments": len(segments),
        "vias": len(vias),
        "failures": failures,
    }


def main() -> int:
    text = PCB.read_text(encoding="utf-8")
    routed, stats = route_board(text)
    PCB.write_text(routed, encoding="utf-8")
    print(stats)
    return 0 if not stats["failures"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
