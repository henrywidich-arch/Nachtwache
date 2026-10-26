// Builds data/appenweier.json for the third map (AppenweierMap) from OpenStreetMap data.
//   node tools/make_appenweier.js <appenweier_local.json>
// The input is the OSM extract around Sander Straße 13a in local metres (x east, z south,
// origin the middle of 13a; made with the Overpass API). This script turns it so that 13a
// stands square to the axes of the game (the street then runs nearly along x), cuts it to
// the playable area, keeps only what the map builds and gives every real business a
// made-up name. OSM data: (c) OpenStreetMap contributors, ODbL.
const fs = require("fs");
const path = require("path");

const source = process.argv[2];
if (!source) {
	console.error("usage: node tools/make_appenweier.js <appenweier_local.json>");
	process.exit(1);
}
const osm = JSON.parse(fs.readFileSync(source, "utf8"));

// The long side of 13a runs at 19.25 degrees to east: turned back by that much.
const TURN = Math.atan2(6.6, 18.9);
const C = Math.cos(TURN), S = Math.sin(TURN);
const turn = ([x, z]) => [Math.round((x * C + z * S) * 10) / 10, Math.round((-x * S + z * C) * 10) / 10];
// The playable area in the turned frame (metres).
const BOUNDS = { x0: -95, z0: -55, x1: 300, z1: 125 };

// Real names on the map get names of their own (nothing here is a real business).
const RENAME = [
	[/Bergheimer/i, "Brettner Torbau"],
	[/EDEKA|Decker/i, "Frischmarkt Krone"],
	[/^dm$|drogerie/i, "Drogerie Hellwig"],
	[/Vollmer|Gärtnerei/i, "Gärtnerei Lindenhof"],
	[/ASB|Samariter|Rettungswache/i, "Rettungswache"],
	[/Feuerwehr/i, "Feuerwehr"],
	[/Immergrün/i, "Café Mondschein"],
	[/Autowelt/i, "Autohaus Rheinblick"],
	[/Gmeiner|Confiserie/i, "Confiserie Zuckerstube"],
	[/Gerdes|Bäckerei/i, "Bäckerei Morgenrot"],
];
function rename(name) {
	if (!name) return "";
	for (const [pattern, made_up] of RENAME) if (pattern.test(name)) return made_up;
	return "";
}

const inside = ([x, z], grow = 0) => x >= BOUNDS.x0 - grow && x <= BOUNDS.x1 + grow && z >= BOUNDS.z0 - grow && z <= BOUNDS.z1 + grow;

// Sutherland-Hodgman against the bounds rectangle.
function clipPolygon(points) {
	let out = points;
	const edges = [
		[(p) => p[0] >= BOUNDS.x0, (a, b) => cut(a, b, 0, BOUNDS.x0)],
		[(p) => p[0] <= BOUNDS.x1, (a, b) => cut(a, b, 0, BOUNDS.x1)],
		[(p) => p[1] >= BOUNDS.z0, (a, b) => cut(a, b, 1, BOUNDS.z0)],
		[(p) => p[1] <= BOUNDS.z1, (a, b) => cut(a, b, 1, BOUNDS.z1)],
	];
	for (const [keep, cross] of edges) {
		const next = [];
		for (let i = 0; i < out.length; i++) {
			const a = out[i], b = out[(i + 1) % out.length];
			if (keep(a)) {
				next.push(a);
				if (!keep(b)) next.push(cross(a, b));
			} else if (keep(b)) next.push(cross(a, b));
		}
		out = next;
		if (out.length < 3) return [];
	}
	return out.map(([x, z]) => [Math.round(x * 10) / 10, Math.round(z * 10) / 10]);
}
function cut(a, b, axis, value) {
	const t = (value - a[axis]) / (b[axis] - a[axis]);
	return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
}
// A line cut into the runs of it that lie inside (a little beyond the edge, so that roads
// reach the limits of the map).
function clipLine(points) {
	const runs = [];
	let run = [];
	for (let i = 0; i < points.length; i++) {
		const p = points[i];
		if (inside(p, 8)) {
			if (run.length === 0 && i > 0) run.push(points[i - 1]);
			run.push(p);
		} else if (run.length > 0) {
			run.push(p);
			runs.push(run);
			run = [];
		}
	}
	if (run.length > 1) runs.push(run);
	return runs;
}
function unclose(points) {
	const n = points.length;
	if (n > 1 && points[0][0] === points[n - 1][0] && points[0][1] === points[n - 1][1]) return points.slice(0, n - 1);
	return points;
}

const out = { note: "Map data (c) OpenStreetMap contributors, ODbL. Turned and cut by tools/make_appenweier.js.", bounds: [BOUNDS.x0, BOUNDS.z0, BOUNDS.x1 - BOUNDS.x0, BOUNDS.z1 - BOUNDS.z0], roads: [], buildings: [], areas: [], walls: [], trees: [], lamps: [], rails: [] };

for (const road of osm.roads) {
	if (["path", "footway"].includes(road.type) && !road.name) {
		// Footpaths are kept narrow; they are drawn as paving.
	}
	for (const run of clipLine(road.points.map(turn))) {
		out.roads.push({ name: road.name || "", type: road.type, width: road.width_guess || 4, ring: road.junction === "roundabout", points: run });
	}
}

const SPECIAL = { w296354339: "house", w296353696: "works" };
for (const building of osm.buildings) {
	const points = unclose(building.points.map(turn));
	if (!points.some((p) => inside(p))) continue;
	const tags = building.tags || {};
	const name = rename(tags.name || tags.operator || tags.brand || (tags.building === "fire_station" ? "Feuerwehr" : ""));
	const levels = parseInt(tags["building:levels"] || "0", 10) || 0;
	out.buildings.push({
		id: building.id, role: SPECIAL[building.id] || "", kind: tags.building || "yes", name,
		number: tags["addr:housenumber"] || "", street: tags["addr:street"] || "", levels, points,
	});
}

const AREA_KINDS = ["grass", "farmland", "parking", "flowerbed", "scrub", "garden", "orchard", "meadow", "wood", "fire_station", "retail", "commercial", "industrial", "residential", "area_highway_footway", "area_highway_path"];
for (const area of osm.areas) {
	if (!AREA_KINDS.includes(area.kind)) continue;
	if (area.closed === false) continue;
	const points = clipPolygon(unclose(area.points.map(turn)));
	if (points.length < 3) continue;
	out.areas.push({ kind: area.kind, points });
}
for (const barrier of osm.barriers) {
	if (!["wall", "hedge", "tree_row", "fence"].includes(barrier.kind) || !barrier.points) continue;
	for (const run of clipLine(barrier.points.map(turn))) out.walls.push({ kind: barrier.kind, points: run });
}
for (const tree of osm.trees) {
	const p = turn(tree);
	if (inside(p)) out.trees.push(p);
}
for (const lamp of osm.lamps) {
	const p = turn(lamp);
	if (inside(p)) out.lamps.push(p);
}
for (const rail of osm.railways) {
	for (const run of clipLine(rail.points.map(turn))) out.rails.push({ kind: rail.kind, points: run });
}
const roundabout = osm.roundabout;
out.roundabout = { centre: turn(roundabout.centre), radius: roundabout.radius_m };

const target = path.join(__dirname, "..", "data", "appenweier.json");
fs.writeFileSync(target, JSON.stringify(out));
console.log("wrote", target, "roads", out.roads.length, "buildings", out.buildings.length, "areas", out.areas.length, "walls", out.walls.length, "trees", out.trees.length, "lamps", out.lamps.length, "rails", out.rails.length);
