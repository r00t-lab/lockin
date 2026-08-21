"""Upload a signed .aab to a Play track, without opening the console.

The other half of tools/play_status.py, and needed for the same reason: the
`play-*` tag builds and signs a bundle but does not upload it, because
PLAY_SERVICE_ACCOUNT_JSON is not set as a repo secret. Until it is, every
version code on the internal track gets there by hand -- this script is the
hand.

## Use

    python tools/play_upload.py <path-to.aab> [track]
    python tools/play_upload.py --promote <versionCode> <track>

`--promote` moves a bundle that is already on Play to another track without
uploading anything. Use it to put the build the testers already have onto the
closed track: Play refuses a version code it has seen before, so re-uploading
the same .aab fails.

`track` defaults to internal. The signed bundle from any tag is published as a
release asset, so the usual sequence is:

    curl -LO https://github.com/r00t-lab/lockin/releases/download/play-9/app-release.aab
    python tools/play_upload.py app-release.aab internal

## What it needs
The same service account JSON as play_status.py (PLAY_KEY_PATH, or the default
path in ~/Downloads). It needs *release to testing tracks* and *manage testing
tracks*; it does not need the monetary permissions, which stay closed until a
payments profile exists.

## What it will not do
Promote to production, or touch the closed-testing track's tester list. Both are
console decisions with a 14-day clock attached, and neither should happen as a
side effect of running a script.
"""
import json
import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play_status as ps

API = ps.API
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/"
PKG = ps.PACKAGE

# Deliberately not "production". Promoting is a decision, not a flag.
ALLOWED_TRACKS = ("internal", "alpha", "beta")


def call(url, method="GET", body=None, ctype="application/json"):
    headers = {"Authorization": "Bearer " + ps.token()}
    data = None
    if body is not None:
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        headers["Content-Type"] = ctype
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as e:
        # Play's errors name the field, not the cause; print the body or spend an
        # afternoon guessing which permission is missing.
        sys.stderr.write("HTTP %s on %s %s\n" % (e.code, method, url.split("/v3/")[-1][:80]))
        sys.stderr.write(e.read().decode()[:600] + "\n")
        sys.exit(1)


def promote(code, track):
    eid = call(API + "applications/%s/edits" % PKG, method="POST")["id"]
    call(API + "applications/%s/edits/%s/tracks/%s" % (PKG, eid, track), method="PUT", body={
        "track": track,
        "releases": [{"versionCodes": [str(code)], "status": "completed"}],
    })
    call(API + "applications/%s/edits/%s:commit" % (PKG, eid), method="POST")
    print("track       %s -> %s" % (track, code))
    print("committed   run tools/play_status.py to confirm")


def main():
    if len(sys.argv) < 2:
        sys.stderr.write(__doc__)
        sys.exit(2)

    if sys.argv[1] == "--promote":
        if len(sys.argv) < 4:
            sys.stderr.write("usage: play_upload.py --promote <versionCode> <track>\n")
            sys.exit(2)
        code, track = sys.argv[2], sys.argv[3]
        if track not in ALLOWED_TRACKS:
            sys.stderr.write("track must be one of %s\n" % ", ".join(ALLOWED_TRACKS))
            sys.exit(2)
        promote(code, track)
        return

    aab = sys.argv[1]
    track = sys.argv[2] if len(sys.argv) > 2 else "internal"
    notes = os.environ.get("PLAY_RELEASE_NOTES", "")

    if track not in ALLOWED_TRACKS:
        sys.stderr.write("track must be one of %s (got %r)\n" % (", ".join(ALLOWED_TRACKS), track))
        sys.exit(2)
    if not os.path.exists(aab):
        sys.stderr.write("no such file: %s\n" % aab)
        sys.exit(2)

    edit = call(API + "applications/%s/edits" % PKG, method="POST")
    eid = edit["id"]
    print("edit        %s" % eid)

    blob = open(aab, "rb").read()
    print("uploading   %.1f MB" % (len(blob) / 1e6))
    up = call(
        UPLOAD + "applications/%s/edits/%s/bundles?uploadType=media" % (PKG, eid),
        method="POST", body=blob, ctype="application/octet-stream",
    )
    code = up["versionCode"]
    print("versionCode %s" % code)

    release = {"versionCodes": [str(code)], "status": "completed"}
    if notes:
        release["releaseNotes"] = [{"language": "en-US", "text": notes}]

    call(API + "applications/%s/edits/%s/tracks/%s" % (PKG, eid, track),
         method="PUT", body={"track": track, "releases": [release]})
    print("track       %s -> %s" % (track, code))

    call(API + "applications/%s/edits/%s:commit" % (PKG, eid), method="POST")
    print("committed   run tools/play_status.py to confirm")


if __name__ == "__main__":
    main()
