import json
import sys
from pathlib import Path

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def b58encode(data: bytes) -> str:
    n = int.from_bytes(data, "big")
    out = []
    while n:
        n, r = divmod(n, 58)
        out.append(ALPHABET[r])
    pad = 0
    for byte in data:
        if byte == 0:
            pad += 1
        else:
            break
    return "1" * pad + "".join(reversed(out or [""]))


if len(sys.argv) != 2:
    raise SystemExit("usage: derive-wallet-address.py KEYPAIR_JSON")

path = Path(sys.argv[1])
values = json.loads(path.read_text())
if len(values) != 64:
    raise SystemExit(f"expected 64-byte Solana keypair JSON, got {len(values)} values")

pubkey = bytes(int(value) for value in values[32:64])
print(json.dumps({"path": str(path), "address": b58encode(pubkey)}))

