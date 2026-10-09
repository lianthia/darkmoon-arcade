"""Reads files straight from the installed WoW: Forever client (local CASC storage).

    python tools/casc_local.py check <fileid> [...]    is the file in the client and readable?
    python tools/casc_local.py png <fileid> <out.png>  extracts a texture as PNG

wago.tools serves files of every build, so a file found there may still be missing, encrypted or
not downloaded in the client Ben plays. This answers for the real client.
"""
import pathlib
import struct
import sys
import zlib

WOW = pathlib.Path(r"G:\Battle.net\World of Warcraft")
PRODUCT = "wow_classic_beta"
ENCRYPTED = 0x8000000
NO_NAMES = 0x10000000


def build_config():
    lines = (WOW / ".build.info").read_text().splitlines()
    head = [h.split("!")[0] for h in lines[0].split("|")]
    for line in lines[1:]:
        row = dict(zip(head, line.split("|")))
        if row.get("Product") == PRODUCT:
            key = row["Build Key"]
            text = (WOW / "Data" / "config" / key[:2] / key[2:4] / key).read_text()
            return dict(l.split(" = ", 1) for l in text.splitlines() if " = " in l)
    raise SystemExit("product not installed")


class Storage:
    def __init__(self):
        self.index = {}
        data = WOW / "Data" / "data"
        # Each bucket keeps its newest .idx file.
        newest = {}
        for f in data.glob("*.idx"):
            bucket = f.name[:2]
            if bucket not in newest or f.name > newest[bucket].name:
                newest[bucket] = f
        for f in newest.values():
            raw = f.read_bytes()
            size = struct.unpack_from("<I", raw, 0x20)[0]
            for pos in range(0x28, 0x28 + size, 18):
                ekey = raw[pos:pos + 9]
                packed = int.from_bytes(raw[pos + 9:pos + 14], "big")
                length = struct.unpack_from("<I", raw, pos + 14)[0]
                self.index.setdefault(ekey, (packed >> 30, packed & 0x3FFFFFFF, length))
        self.data = data

    def has(self, ekey):
        return ekey[:9] in self.index

    def read(self, ekey):
        archive, offset, length = self.index[ekey[:9]]
        with open(self.data / f"data.{archive:03d}", "rb") as f:
            f.seek(offset)
            blob = f.read(length)
        return blte(blob[30:])


class Encrypted(Exception):
    pass


def blte(blob):
    assert blob[:4] == b"BLTE", "not BLTE"
    header = struct.unpack_from(">I", blob, 4)[0]
    if header == 0:
        return chunk(blob[8:])
    count = int.from_bytes(blob[9:12], "big")
    sizes = [struct.unpack_from(">II", blob, 12 + i * 24) for i in range(count)]
    out, pos = [], header
    for comp, _ in sizes:
        out.append(chunk(blob[pos:pos + comp]))
        pos += comp
    return b"".join(out)


def chunk(c):
    mode = c[:1]
    if mode == b"N":
        return c[1:]
    if mode == b"Z":
        return zlib.decompress(c[1:])
    if mode == b"E":
        raise Encrypted()
    if mode == b"F":
        return blte(c[1:])
    raise ValueError(f"chunk mode {mode!r}")


def parse_encoding(raw):
    assert raw[:2] == b"EN"
    hash_c, hash_e = raw[3], raw[4]
    cpage_kb = struct.unpack_from(">H", raw, 5)[0]
    cpages = struct.unpack_from(">I", raw, 9)[0]
    espec = struct.unpack_from(">I", raw, 18)[0]
    pos = 22 + espec + cpages * (hash_c + 16)
    table = {}
    for _ in range(cpages):
        page = raw[pos:pos + cpage_kb * 1024]
        p = 0
        while p + 6 + hash_c <= len(page):
            keys = page[p]
            if keys == 0:
                break
            ckey = page[p + 6:p + 6 + hash_c]
            table[ckey] = page[p + 6 + hash_c:p + 6 + hash_c + hash_e]
            p += 6 + hash_c + keys * hash_e
        pos += cpage_kb * 1024
    return table


def rot(x, k):
    return ((x << k) | (x >> (32 - k))) & 0xFFFFFFFF


def hashlittle2(data, pc=0, pb=0):
    """Bob Jenkins' lookup3, as CASC uses it for path hashes."""
    length = len(data)
    a = b = c = (0xDEADBEEF + length + pc) & 0xFFFFFFFF
    c = (c + pb) & 0xFFFFFFFF
    pos = 0
    while length > 12:
        a = (a + int.from_bytes(data[pos:pos + 4], "little")) & 0xFFFFFFFF
        b = (b + int.from_bytes(data[pos + 4:pos + 8], "little")) & 0xFFFFFFFF
        c = (c + int.from_bytes(data[pos + 8:pos + 12], "little")) & 0xFFFFFFFF
        a = (a - c) & 0xFFFFFFFF; a ^= rot(c, 4); c = (c + b) & 0xFFFFFFFF
        b = (b - a) & 0xFFFFFFFF; b ^= rot(a, 6); a = (a + c) & 0xFFFFFFFF
        c = (c - b) & 0xFFFFFFFF; c ^= rot(b, 8); b = (b + a) & 0xFFFFFFFF
        a = (a - c) & 0xFFFFFFFF; a ^= rot(c, 16); c = (c + b) & 0xFFFFFFFF
        b = (b - a) & 0xFFFFFFFF; b ^= rot(a, 19); a = (a + c) & 0xFFFFFFFF
        c = (c - b) & 0xFFFFFFFF; c ^= rot(b, 4); b = (b + a) & 0xFFFFFFFF
        length -= 12
        pos += 12
    if length == 0:
        return c, b
    tail = data[pos:] + bytes(12 - length)
    a = (a + int.from_bytes(tail[0:4], "little")) & 0xFFFFFFFF
    b = (b + int.from_bytes(tail[4:8], "little")) & 0xFFFFFFFF
    c = (c + int.from_bytes(tail[8:12], "little")) & 0xFFFFFFFF
    c ^= b; c = (c - rot(b, 14)) & 0xFFFFFFFF
    a ^= c; a = (a - rot(c, 11)) & 0xFFFFFFFF
    b ^= a; b = (b - rot(a, 25)) & 0xFFFFFFFF
    c ^= b; c = (c - rot(b, 16)) & 0xFFFFFFFF
    a ^= c; a = (a - rot(c, 4)) & 0xFFFFFFFF
    b ^= a; b = (b - rot(a, 14)) & 0xFFFFFFFF
    c ^= b; c = (c - rot(b, 24)) & 0xFFFFFFFF
    return c, b


def path_hash(path):
    c, b = hashlittle2(path.upper().replace("/", "\\").encode())
    return (c << 32) | b


def parse_root(raw, names=None):
    files = {}
    pos = 4
    if raw[:4] == b"TSFM":
        header, version = struct.unpack_from("<II", raw, 4)
        if header < 100:
            pos = header
        else:
            version = 0
            pos = 12
    else:
        version, pos = -1, 0
    while pos < len(raw):
        count = struct.unpack_from("<I", raw, pos)[0]
        if version == 2:
            _, f1, f2, f3 = struct.unpack_from("<IIIB", raw, pos + 4)
            flags = f1 | f2 | (f3 << 17)
            pos += 17
        else:
            flags = struct.unpack_from("<I", raw, pos + 4)[0]
            pos += 12
        ids, fid = [], -1
        for i in range(count):
            fid += struct.unpack_from("<i", raw, pos + i * 4)[0] + 1
            ids.append(fid)
        pos += count * 4
        for i, fid in enumerate(ids):
            files.setdefault(fid, (raw[pos + i * 16:pos + i * 16 + 16], flags))
        pos += count * 16
        if version < 0 or not flags & NO_NAMES:
            if names is not None:
                for i, fid in enumerate(ids):
                    names.setdefault(struct.unpack_from("<Q", raw, pos + i * 8)[0], fid)
            pos += count * 8
    return files


class Client:
    def __init__(self):
        cfg = build_config()
        self.storage = Storage()
        enc_ekey = bytes.fromhex(cfg["encoding"].split()[1])
        self.encoding = parse_encoding(self.storage.read(enc_ekey))
        root_ekey = self.encoding[bytes.fromhex(cfg["root"].split()[0])]
        self.names = {}
        self.root = parse_root(self.storage.read(root_ekey), self.names)

    def file_id(self, path):
        """File ID of a client path like Interface/Icons/Spell_Holy_Heal (extension optional)."""
        if "." not in path.rsplit("\\", 1)[-1].rsplit("/", 1)[-1]:
            path += ".blp"
        return self.names.get(path_hash(path))

    def status(self, fid):
        entry = self.root.get(fid)
        if not entry:
            return "missing"
        ckey, flags = entry
        ekey = self.encoding.get(ckey)
        if not ekey or not self.storage.has(ekey):
            return "not downloaded"
        try:
            self.storage.read(ekey)
        except Encrypted:
            return "encrypted"
        return "encrypted-flag" if flags & ENCRYPTED else "ok"

    def read(self, fid):
        ckey, _ = self.root[fid]
        return self.storage.read(self.encoding[ckey])


def main():
    client = Client()
    if sys.argv[1] == "check":
        for fid in sys.argv[2:]:
            print(fid, client.status(int(fid)))
    elif sys.argv[1] == "png":
        sys.path.insert(0, str(pathlib.Path(__file__).parent))
        from atlas_preview import decode_blp
        decode_blp(client.read(int(sys.argv[2]))).save(sys.argv[3])
        print("wrote", sys.argv[3])


if __name__ == "__main__":
    main()
