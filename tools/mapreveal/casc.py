import os, struct, zlib, glob, hashlib
BASE = os.path.expanduser("~/mnt/World of Warcraft/Data")

def load_indexes():
    idx = {}
    for folder in ("data",):
        files = glob.glob(os.path.join(BASE, folder, "*.idx"))
        best = {}
        for f in files:
            n = os.path.basename(f)[:-4]
            b, v = int(n[:2], 16), int(n[2:], 16)
            if b not in best or v > best[b][0]: best[b] = (v, f)
        for b, (v, f) in best.items():
            d = open(f, "rb").read()
            hsize = struct.unpack_from("<I", d, 0)[0]
            pos = 8 + hsize
            pos = (pos + 15) & ~15
            esize = struct.unpack_from("<I", d, pos)[0]
            pos += 8
            for i in range(esize // 18):
                e = d[pos + i * 18: pos + i * 18 + 18]
                key = e[:9]
                val = int.from_bytes(e[9:14], "big")
                size = struct.unpack("<I", e[14:18])[0]
                if key not in idx:
                    idx[key] = (val >> 30, val & 0x3FFFFFFF, size)
    return idx

def blte(data):
    assert data[:4] == b"BLTE", data[:4]
    hsize = struct.unpack(">I", data[4:8])[0]
    out = []
    if hsize == 0:
        chunks = [(len(data) - 8, None)]
        pos = 8
    else:
        cnt = int.from_bytes(data[9:12], "big")
        chunks = []
        for i in range(cnt):
            cs, ds = struct.unpack_from(">II", data, 12 + i * 24)
            chunks.append((cs, ds))
        pos = hsize
    for cs, ds in chunks:
        c = data[pos:pos + cs]
        pos += cs
        m = c[:1]
        if m == b"N": out.append(c[1:])
        elif m == b"Z": out.append(zlib.decompress(c[1:]))
        elif m == b"E": out.append(b"\0" * (ds or 0))
        else: raise Exception("mode %r" % m)
    return b"".join(out)

class CASC:
    def __init__(self):
        self.idx = load_indexes()
        self.fh = {}
    def read_ekey(self, ekey):
        e = self.idx.get(ekey[:9])
        if not e: return None
        arc, off, size = e
        if arc not in self.fh:
            self.fh[arc] = open(os.path.join(BASE, "data", "data.%03d" % arc), "rb")
        f = self.fh[arc]
        f.seek(off)
        d = f.read(size)
        return blte(d[30:])

def build_config(key):
    p = os.path.join(BASE, "config", key[:2], key[2:4], key)
    cfg = {}
    for l in open(p, encoding="utf-8"):
        if " = " in l:
            k, v = l.strip().split(" = ", 1)
            cfg[k] = v.split()
    return cfg

def parse_encoding(d, wanted):
    assert d[:2] == b"EN"
    ck, ek = d[3], d[4]
    cpage = struct.unpack(">H", d[5:7])[0] * 1024
    cpages = struct.unpack(">I", d[9:13])[0]
    espec = struct.unpack(">I", d[18:22])[0]
    pos = 22 + espec
    index = pos
    pos += cpages * (ck + 16)
    res = {}
    for p in range(cpages):
        page = d[pos + p * cpage: pos + (p + 1) * cpage]
        q = 0
        while q + 6 + ck <= len(page):
            n = page[q]
            if n == 0: break
            ckey = page[q + 6: q + 6 + ck]
            ekeys = page[q + 6 + ck: q + 6 + ck + ek * n]
            if wanted is None or ckey in wanted: res[ckey] = ekeys[:ek]
            q += 6 + ck + ek * n
    return res
