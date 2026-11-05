import time, pickle
from casc import *
t=time.time()
c = CASC(); print("idx", len(c.idx), time.time()-t)
cfg = build_config("9006ba6948388dd0d4a0578e64b8a92e")
enc_ckey, enc_ekey = cfg["encoding"]
d = c.read_ekey(bytes.fromhex(enc_ekey)); print("encoding", len(d) if d else None)
enc = parse_encoding(d, None); print("enc entries", len(enc), time.time()-t)
pickle.dump(enc, open("enc.pkl","wb"))
root_ekey = enc.get(bytes.fromhex(cfg["root"][0])); print("root ekey", root_ekey.hex() if root_ekey else None)
r = c.read_ekey(root_ekey); print("root", len(r), r[:32])
open("root.bin","wb").write(r)
