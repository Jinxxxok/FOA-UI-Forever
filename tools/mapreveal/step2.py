import struct, pickle
r = open("root.bin","rb").read()
hs, ver, total, named = struct.unpack_from("<IIII", r, 4)
print(hs, ver, total, named)
pos = hs
fd = {}
blocks = 0
while pos < len(r):
    num, loc, u1, u2 = struct.unpack_from("<IIII", r, pos); u3 = r[pos+16]
    pos += 17
    cflags = u1 | u2 | (u3 << 17)
    deltas = struct.unpack_from("<%di" % num, r, pos); pos += 4*num
    ck = r[pos:pos+16*num]; pos += 16*num
    if not (cflags & 0x10000000): pos += 8*num
    f = -1
    for i, dlt in enumerate(deltas):
        f = f + 1 + dlt
        if f not in fd or (loc & 0x2) : fd.setdefault(f, ck[i*16:i*16+16])
    blocks += 1
print("blocks", blocks, "files", len(fd), "end", pos, len(r))
pickle.dump(fd, open("root.pkl","wb"))
for f in (1957212, 1134579, 1957217, 1957210):
    print(f, fd.get(f, b"").hex())
