import struct, json, collections, wdc5
def strings_parse(path, sfields):
    d = open(path,"rb").read()
    o = 136
    rc, fc, rs = struct.unpack_from("<3I", d, o); o += 36 + 4
    tfc, bp_off, lcc, fsi_size, common_size, pallet_size, sec_count = struct.unpack_from("<7I", d, o); o += 28
    secs = [struct.unpack_from("<QIIIIIIII", d, o + 40*i) for i in range(sec_count)]; o += 40*sec_count + 4*tfc
    fsi = [struct.unpack_from("<HHIIIII", d, o + 24*i) for i in range(fsi_size//24)]
    out = {}
    for (tact, foff, src, ssize, oend, idsize, relsize, omc, ctc) in secs:
        idp = foff + src*rs + ssize
        ids = struct.unpack_from("<%dI" % (idsize//4), d, idp) if idsize else None
        for r in range(src):
            base = foff + r*rs
            bits = int.from_bytes(d[base:base+rs], "little")
            res = []
            for i in sfields:
                v = (bits >> fsi[i][0]) & ((1 << fsi[i][1]) - 1)
                a = base + fsi[i][0]//8 + v
                e = d.index(b"\0", a); res.append(d[a:e].decode("utf-8","replace"))
            out[ids[r] if ids else r] = res
    return out
names = strings_parse("r1957206.db2", [0])
xart = collections.defaultdict(list)
for rid, v, parent in wdc5.parse(open("r1957217.db2","rb").read()): xart[parent].append(v[1])
tiles = collections.defaultdict(list)
for rid, v, parent in wdc5.parse(open("r1957210.db2","rb").read()): tiles[parent].append((v[2], v[0], v[1], v[3]))
ids = list(range(213,320)) + [476,477,478,479,431,432,435,436]
maps = {}
for u in ids:
    for a in xart.get(u, []):
        ts = sorted(t for t in tiles.get(a, []) if t[0] == 0)
        if len(ts) == 12:
            maps[u] = {"name": names.get(u, ["?"])[0], "art": a, "fids": [t[3] for t in ts]}
ej = json.load(open("ej.json"))
out = {"maps": maps, "ej": [e for e in ej if e["ui"] in maps]}
json.dump(out, open("dmaps.json","w"), ensure_ascii=False)
print(len(maps), len(out["ej"]))
for u in sorted(maps)[:120]: print(u, maps[u]["name"])
