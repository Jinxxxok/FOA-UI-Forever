import struct, pickle
from casc import *
c = CASC()
enc = pickle.load(open("enc.pkl","rb")); fd = pickle.load(open("root.pkl","rb"))
for f in (1957212, 1134579):
    ek = enc.get(fd[f]); d = c.read_ekey(ek)
    open("%d.db2"%f,"wb").write(d)
    magic = d[:4]; ver = struct.unpack_from("<I", d, 4)[0]
    off = 8 + 128
    rc, fc, rs, sts, th, lh, mn, mx, loc = struct.unpack_from("<IIIIIIIII", d, off)
    print(f, magic, ver, "records", rc, "fields", fc, "recsize", rs, "minmax", mn, mx, hex(th))
