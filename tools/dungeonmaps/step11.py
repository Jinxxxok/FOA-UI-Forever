import struct, pickle, wdc5
from casc import *
c = CASC()
fenc = pickle.load(open("enc.pkl","rb")); ffd = pickle.load(open("root.pkl","rb"))
renc, rfd = pickle.load(open("retail.pkl","rb"))
for tag, enc, fd in (("F", fenc, ffd), ("R", renc, rfd)):
    for f in (1240336, 1237438, 1301155, 1347279):
        ck = fd.get(f)
        ek = enc.get(ck) if ck else None
        d = c.read_ekey(ek) if ek else None
        if not d: print(tag, f, "none"); continue
        open("%s%d.db2" % (tag, f), "wb").write(d)
        rc, fc, rs = struct.unpack_from("<III", d, 136)
        th = struct.unpack_from("<I", d, 136+16)[0]
        print(tag, f, d[:4], "rec", rc, "fields", fc, "recsize", rs, hex(th))
