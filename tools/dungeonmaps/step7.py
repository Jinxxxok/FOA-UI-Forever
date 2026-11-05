import struct, pickle, wdc5, os
from casc import *
c = CASC()
cfg = build_config("bc493ecb2898766c0f8947a99b4b3d65")
print(cfg.get("build-name"))
d = c.read_ekey(bytes.fromhex(cfg["encoding"][1])); enc = parse_encoding(d, None); print("enc", len(enc))
r = c.read_ekey(enc[bytes.fromhex(cfg["root"][0])]); open("root_retail.bin","wb").write(r)
hs = struct.unpack_from("<I", r, 4)[0]; pos = hs; fd = {}
while pos < len(r):
    num, loc, u1, u2 = struct.unpack_from("<IIII", r, pos); u3 = r[pos+16]; pos += 17
    cf = u1 | u2 | (u3 << 17)
    deltas = struct.unpack_from("<%di" % num, r, pos); pos += 4*num
    ck = r[pos:pos+16*num]; pos += 16*num
    if not (cf & 0x10000000): pos += 8*num
    f = -1
    for i, dl in enumerate(deltas):
        f += 1 + dl
        fd.setdefault(f, ck[i*16:i*16+16])
print("retail files", len(fd))
pickle.dump((enc, fd), open("retail.pkl","wb"))
for f in (1957202, 1957206, 1957210, 1957217, 1957208):
    ek = enc.get(fd.get(f, b"")); dd = c.read_ekey(ek) if ek else None
    if dd: open("r%d.db2" % f, "wb").write(dd); print(f, len(dd))
