import wdc5, collections, json
t = wdc5.parse(open("1957212.db2","rb").read())
o = wdc5.parse(open("1134579.db2","rb").read())
tiles = collections.defaultdict(list)
for rid, v, parent in t:
    row, col, layer, fid = v
    tiles[parent].append((layer, row, col, fid))
fl = collections.Counter(); pc = collections.Counter()
art = collections.defaultdict(list)
for rid, v, parent in o:
    _, artid, w, h, x, y = v[:6]; cond, flags = v[10], v[11]
    fl[flags] += 1; pc[cond != 0] += 1
    ts = sorted(tiles.get(rid, []))
    fids = [f for (l, r, c, f) in ts if l == 0]
    if not fids: continue
    art[artid].append([w, h, x, y, flags, cond, fids])
print("flags", fl, "cond", pc, "arts", len(art), "missing tiles", sum(1 for rid,v,p in o if rid not in tiles))
json.dump(art, open("reveal.json","w"))
import os; print(os.path.getsize("reveal.json"))
