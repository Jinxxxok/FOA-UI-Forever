import struct, json
d = open("R1240336.db2","rb").read()
o = 136
rc, fc, rs, sts, th, lh, mn, mx, loc = struct.unpack_from("<9I", d, o); o += 36
flags, id_index = struct.unpack_from("<HH", d, o); o += 4
tfc, bp_off, lcc, fsi_size, common_size, pallet_size, sec_count = struct.unpack_from("<7I", d, o); o += 28
secs = [struct.unpack_from("<QIIIIIIII", d, o + 40*i) for i in range(sec_count)]; o += 40*sec_count
o += 4*tfc
fsi = [struct.unpack_from("<HHIIIII", d, o + 24*i) for i in range(fsi_size//24)]
print([ (f[0], f[1], f[3]) for f in fsi])
out = []
for (tact, foff, src, ssize, oend, idsize, relsize, omc, ctc) in secs:
    for r in range(src):
        base = foff + r*rs
        rec = d[base:base+rs]
        bits = int.from_bytes(rec, "little")
        def fld(i):
            fo, fsz = fsi[i][0], fsi[i][1]
            return (bits >> fo) & ((1 << fsz) - 1)
        def s(i):
            v = fld(i); a = base + fsi[i][0]//8 + v
            e = d.index(b"\0", a); return d[a:e].decode("utf-8", "replace")
        name = s(0)
        mp = fld(2); x = struct.unpack("<f", struct.pack("<I", mp & 0xffffffff))[0]; y = struct.unpack("<f", struct.pack("<I", mp >> 32))[0]
        out.append({"id": fld(3), "name": name, "inst": fld(4), "dungeonEnc": fld(5), "order": fld(6), "ui": fld(8), "x": round(x, 4), "y": round(y, 4)})
json.dump(out, open("ej.json", "w"), ensure_ascii=False)
for e in out:
    if e["ui"] in (279, 242, 229, 291, 213, 310, 221, 225, 301, 300, 302, 230, 219, 280, 220, 250, 234, 317, 476, 248):
        print(e)
