# koKR 판 파일 꺼내기: python3 s3.py <fileDataID> ...  →  <id>_ko.db2
import struct, pickle, sys
from casc import *
want = set(int(a) for a in sys.argv[1:])
r = open("root.bin", "rb").read()
hs, ver, total, named = struct.unpack_from("<IIII", r, 4)
pos = hs
found = {}
while pos < len(r):
    num, loc, u1, u2 = struct.unpack_from("<IIII", r, pos); u3 = r[pos + 16]
    pos += 17
    cflags = u1 | u2 | (u3 << 17)
    deltas = struct.unpack_from("<%di" % num, r, pos); pos += 4 * num
    ck = r[pos:pos + 16 * num]; pos += 16 * num
    if not (cflags & 0x10000000): pos += 8 * num
    f = -1
    for i, dlt in enumerate(deltas):
        f = f + 1 + dlt
        if f in want: found.setdefault(f, []).append((loc, ck[i * 16:i * 16 + 16]))
enc = pickle.load(open("enc.pkl", "rb"))
c = CASC()
for f in sorted(want):
    for loc, ck in found.get(f, []):
        ek = enc.get(ck)
        d = c.read_ekey(ek) if ek else None
        if d and loc & 0x4:
            open("%d_ko.db2" % f, "wb").write(d)
            print(f, "koKR", len(d))
