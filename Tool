#!/usr/bin/env python3
"""
unity_loc_tool.py - translates Unity games that use Unity Localization + Addressables.
Only standard library for Python 3.8+. Commands:

extract BUNDLE -o FOLDER extracts text to CSV (and updates existing CSVs)
check FOLDER [--font F.ttf] checks tags, {0}, \\n and shows progress
build BUNDLE FOLDER -o OUTPUT [--catalog catalog.bin] generates the translated bundle
install OUTPUT --game GAME_FOLDER installs with backup (restore undoes)
"""
import sys, os, re, csv, json, struct, lzma, shutil, argparse 

# ---------------------------------------------------------------- UnityFS
def lz4_block(src, usize):
    dst = bytearray(); i = 0; n = len(src)
    while i < n:
        t = src[i]; i += 1; l = t >> 4
        if l == 15:
            while True:
                b = src[i]; i += 1; l += b
                if b != 255: break
        dst += src[i:i+l]; i += l
        if i >= n: break
        off = src[i] | (src[i+1] << 8); i += 2; m = t & 15
        if m == 15:
            while True:
                b = src[i]; i += 1; m += b
                if b != 255: break
        m += 4
        if off == 1: dst += bytes([dst[-1]]) * m
        else:
            for _ in range(m): dst.append(dst[-off])
    return bytes(dst)

def decomp(data, ctype, usize):
    if ctype == 0: return data
    if ctype == 1:
        return lzma.decompress(data[:5] + struct.pack('<q', usize) + data[5:], format=lzma.FORMAT_ALONE)
    if ctype in (2, 3): return lz4_block(data, usize)
    raise ValueError('compressão desconhecida: %d' % ctype)

def cstr(d, p):
    e = d.index(b'\0', p); return d[p:e].decode(), e + 1

def load_bundle(path):
    d = open(path, 'rb').read()
    sig, p = cstr(d, 0)
    if sig != 'UnityFS': raise ValueError('não é um bundle UnityFS (%s)' % sig)
    ver = struct.unpack_from('>I', d, p)[0]; p += 4
    _, p = cstr(d, p); _, p = cstr(d, p)
    header_prefix = d[:p]
    size, cbi, ubi, flags = struct.unpack_from('>QIII', d, p); p += 20
    if ver >= 7: p = (p + 15) & ~15
    if flags & 0x80: bi = d[len(d) - cbi:]
    else:
        bi = d[p:p + cbi]; p += cbi
        if flags & 0x200: p = (p + 15) & ~15
    bi = decomp(bi, flags & 0x3f, ubi)
    q = 16; nb = struct.unpack_from('>I', bi, q)[0]; q += 4; blocks = []
    for _ in range(nb):
        u, c, f = struct.unpack_from('>IIH', bi, q); q += 10; blocks.append((u, c, f))
    nn = struct.unpack_from('>I', bi, q)[0]; q += 4; nodes = []
    for _ in range(nn):
        off, sz, fl = struct.unpack_from('>QQI', bi, q); q += 20
        name, q = cstr(bi, q); nodes.append([off, sz, fl, name])
    out = b''
    for u, c, f in blocks:
        out += decomp(d[p:p + c], f & 0x3f, u); p += c
    files = [(n[3], n[2], out[n[0]:n[0] + n[1]]) for n in nodes]
    return header_prefix, files

def write_bundle(path, header_prefix, files):
    cab = b''; nodes = b''
    for name, fl, data in files:
        nodes += struct.pack('>QQI', len(cab), len(data), fl) + name.encode() + b'\0'
        cab += data
    BS = 131072; sizes = [min(BS, len(cab) - i) for i in range(0, len(cab), BS)] or [0]
    bi = bytearray(16) + struct.pack('>I', len(sizes))
    for u in sizes: bi += struct.pack('>IIH', u, u, 0)
    bi += struct.pack('>I', len(files)) + nodes
    flags = 0x240
    pre = len(header_prefix) + 20
    pad1 = (-pre) % 16; pad2 = (-(pre + pad1 + len(bi))) % 16
    total = pre + pad1 + len(bi) + pad2 + len(cab)
    with open(path, 'wb') as f:
        f.write(header_prefix + struct.pack('>QIII', total, len(bi), len(bi), flags))
        f.write(b'\0' * pad1 + bytes(bi) + b'\0' * pad2 + cab)

# ---------------------------------------------------------- SerializedFile
class R:
    def __init__(s, d, p, e='<'): s.d = d; s.p = p; s.e = e
    def f(s, fmt, n): v = struct.unpack_from(s.e + fmt, s.d, s.p)[0]; s.p += n; return v
    def i32(s): return s.f('i', 4)
    def u32(s): return s.f('I', 4)
    def i64(s): return s.f('q', 8)
    def u16(s): return s.f('H', 2)
    def u8(s): return s.f('B', 1)
    def align(s): s.p = (s.p + 3) & ~3
    def cs(s):
        e = s.d.index(b'\0', s.p); v = s.d[s.p:e].decode(); s.p = e + 1; return v

def parse_serialized(d):
    h = R(d, 0, '>')
    meta_size = h.u32(); fsize = h.u32(); ver = h.u32(); data_off = h.u32()
    if ver >= 22:
        h.p = 16; h.u8(); h.p += 3
        meta_size = h.u32(); fsize = h.i64(); data_off = h.i64(); h.i64()
    else:
        h.u8(); h.p += 3
    if not 17 <= ver <= 30: raise ValueError('SerializedFile v%d não suportado' % ver)
    r = R(d, h.p, '<')
    r.cs(); r.i32(); tt = r.u8(); nt = r.i32(); types = []
    for _ in range(nt):
        cid = r.i32(); r.u8(); r.u16()
        if cid == 114: r.p += 16
        r.p += 16
        if tt:
            nn = r.i32(); sb = r.i32(); r.p += nn * (32 if ver >= 19 else 24) + sb
            if ver >= 21:
                dn = r.i32(); r.p += dn * 4
        types.append(cid)
    oc = r.i32(); objs = []
    for _ in range(oc):
        r.align(); pid = r.i64()
        ent = r.p
        start = r.i64() if ver >= 22 else r.u32()
        size = r.u32(); ti = r.i32()
        objs.append(dict(pid=pid, ent=ent, start=start, size=size, cid=types[ti]))
    return dict(ver=ver, data_off=data_off, objs=objs, fsize_off=(24 if ver >= 22 else 4))

# --------------------------------------------------------------- StringTable
def _s(b, p):
    n = struct.unpack_from('<i', b, p)[0]
    if n < 0 or p + 4 + n > len(b): raise ValueError('string')
    v = b[p + 4:p + 4 + n]; return v, (p + 4 + n + 3) & ~3

def parse_table(b):
    p = 12 + 4 + 12
    name, p = _s(b, p); code, p = _s(b, p)
    name = name.decode(); code.decode()
    p += 12
    if struct.unpack_from('<i', b, p)[0] != 0: raise ValueError('metadata')
    p += 4; head = b[:p]
    n = struct.unpack_from('<i', b, p)[0]; p += 4
    if not 0 <= n < 200000: raise ValueError('n')
    ents = []
    for _ in range(n):
        i = struct.unpack_from('<Q', b, p)[0]; p += 8
        s, p = _s(b, p); s = s.decode('utf-8')
        if struct.unpack_from('<i', b, p)[0] != 0: raise ValueError('entry metadata')
        p += 4; ents.append((i, s))
    return name, head, ents, b[p:]

def build_table(head, ents, tail):
    o = bytearray(head) + struct.pack('<i', len(ents))
    for i, s in ents:
        bs = s.encode('utf-8')
        o += struct.pack('<Qi', i, len(bs)) + bs + b'\0' * ((-len(bs)) % 4) + struct.pack('<i', 0)
    return bytes(o + tail)

def find_tables(files):
    """-> lista de (indice_arquivo, indice_objeto, nome, head, ents, tail)"""
    res = []
    for fi, (name, fl, data) in enumerate(files):
        try: m = parse_serialized(data)
        except Exception: continue
        for oi, o in enumerate(m['objs']):
            if o['cid'] != 114: continue
            b = data[m['data_off'] + o['start']: m['data_off'] + o['start'] + o['size']]
            try: res.append((fi, oi) + parse_table(b))
            except Exception: pass
    return res

# ------------------------------------------------------------------- CSV
TOK = re.compile(r'<[^>]+>|\{[0-9A-Za-z_.:]+\}|\\n|\\t|%[sdif]')

def csv_path(folder, table): return os.path.join(folder, table + '.csv')

def read_csv(path):
    rows = {}
    if os.path.exists(path):
        with open(path, newline='', encoding='utf-8-sig') as f:
            for r in csv.DictReader(f): rows[r['source']] = r
    return rows

def cmd_extract(a):
    _, files = load_bundle(a.bundle)
    tabs = find_tables(files)
    if not tabs: sys.exit('Nenhuma StringTable do Unity Localization encontrada neste bundle.')
    os.makedirs(a.out, exist_ok=True)
    for fi, oi, name, head, ents, tail in tabs:
        old = read_csv(csv_path(a.out, name)); cnt = {}; order = []
        for _, s in ents:
            if s.strip() == '': continue
            if s not in cnt: cnt[s] = 0; order.append(s)
            cnt[s] += 1
        new = [s for s in order if s not in old]
        gone = [s for s in old if s not in cnt]
        with open(csv_path(a.out, name), 'w', newline='', encoding='utf-8-sig') as f:
            w = csv.writer(f); w.writerow(['source', 'translation', 'count', 'note'])
            for s in order:
                o = old.get(s, {})
                w.writerow([s, o.get('translation', ''), cnt[s], o.get('note', '')])
        print('%-32s %5d textos únicos | novos: %d | removidos do jogo: %d' % (name, len(order), len(new), len(gone)))
    json.dump({'bundle': os.path.basename(a.bundle)}, open(os.path.join(a.out, 'project.json'), 'w'))

def load_translations(folder):
    out = {}
    for fn in os.listdir(folder):
        if fn.endswith('.csv'):
            out[fn[:-4]] = {s: r['translation'] for s, r in read_csv(os.path.join(folder, fn)).items() if r['translation'].strip()}
    return out

def problems(src, tr):
    errs = []
    if sorted(TOK.findall(src)) != sorted(TOK.findall(tr)): errs.append('tags/variáveis diferentes')
    if src.count('\n') != tr.count('\n'): errs.append('número de quebras de linha diferente')
    if tr.count('<') != tr.count('>'): errs.append('"<" e ">" desbalanceados')
    return errs

def cmd_check(a):
    ttf = None
    if a.font:
        try:
            from fontTools.ttLib import TTFont
            ttf = set(TTFont(a.font).getBestCmap())
        except ImportError: print('(instale fontTools para checar a fonte: pip install fonttools)')
    tot = done = bad = 0
    for fn in sorted(os.listdir(a.folder)):
        if not fn.endswith('.csv'): continue
        rows = read_csv(os.path.join(a.folder, fn)); t = d = 0
        for s, r in rows.items():
            t += 1; tr = r['translation']
            if not tr.strip(): continue
            d += 1
            for e in problems(s, tr):
                bad += 1; print('[%s] %s\n   origem:   %r\n   tradução: %r' % (fn[:-4], e, s[:90], tr[:90]))
            if ttf:
                miss = sorted({c for c in tr if ord(c) not in ttf and c not in '\n\r'})
                if miss: bad += 1; print('[%s] glifos ausentes na fonte: %s -> %r' % (fn[:-4], ''.join(miss), tr[:60]))
        tot += t; done += d
        print('%-36s %5d/%-5d (%d%%)' % (fn[:-4], d, t, 100 * d // max(t, 1)))
    print('TOTAL %d/%d  | problemas: %d' % (done, tot, bad))
    sys.exit(1 if bad else 0)

# ----------------------------------------------------------------- catalog
def patch_catalog(cat_path, old_size, new_size, out_path):
    cat = bytearray(open(cat_path, 'rb').read())
    pat = struct.pack('<I', old_size); hits = []
    for m in re.finditer(re.escape(pat), bytes(cat)):
        i = m.start()
        if i >= 12:
            h, nm = struct.unpack_from('<II', cat, i - 12)
            if h < len(cat) and nm < len(cat): hits.append(i)
    if len(hits) != 1:
        print('AVISO: não consegui localizar a entrada do bundle no catalog.bin de forma única (%d candidatos).' % len(hits)); return False
    i = hits[0]; struct.pack_into('<II', cat, i - 4, 0, new_size)   # CRC=0 desliga a verificação
    open(out_path, 'wb').write(cat); return True

def cmd_build(a):
    header, files = load_bundle(a.bundle)
    tr = load_translations(a.folder)
    tabs = find_tables(files); files = [list(f) for f in files]; changed = 0; total = 0
    by_file = {}
    for fi, oi, name, head, ents, tail in tabs:
        m = tr.get(name, {}); new = []
        for i, s in ents:
            t = m.get(s)
            if t is not None and not problems(s, t): new.append((i, t)); changed += 1
            else:
                if t is not None: print('ignorada (problema de formatação):', repr(s[:60]))
                new.append((i, s))
            total += 1
        by_file.setdefault(fi, {})[oi] = build_table(head, new, tail)
    for fi, repl in by_file.items():
        d = files[fi][2]; m = parse_serialized(d); base = m['data_off']
        meta = bytearray(d[:base]); body = bytearray()
        for oi, o in enumerate(m['objs']):
            b = repl.get(oi, d[base + o['start']: base + o['start'] + o['size']])
            while len(body) % 16: body.append(0)
            if m['ver'] >= 22: struct.pack_into('<q', meta, o['ent'], len(body)); struct.pack_into('<I', meta, o['ent'] + 8, len(b))
            else: struct.pack_into('<II', meta, o['ent'], len(body), len(b))
            body += b
        cab = bytearray(meta + body)
        if m['ver'] >= 22: struct.pack_into('>q', cab, m['fsize_off'], len(cab))
        else: struct.pack_into('>I', cab, m['fsize_off'], len(cab))
        files[fi][2] = bytes(cab)
    os.makedirs(a.out, exist_ok=True)
    out_b = os.path.join(a.out, os.path.basename(a.bundle))
    write_bundle(out_b, header, [tuple(f) for f in files])
    print('bundle gerado: %s  (%d de %d textos traduzidos)' % (out_b, changed, total))
    if a.catalog:
        out_c = os.path.join(a.out, 'catalog.bin')
        ok = patch_catalog(a.catalog, os.path.getsize(a.bundle), os.path.getsize(out_b), out_c)
        print('catalog.bin ' + ('ajustado (CRC desativado): ' + out_c if ok else 'NÃO ajustado'))
    else:
        print('Dica: use --catalog caminho/do/catalog.bin, senão o jogo pode recusar o bundle (CRC).')

# ------------------------------------------------------------ install
def find_aa(game):
    for root, dirs, _ in os.walk(game):
        if os.path.basename(root) == 'aa' and 'StandaloneWindows64' in dirs: return root
    sys.exit('pasta StreamingAssets/aa não encontrada em ' + game)

def cmd_install(a):
    aa = find_aa(a.game)
    for fn in os.listdir(a.saida):
        if fn.endswith('.bundle') or fn == 'catalog.bin':
            dst = os.path.join(aa, fn) if fn == 'catalog.bin' else os.path.join(aa, 'StandaloneWindows64', fn)
            if os.path.exists(dst) and not os.path.exists(dst + '.bak'): shutil.copy2(dst, dst + '.bak')
            shutil.copy2(os.path.join(a.saida, fn), dst); print('instalado:', dst)

def cmd_restore(a):
    aa = find_aa(a.game); n = 0
    for root, _, fs in os.walk(aa):
        for fn in fs:
            if fn.endswith('.bak'):
                p = os.path.join(root, fn); shutil.copy2(p, p[:-4]); os.remove(p); n += 1; print('restaurado:', p[:-4])
    if not n: print('nenhum backup encontrado')

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest='cmd', required=True)
    p = sp.add_parser('extract'); p.add_argument('bundle'); p.add_argument('-o', '--out', required=True); p.set_defaults(f=cmd_extract)
    p = sp.add_parser('check'); p.add_argument('folder'); p.add_argument('--font'); p.set_defaults(f=cmd_check)
    p = sp.add_parser('build'); p.add_argument('bundle'); p.add_argument('folder'); p.add_argument('-o', '--out', required=True); p.add_argument('--catalog'); p.set_defaults(f=cmd_build)
    p = sp.add_parser('install'); p.add_argument('saida'); p.add_argument('--game', required=True); p.set_defaults(f=cmd_install)
    p = sp.add_parser('restore'); p.add_argument('--game', required=True); p.set_defaults(f=cmd_restore)
    a = ap.parse_args(); a.f(a)

if __name__ == '__main__': main()
