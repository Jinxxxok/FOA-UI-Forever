# WDC5 오프셋 맵(sparse) 표의 글자 필드 읽기 (Spell.db2 등)
import struct
def parse_sparse_strings(d, nfields):
    o = 8 + 128
    rc, fc, rs, sts, th, lh, mn, mx, loc = struct.unpack_from("<9I", d, o); o += 36
    flags, id_index = struct.unpack_from("<HH", d, o); o += 4
    tfc, bp_off, lcc, fsi_size, common_size, pallet_size, sec_count = struct.unpack_from("<7I", d, o); o += 28
    secs = [struct.unpack_from("<QIIIIIIII", d, o + 40 * i) for i in range(sec_count)]
    out = {}
    for (tact, foff, src, ssize, oend, idsize, relsize, omc, ctc) in secs:
        if tact and d[foff:foff + 16] == b"\0" * 16: continue  # 암호화된 구역
        p = oend
        ids = struct.unpack_from("<%dI" % (idsize // 4), d, p) if idsize else (); p += idsize
        p += ctc * 8
        om = [struct.unpack_from("<IH", d, p + 6 * i) for i in range(omc)]; p += 6 * omc
        p += relsize
        omids = struct.unpack_from("<%dI" % omc, d, p) if omc else ()
        idl = omids if omids else ids
        for i, (off, size) in enumerate(om):
            rec = d[off:off + size]
            vals = []; q = 0
            for k in range(nfields):
                e = rec.find(b"\0", q)
                if e < 0: break
                vals.append(rec[q:e].decode("utf-8", "replace")); q = e + 1
            if i < len(idl): out[idl[i]] = vals
    return out
