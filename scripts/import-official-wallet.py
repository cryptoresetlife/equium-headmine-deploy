import json
import sys
from pathlib import Path

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def b58decode(value: str) -> bytes:
    n = 0
    for char in value.strip():
        if char not in ALPHABET:
            raise ValueError(f"invalid base58 character: {char!r}")
        n = n * 58 + ALPHABET.index(char)
    raw = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    pad = 0
    for char in value:
        if char == "1":
            pad += 1
        else:
            break
    return b"\0" * pad + raw


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


def parse_private_key(secret: str) -> bytes:
    secret = secret.strip()
    if not secret:
        raise ValueError("empty private key")
    if secret.startswith("["):
        values = json.loads(secret)
        return bytes(int(value) for value in values)
    return b58decode("".join(secret.split()))


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: import-official-wallet.py EXPECTED_ADDRESS OUTPUT_PATH", file=sys.stderr)
        return 2

    expected = sys.argv[1]
    output = Path(sys.argv[2])
    secret = sys.stdin.read()

    try:
        from nacl.signing import SigningKey
    except Exception as exc:
        print(f"PyNaCl is required but unavailable: {exc}", file=sys.stderr)
        print("Install it with: python -m pip install --user pynacl", file=sys.stderr)
        return 2

    try:
        raw = parse_private_key(secret)
    except Exception as exc:
        print(f"Could not parse private key: {exc}", file=sys.stderr)
        return 1

    if len(raw) == 64:
        seed = raw[:32]
    elif len(raw) == 32:
        seed = raw
    else:
        print(f"Unsupported private key length: {len(raw)} bytes", file=sys.stderr)
        return 1

    signing_key = SigningKey(seed)
    pubkey = bytes(signing_key.verify_key)
    keypair = seed + pubkey
    address = b58encode(pubkey)

    if address != expected:
        print("Derived address mismatch. Refusing to save.", file=sys.stderr)
        print(f"Expected: {expected}", file=sys.stderr)
        print(f"Derived:  {address}", file=sys.stderr)
        return 1

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(list(keypair), separators=(",", ":")))
    (output.parent / "official-address.txt").write_text(address + "\n")
    print(address)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

