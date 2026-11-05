import wdc5, pickle, collections
xart = collections.defaultdict(list)
for rid, v, parent in wdc5.parse(open("r1957217.db2","rb").read()):
    xart[parent].append(v[1])
tiles = collections.defaultdict(list)
for rid, v, parent in wdc5.parse(open("r1957210.db2","rb").read()):
    tiles[parent].append((v[2], v[0], v[1], v[3]))
art = {rid: v for rid, v, p in wdc5.parse(open("r1957202.db2","rb").read())}
style = collections.defaultdict(list)
for rid, v, p in wdc5.parse(open("r1957208.db2","rb").read()): style[p].append(v)
ffd = pickle.load(open("root.pkl","rb"))
_, rfd = pickle.load(open("retail.pkl","rb"))
ids = [213,279,291,292,310,311,312,313,314,315,316,221,222,223,225,226,227,228,229,301,300,302,303,304,305,230,231,219,280,281,220,242,243,250,251,252,253,254,255,234,235,236,237,238,239,240,317,318,306,307,308,309,476,477,478,479,248,431,432,435,436]
for u in ids:
    arts = xart.get(u, [])
    for a in arts:
        ts = [t for t in tiles.get(a, []) if t[0] == 0]
        st = style.get(art.get(a, [0,0,0])[2], [])
        lay = st[0] if st else None
        inF = sum(1 for t in ts if t[3] in ffd); inR = sum(1 for t in ts if t[3] in rfd)
        print(u, "art", a, "tiles", len(ts), "inForever", inF, "inRetail", inR, "layer", lay[1:5] if lay else None, "fid0", ts[0][3] if ts else None)
