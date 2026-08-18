"""Revoke the throwaway development certificates earlier CI runs left behind.

Xcode signs an archive for development and `exportArchive` re-signs it afterwards, so
every build legitimately needs a development certificate. The problem is that the runner
is destroyed minutes later with the private key inside it, so each run leaves behind a
certificate nobody can ever use. Ten of those filled Apple's per-account ceiling, after
which every build failed with "Choose a certificate to revoke" — an error that names
provisioning profiles and points nowhere near the cause. It cost a day, twice.

So the pipeline cleans up after itself.

Two guards, enforced rather than trusted:

  * Only `DEVELOPMENT` certificates named exactly "Created via API" are touched. Real
    distribution certificates belong to a person, are cloud-managed, and revoking one
    would break every future build.
  * Only ones older than MIN_AGE_HOURS. A certificate minted in the last few hours may
    belong to a build running right now, and pulling it out from under that build would
    turn this cleanup into the outage it exists to prevent.

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_CONTENT (base64 .p8) in the environment —
the same three secrets the build already uses. Never fails the job: a cleanup that can
break a green build is worse than no cleanup.
"""
import base64
import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

MIN_AGE_HOURS = 6
API = "https://api.appstoreconnect.apple.com/v1/"


def token() -> str:
    key = base64.b64decode(os.environ["ASC_KEY_CONTENT"]).decode()
    now = int(time.time())
    return jwt.encode(
        {
            "iss": os.environ["ASC_ISSUER_ID"],
            "iat": now,
            "exp": now + 900,
            "aud": "appstoreconnect-v1",
        },
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(path: str, method: str = "GET"):
    req = urllib.request.Request(
        API + path, method=method, headers={"Authorization": "Bearer " + token()}
    )
    try:
        with urllib.request.urlopen(req) as response:
            body = response.read()
            return response.status, (json.loads(body) if body else {})
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def main() -> int:
    status, payload = call("certificates?limit=200")
    if status != 200:
        print(f"::warning::certificate listing failed ({status}); skipping cleanup")
        return 0

    rows = payload.get("data", [])
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=MIN_AGE_HOURS)
    doomed = []

    for certificate in rows:
        attributes = certificate["attributes"]
        if attributes.get("certificateType") != "DEVELOPMENT":
            continue
        if attributes.get("displayName") != "Created via API":
            continue

        # No creation date is exposed, so age is inferred from the expiry: Apple issues
        # development certificates for a year, which makes "expires in less than a year
        # minus MIN_AGE_HOURS" the same question as "older than MIN_AGE_HOURS".
        raw = attributes.get("expirationDate")
        if not raw:
            continue
        expires = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if expires - dt.timedelta(days=365) < cutoff:
            doomed.append(certificate)

    print(f"{len(rows)} certificates on the account, {len(doomed)} stale and revocable")
    for certificate in doomed:
        assert certificate["attributes"]["certificateType"] == "DEVELOPMENT"
        status, _ = call(f"certificates/{certificate['id']}", method="DELETE")
        state = "revoked" if status in (200, 204) else f"failed ({status})"
        print(f"  {certificate['id']}: {state}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:  # noqa: BLE001 - never break the build over cleanup
        print(f"::warning::certificate cleanup skipped: {error}")
        sys.exit(0)
