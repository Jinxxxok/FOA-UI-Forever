import struct
def parse(d):
    assert d[:4] == b"WDC5"
    o = 8 + 128
    rc, fc, rs, sts, th, lh, mn, mx, loc = struct.unpack_from("<9I", d, o); o += 36
    flags, id_index = struct.unpack_from("<HH", d, o); o += 4
    tfc, bp_off, lcc, fsi_size, common_size, pallet_size, sec_count = struct.unpack_from("<7I", d, o); o += 28
    secs = []
    for i in range(sec_count):
        secs.append(struct.unpack_from("<QIIIIIIII", d, o)); o += 40
    o += 4 * tfc  # field structures
    fsi = []
    for i in range(fsi_size // 24):
        fsi.append(struct.unpack_from("<HHIIIII", d, o)); o += 24
    pallet_start = o; o += pallet_size
    common_start = o; o += common_size
    # pallet / common per field
    pal, com = {}, {}
    po, co = pallet_start, common_start
    for fi, f in enumerate(fsi):
        _, _, add, ctype, a, b, cc = f
        if ctype in (3, 4):
            pal[fi] = struct.unpack_from("<%dI" % (add // 4), d, po); po += add
        elif ctype == 2:
            m = {}
            for k in range(add // 8):
                i_, v = struct.unpack_from("<II", d, co + k * 8); m[i_] = v
            com[fi] = (m, a); co += add
    rows = []
    for (tact, foff, src, ssize, oend, idsize, relsize, omc, ctc) in secs:
        p = foff
        recs = d[p:p + src * rs]; p += src * rs + ssize
        ids = list(struct.unpack_from("<%dI" % (idsize // 4), d, p)) if idsize else None; p += idsize
        copies = [struct.unpack_from("<II", d, p + k * 8) for k in range(ctc)]; p += ctc * 8
        p += omc * 6
        rel = {}
        if relsize:
            n, rmin, rmax = struct.unpack_from("<III", d, p); q = p + 12
            for k in range(n):
                fid, ridx = struct.unpack_from("<II", d, q + k * 8); rel[ridx] = fid
            p += relsize
        for r in range(src):
            rec = recs[r * rs:(r + 1) * rs]
            bits = int.from_bytes(rec, "little")
            vals = []
            for fi, f in enumerate(fsi):
                foff_b, fsize_b, add, ctype, a, b, cc = f
                if ctype == 0:
                    v = (bits >> foff_b) & ((1 << fsize_b) - 1)
                elif ctype in (1, 5):
                    v = (bits >> foff_b) & ((1 << b) - 1) if b else 0
                    if ctype == 5 and b and v >> (b - 1): v -= 1 << b
                elif ctype == 3:
                    ix = (bits >> foff_b) & ((1 << b) - 1); v = pal[fi][ix]
                elif ctype == 4:
                    ix = (bits >> foff_b) & ((1 << b) - 1); v = pal[fi][ix * cc:(ix + 1) * cc]
                elif ctype == 2:
                    v = None
                else:
                    v = None
                vals.append(v)
            rid = ids[r] if ids else vals[id_index]
            for fi, (m, dflt) in com.items():
                vals[fi] = m.get(rid, dflt)
            rows.append((rid, vals, rel.get(r)))
    return rows
