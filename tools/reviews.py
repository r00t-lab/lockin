"""What people are actually saying, in one place.

App Store Connect shows reviews one storefront at a time behind a territory picker,
which is fine when there are hundreds and useless when you are waiting for the first
one. This prints every review across every territory, newest first, plus the public
rating counts the store shows shoppers.

    python tools/reviews.py              # everything
    python tools/reviews.py --unanswered # only the ones with no reply yet

Reads the same key as asc_metadata.py.
"""

import argparse
import base64
import collections
import importlib.util
import json
import os
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("asc", os.path.join(HERE, "asc_metadata.py"))
asc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(asc)

# The storefronts worth checking first. The API returns every territory anyway; this is
# only the order things get printed in when nothing else distinguishes them.
STOREFRONTS = ["us", "gb", "ca", "au", "de", "tr"]


def public_ratings():
    """What a shopper sees. Not in the ASC API -- this is the same lookup the store uses."""
    out = []
    for cc in STOREFRONTS:
        url = "https://itunes.apple.com/lookup?id=%s&country=%s" % (asc.APP_ID, cc)
        try:
            with urllib.request.urlopen(url, timeout=20) as r:
                results = json.load(r).get("results") or []
        except Exception as exc:
            out.append((cc, "sorgulanamadi: %s" % exc))
            continue
        if not results:
            out.append((cc, "listede yok"))
            continue
        d = results[0]
        out.append((cc, "%s yildiz, %s oy  (bu surum: %s oy)" % (
            d.get("averageUserRating") or 0,
            d.get("userRatingCount") or 0,
            d.get("userRatingCountForCurrentVersion") or 0)))
    return out


def reviews(unanswered_only=False):
    got, cursor = [], None
    while True:
        path = "v1/apps/%s/customerReviews?limit=200&sort=-createdDate&include=response" % asc.APP_ID
        if cursor:
            path += "&cursor=" + cursor
        page = asc.call(path)
        answered = {
            r["relationships"]["review"]["data"]["id"]
            for r in page.get("included", [])
            if r.get("type") == "customerReviewResponses"
            and r.get("relationships", {}).get("review", {}).get("data")
        }
        for x in page.get("data", []):
            if unanswered_only and x["id"] in answered:
                continue
            a = x["attributes"]
            got.append({
                "rating": a.get("rating"),
                "title": a.get("title") or "",
                "body": (a.get("body") or "").replace("\n", " "),
                "who": a.get("reviewerNickname") or "",
                "when": (a.get("createdDate") or "")[:10],
                "where": a.get("territory") or "",
                "answered": x["id"] in answered,
            })
        cursor = (page.get("links", {}).get("next") or "").split("cursor=")[-1] if page.get("links", {}).get("next") else None
        if not cursor:
            break
    return got


def territories():
    """Which storefronts actually list the app, and why the rest do not.

    Worth a line of its own because a blocked territory is invisible from the outside:
    the app still reads as "available" in App Store Connect, it simply is not in the
    store. That is how all 27 EU storefronts went missing without a single error.
    """
    d = asc.call("v1/apps/%s/appAvailabilityV2?include=territoryAvailabilities"
                 "&limit[territoryAvailabilities]=50" % asc.APP_ID)
    buckets, cursor = collections.defaultdict(list), None
    while True:
        path = "v2/appAvailabilities/%s/territoryAvailabilities?limit=50" % d["data"]["id"]
        if cursor:
            path += "&cursor=" + cursor
        page = asc.call(path)
        for x in page["data"]:
            try:
                where = json.loads(base64.b64decode(x["id"] + "=="))["t"]
            except Exception:
                where = x["id"][:8]
            buckets[",".join(x["attributes"].get("contentStatuses") or ["?"])].append(where)
        nxt = page.get("links", {}).get("next")
        if not nxt:
            break
        cursor = nxt.split("cursor=")[-1].split("&")[0]
    return buckets


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--unanswered", action="store_true", help="only reviews with no reply")
    args = p.parse_args()

    print("=== bolgeler ===")
    for status, places in sorted(territories().items(), key=lambda kv: -len(kv[1])):
        print("  %-38s %3d" % (status, len(places)))
        if status != "AVAILABLE":
            print("      " + " ".join(sorted(places)))
    print()
    print("=== magazada gorunen puan ===")
    for cc, line in public_ratings():
        print("  %-3s %s" % (cc.upper(), line))

    rs = reviews(args.unanswered)
    print()
    print("=== yorumlar (%d) ===" % len(rs))
    if not rs:
        print("  henuz yok")
        return
    for r in rs:
        flag = "" if r["answered"] else "  [YANITSIZ]"
        print("  %s %s  %-2s  %s%s" % (r["when"], (r["where"] or "??")[:3], "%s*" % r["rating"], r["title"][:60], flag))
        if r["body"]:
            print("      %s" % r["body"][:160])
        print("      -- %s" % r["who"])


if __name__ == "__main__":
    main()
