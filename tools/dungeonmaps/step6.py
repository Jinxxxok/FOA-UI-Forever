import struct, pickle, wdc5
from casc import *
c = CASC()
enc = pickle.load(open("enc.pkl","rb")); fd = pickle.load(open("root.pkl","rb"))
for f in (1957202, 1957206, 1957210, 1957217, 1957199, 1957200, 1957204, 1957208):
    if f not in fd: print(f, "none"); continue
    ek = enc.get(fd[f]); d = c.read_ekey(ek) if ek else None
    if not d: print(f, "nodata"); continue
    open("%d.db2"%f,"wb").write(d)
    rc, fc, rs = struct.unpack_from("<III", d, 136)
    try:
        rows = wdc5.parse(d)
        print(f, "rec", rc, "fields", fc, rows[:2])
    except Exception as e:
        print(f, "rec", rc, "fields", fc, "ERR", e)
