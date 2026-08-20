"""Read the Google Play side of Nagg without opening the console.

The Android counterpart of tools/asc_metadata.py, and written for the same reason: half
of what blocks a release is invisible until something fails, and a panel session cannot be
diffed, repeated, or handed to the next person.

## What it needs
A Play service account JSON that has access to this app. The one in use belongs to the
VexFit RevenueCat project and was granted access to Nagg by hand:

    vexfit-revenuecat@project-03b3d6d8-d75b-446e-aaf.iam.gserviceaccount.com

Point PLAY_KEY_PATH at its JSON, or drop the file next to the default path below.

## What the API will and will not do here
Uploading a bundle, moving it between tracks, writing the store listing: all fine.
Creating subscriptions is not -- it returns PERMISSION_DENIED from the same account that
can commit a listing, because Play gates every monetary endpoint behind a payments
profile. That is a bank-and-tax setup, not a permission.

Run: python tools/play_status.py
"""
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

KEY_PATH = os.environ.get(
    "PLAY_KEY_PATH",
    os.path.expanduser("~/Downloads/project-03b3d6d8-d75b-446e-aaf-1bde7f7299b1.json"),
)
PACKAGE = os.environ.get("PLAY_PACKAGE", "com.r00tlab.nagg")
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"

_token = {"value": None, "expires": 0.0}


def token() -> str:
    if _token["value"] and _token["expires"] > time.time() + 60:
        return _token["value"]

    creds = json.load(open(KEY_PATH))
    now = int(time.time())
    assertion = jwt.encode(
        {"iss": creds["client_email"], "scope": SCOPE, "aud": creds["token_uri"],
         "iat": now, "exp": now + 3600},
        creds["private_key"], algorithm="RS256",
    )
    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }).encode()
    with urllib.request.urlopen(urllib.request.Request(creds["token_uri"], data=body)) as r:
        payload = json.loads(r.read())
    _token["value"] = payload["access_token"]
    _token["expires"] = time.time() + payload.get("expires_in", 3600)
    return _token["value"]


def call(path, method="GET", body=None):
    url = path if path.startswith("http") else API + path.lstrip("/")
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": "Bearer " + token()}
    if data:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, method=method, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        try:
            detail = json.dumps(json.loads(detail)["error"], indent=1)[:600]
        except Exception:
            pass
        raise SystemExit("HTTP %s %s %s\n%s" % (error.code, method, url, detail))


def main():
    # Every read happens inside one edit; an edit that is never committed changes nothing.
    edit = call("applications/%s/edits" % PACKAGE, "POST", {})["id"]

    print("package        %s" % PACKAGE)

    for track in call("applications/%s/edits/%s/tracks" % (PACKAGE, edit)).get("tracks", []):
        releases = track.get("releases", [])
        if releases:
            for r in releases:
                print("track          %-11s %s  versionCodes=%s"
                      % (track["track"], r.get("status"), r.get("versionCodes")))

    try:
        listing = call("applications/%s/edits/%s/listings/en-US" % (PACKAGE, edit))
        print("listing        %s | short=%d chars | full=%d chars"
              % (listing.get("title"), len(listing.get("shortDescription") or ""),
                 len(listing.get("fullDescription") or "")))
    except SystemExit:
        print("listing        NOT SET")

    for slot in ("phoneScreenshots", "sevenInchScreenshots", "tenInchScreenshots",
                 "icon", "featureGraphic"):
        images = call("applications/%s/edits/%s/listings/en-US/%s"
                      % (PACKAGE, edit, slot)).get("images", [])
        print("%-14s %d" % (slot, len(images)))

    subs = call("applications/%s/subscriptions?pageSize=10" % PACKAGE).get("subscriptions", [])
    if subs:
        for s in subs:
            print("subscription   %s" % s.get("productId"))
    else:
        # Not a permission problem. Play refuses every monetary endpoint until a payments
        # profile exists, and says "permission denied" while doing it.
        print("subscription   none — payments profile not set up yet")


if __name__ == "__main__":
    main()
