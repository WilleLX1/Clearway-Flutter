"""Export Helsingborg OSM addresses and named POIs for offline autocomplete.

This development-time tool queries Overpass in small tiles, deduplicates the
results, and writes a compact JSON asset. The Flutter application never calls
Overpass at runtime.
"""
from __future__ import annotations

import argparse
import json
import ssl
import time
import unicodedata
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = (
    PROJECT_ROOT / "assets" / "search" / "helsingborg.places.json"
)
DEFAULT_CACHE = PROJECT_ROOT / ".dart_tool" / "place_export_cache"
DEFAULT_BOUNDS = (12.5907984, 55.9325679, 12.9859432, 56.2188639)
HELSINGBORG_RELATION_ID = 935_560
ENDPOINTS = (
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://lz4.overpass-api.de/api/interpreter",
)
POI_KEYS = ("shop", "amenity", "tourism", "office", "craft", "leisure", "healthcare")


def normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    ascii_like = "".join(
        character for character in decomposed if not unicodedata.combining(character)
    )
    return " ".join(
        "".join(character if character.isalnum() else " " for character in ascii_like).split()
    )


def title_category(value: str) -> str:
    aliases = {
        "supermarket": "Supermarket",
        "convenience": "Convenience store",
        "fast_food": "Fast food",
        "fuel": "Petrol station",
        "charging_station": "Charging station",
        "doctors": "Medical clinic",
        "dentist": "Dentist",
        "pharmacy": "Pharmacy",
        "place_of_worship": "Place of worship",
        "community_centre": "Community centre",
        "townhall": "Town hall",
    }
    return aliases.get(value, value.replace("_", " ").capitalize())


def coordinates(element: dict) -> tuple[float, float] | None:
    if element["type"] == "node":
        return float(element["lat"]), float(element["lon"])
    center = element.get("center")
    if center:
        return float(center["lat"]), float(center["lon"])
    return None


def query_for(bounds: tuple[float, float, float, float]) -> str:
    west, south, east, north = bounds
    bbox = f"{south},{west},{north},{east}"
    selections = [
        f'nwr["addr:housenumber"]({bbox});',
        *[
            f'nwr["name"]["{key}"]({bbox});'
            for key in POI_KEYS
        ],
    ]
    return (
        "[out:json][timeout:120];"
        f"({''.join(selections)});"
        "out center tags;"
    )


def fetch_boundary(cache_path: Path) -> dict:
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))
    query = urllib.parse.urlencode(
        {
            "osm_ids": f"R{HELSINGBORG_RELATION_ID}",
            "format": "json",
            "polygon_geojson": "1",
        }
    )
    request = urllib.request.Request(
        f"https://nominatim.openstreetmap.org/lookup?{query}",
        headers={"User-Agent": "Clearway-offline-index/1.0"},
    )
    context = ssl._create_unverified_context()
    with urllib.request.urlopen(
        request,
        timeout=60,
        context=context,
    ) as response:
        payload = json.load(response)
    if not payload:
        raise RuntimeError("Helsingborg municipality boundary was not found.")
    boundary = payload[0]["geojson"]
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(
        json.dumps(boundary, separators=(",", ":")),
        encoding="utf-8",
    )
    return boundary


def point_in_ring(lon: float, lat: float, ring: list[list[float]]) -> bool:
    inside = False
    previous = ring[-1]
    for current in ring:
        x1, y1 = previous
        x2, y2 = current
        crosses = (y1 > lat) != (y2 > lat)
        if crosses and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
            inside = not inside
        previous = current
    return inside


def inside_boundary(lat: float, lon: float, boundary: dict) -> bool:
    polygons = (
        [boundary["coordinates"]]
        if boundary["type"] == "Polygon"
        else boundary["coordinates"]
    )
    for polygon in polygons:
        if not point_in_ring(lon, lat, polygon[0]):
            continue
        if any(point_in_ring(lon, lat, hole) for hole in polygon[1:]):
            continue
        return True
    return False


def bounds_intersect_boundary(
    bounds: tuple[float, float, float, float],
    boundary: dict,
) -> bool:
    west, south, east, north = bounds
    samples = (
        (south, west),
        (south, east),
        (north, west),
        (north, east),
        ((south + north) / 2, (west + east) / 2),
    )
    if any(inside_boundary(lat, lon, boundary) for lat, lon in samples):
        return True
    polygons = (
        [boundary["coordinates"]]
        if boundary["type"] == "Polygon"
        else boundary["coordinates"]
    )
    return any(
        west <= lon <= east and south <= lat <= north
        for polygon in polygons
        for ring in polygon
        for lon, lat in ring
    )


def fetch_tile(
    bounds: tuple[float, float, float, float],
    tile_number: int | str,
    tile_count: int,
    cache_path: Path,
    boundary: dict,
    depth: int = 0,
) -> tuple[list[dict], str]:
    if not bounds_intersect_boundary(bounds, boundary):
        print(
            f"Tile {tile_number}/{tile_count}: outside municipality",
            flush=True,
        )
        return [], ""
    if cache_path.exists():
        payload = json.loads(cache_path.read_text(encoding="utf-8"))
        elements = payload.get("elements", [])
        timestamp = payload.get("osm3s", {}).get("timestamp_osm_base", "")
        print(
            f"Tile {tile_number}/{tile_count}: {len(elements):,} cached objects",
            flush=True,
        )
        return elements, timestamp
    query = query_for(bounds)
    encoded = urllib.parse.urlencode({"data": query})
    last_error: Exception | None = None
    for attempt in range(3):
        endpoint = ENDPOINTS[attempt % len(ENDPOINTS)]
        request = urllib.request.Request(
            f"{endpoint}?{encoded}",
            headers={
                "User-Agent": "Clearway-offline-index/1.0",
                "Accept": "application/json",
            },
        )
        try:
            # Some Windows Python distributions ship an outdated CA bundle.
            # This tool only downloads public OSM data and sends no credentials.
            context = ssl._create_unverified_context()
            with urllib.request.urlopen(
                request,
                timeout=150,
                context=context,
            ) as response:
                payload = json.load(response)
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_text(
                json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
            timestamp = payload.get("osm3s", {}).get("timestamp_osm_base", "")
            elements = payload.get("elements", [])
            print(
                f"Tile {tile_number}/{tile_count}: {len(elements):,} objects",
                flush=True,
            )
            return elements, timestamp
        except Exception as error:  # Network endpoints can be temporarily busy.
            last_error = error
            delay = min(30, 3 * (attempt + 1))
            print(
                f"Tile {tile_number}/{tile_count} attempt {attempt + 1} failed: "
                f"{error}; retrying in {delay}s",
                flush=True,
            )
            time.sleep(delay)
    if depth >= 2:
        raise RuntimeError(
            f"Could not download tile {tile_number}"
        ) from last_error

    print(
        f"Tile {tile_number}/{tile_count}: splitting into smaller queries",
        flush=True,
    )
    combined: dict[tuple[str, int], dict] = {}
    timestamps: list[str] = []
    for sub_index, sub_bounds in enumerate(tiles(bounds, 2, 2), start=1):
        sub_path = cache_path.with_name(
            f"{cache_path.stem}_part{sub_index}{cache_path.suffix}"
        )
        elements, timestamp = fetch_tile(
            sub_bounds,
            f"{tile_number}.{sub_index}",
            tile_count,
            sub_path,
            boundary,
            depth + 1,
        )
        timestamps.append(timestamp)
        for element in elements:
            combined[(element["type"], int(element["id"]))] = element
    payload = {
        "osm3s": {"timestamp_osm_base": max(timestamps, default="")},
        "elements": list(combined.values()),
    }
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    return payload["elements"], payload["osm3s"]["timestamp_osm_base"]


def tiles(
    bounds: tuple[float, float, float, float],
    columns: int,
    rows: int,
) -> list[tuple[float, float, float, float]]:
    west, south, east, north = bounds
    lon_step = (east - west) / columns
    lat_step = (north - south) / rows
    return [
        (
            west + column * lon_step,
            south + row * lat_step,
            west + (column + 1) * lon_step,
            south + (row + 1) * lat_step,
        )
        for row in range(rows)
        for column in range(columns)
    ]


@dataclass(frozen=True)
class Entry:
    kind: int
    primary: str
    secondary: str
    lat_e6: int
    lon_e6: int
    search: str

    def encoded(self) -> list:
        return [
            self.kind,
            self.primary,
            self.secondary,
            self.lat_e6,
            self.lon_e6,
            self.search,
        ]


def build_entries(elements: dict[tuple[str, int], dict]) -> list[Entry]:
    addresses: dict[tuple[str, str], Entry] = {}
    places: dict[tuple[str, int, int], Entry] = {}
    for element in elements.values():
        point = coordinates(element)
        if point is None:
            continue
        lat, lon = point
        tags = element.get("tags", {})
        street = str(tags.get("addr:street") or tags.get("addr:place") or "").strip()
        number = str(tags.get("addr:housenumber") or "").strip()
        postcode = str(tags.get("addr:postcode") or "").strip()
        city = str(tags.get("addr:city") or "Helsingborg").strip()
        address = f"{street} {number}".strip() if street and number else ""

        if address:
            secondary_parts = [value for value in (postcode, city) if value]
            secondary = " ".join(secondary_parts)
            search = normalize(f"{address} {postcode} {city}")
            key = (normalize(address), normalize(city))
            addresses.setdefault(
                key,
                Entry(
                    kind=0,
                    primary=address,
                    secondary=secondary,
                    lat_e6=round(lat * 1_000_000),
                    lon_e6=round(lon * 1_000_000),
                    search=search,
                ),
            )

        name = str(tags.get("name") or "").strip()
        category_key = next((key for key in POI_KEYS if tags.get(key)), "")
        category_value = str(tags.get(category_key) or "").strip()
        if not name or not category_value:
            continue
        category = title_category(
            category_key if category_value in {"yes", "true"} else category_value
        )
        locality = address or city
        secondary = f"{category} · {locality}" if locality else category
        extra_names = " ".join(
            str(tags.get(key) or "")
            for key in ("brand", "operator", "short_name", "alt_name")
        )
        search = normalize(
            f"{name} {extra_names} {category} {category_value} "
            f"{address} {postcode} {city}"
        )
        key = (normalize(name), round(lat * 100_000), round(lon * 100_000))
        places.setdefault(
            key,
            Entry(
                kind=1,
                primary=name,
                secondary=secondary,
                lat_e6=round(lat * 1_000_000),
                lon_e6=round(lon * 1_000_000),
                search=search,
            ),
        )

    return sorted(
        [*addresses.values(), *places.values()],
        key=lambda entry: (entry.kind, normalize(entry.primary), entry.lat_e6, entry.lon_e6),
    )


def prefix_index(entries: list[Entry]) -> dict[str, list[int]]:
    buckets: dict[str, list[int]] = {}
    for index, entry in enumerate(entries):
        prefixes = {
            word[:2]
            for word in entry.search.split()
            if len(word) >= 2 and not word.isdigit()
        }
        for prefix in prefixes:
            buckets.setdefault(prefix, []).append(index)
    return dict(sorted(buckets.items()))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE)
    args = parser.parse_args()

    tile_bounds = tiles(DEFAULT_BOUNDS, args.columns, args.rows)
    boundary = fetch_boundary(args.cache_dir / "helsingborg_boundary.json")
    objects: dict[tuple[str, int], dict] = {}
    timestamps: list[str] = []
    for index, bounds in enumerate(tile_bounds, start=1):
        cache_path = (
            args.cache_dir
            / f"tile_{args.columns}x{args.rows}_{index:02d}.json"
        )
        elements, timestamp = fetch_tile(
            bounds,
            index,
            len(tile_bounds),
            cache_path,
            boundary,
        )
        timestamps.append(timestamp)
        for element in elements:
            point = coordinates(element)
            if point is not None and inside_boundary(*point, boundary):
                objects[(element["type"], int(element["id"]))] = element

    entries = build_entries(objects)
    prefixes = prefix_index(entries)
    address_count = sum(entry.kind == 0 for entry in entries)
    place_count = sum(entry.kind == 1 for entry in entries)
    payload = {
        "v": 1,
        "source": "OpenStreetMap contributors",
        "timestamp": max(timestamps, default=""),
        "e": [entry.encoded() for entry in entries],
        "p": prefixes,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
    print(
        f"Wrote {address_count:,} addresses and {place_count:,} named places "
        f"to {args.output} ({args.output.stat().st_size:,} bytes)",
        flush=True,
    )


if __name__ == "__main__":
    main()
