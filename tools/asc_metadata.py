"""Fill the App Store Connect fields that block submission, from the answers in docs.

## Why this is a script and not a panel session
The answers are decisions, not preferences: the age rating questions bind what the store
copy is allowed to say, and getting one wrong changes the rating. They are written down in
docs/ASC-FORMS.md with the reasoning attached. Typing them into a web form once means the
next person -- or the next version, or the resubmission after a rejection -- retypes them
from memory and drifts. Running this means the panel matches the document by construction.

It also reads the state first. Half of what blocks a submission is invisible in the panel
until you try to submit and get a list of errors, so `--check` prints what is missing while
there is still time to fix it.

## What it sets
  * Age rating declaration -- every question, from docs/ASC-FORMS.md
  * Content rights -- the app contains no third-party content
  * Release type -- MANUAL, because approval day and launch day are different days
    (docs/LAUNCH.md section 5)
  * Version string -- 1.0.0, matching the builds already in TestFlight. The record was
    created as "1.0" and a build can only attach to a version whose number it shares, so
    this mismatch would have blocked the build selector with no explanation.
  * App Review contact and notes -- the demo instructions from docs/STORE.md

## What it cannot set
The App Privacy nutrition label. Those endpoints are not in the API at this version
(appDataUsages returns 404 for this app), so that form stays a panel job. The answers are
in docs/ASC-FORMS.md section 2.

## Use
    python tools/asc_metadata.py --check
    python tools/asc_metadata.py --apply --phone "+90..."

Needs the ASC API key. Either ASC_KEY_PATH pointing at the .p8, or ASC_KEY_CONTENT with
its base64. The key must have the Admin role: App Manager cannot write the age rating.
"""
import argparse
import base64
import json
import os
import time
import urllib.error
import urllib.request

import jwt

KEY_ID = os.environ.get("ASC_KEY_ID", "JJCLLBWGL7")
ISSUER = os.environ.get("ASC_ISSUER_ID", "d4d406a9-3332-497e-a260-bd47ac37270d")
APP_ID = os.environ.get("ASC_APP_ID", "6802195603")
API = "https://api.appstoreconnect.apple.com/"

VERSION_STRING = "1.0.0"
RELEASE_TYPE = "MANUAL"
CONTENT_RIGHTS = "DOES_NOT_USE_THIRD_PARTY_CONTENT"

CONTACT_FIRST = os.environ.get("ASC_CONTACT_FIRST", "Kivanc")
CONTACT_LAST = os.environ.get("ASC_CONTACT_LAST", "Karahasan")
CONTACT_EMAIL = os.environ.get("ASC_CONTACT_EMAIL", "info@kivanckarahasan.pro")

# The demo instructions App Review reads. Kept identical to docs/STORE.md: the reviewer
# needs to be told that dismissing on purpose is the feature, or the alarm coming back
# looks like the bug they are supposed to report.
REVIEW_NOTES = """Nagg schedules alarms with AlarmKit. To test:
1. Create a commitment set 2 minutes from now
2. Put the device in Silent mode and enable a Focus
3. The alarm will fire full screen
4. Tapping "Dismiss" without providing proof reschedules the alarm once, after 2 minutes
   (capped at 5 repeats)
5. Tapping "I'm starting" opens the proof screen; any photo of a desk clears the alarm

Demo account is not required. All data is stored on device."""

# Every answer here is "none" or "no", which is the whole point: the ones worth reading are
# the three that are decisions rather than observations, and each is argued in
# docs/ASC-FORMS.md. Horror is NONE because an alarm that returns is persistence, not fear.
# Medical is false because no store text may mention ADHD, therapy or treatment. Web access
# is false because the only outward links are two fixed nagg.pro pages on the paywall.
AGE_RATING = {
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gamblingSimulated": "NONE",
    "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "gambling": False,
    "unrestrictedWebAccess": False,
    "lootBox": False,
}


def token() -> str:
    if os.environ.get("ASC_KEY_CONTENT"):
        key = base64.b64decode(os.environ["ASC_KEY_CONTENT"]).decode()
    else:
        path = os.environ.get(
            "ASC_KEY_PATH",
            os.path.expanduser("~/Downloads/AuthKey_%s.p8" % KEY_ID),
        )
        key = open(path).read()
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"},
    )


def call(path, method="GET", body=None):
    url = path if path.startswith("http") else API + path.lstrip("/")
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": "Bearer " + token()}
    if data:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, method=method, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            payload = response.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        try:
            detail = "\n".join(
                "  %s: %s" % (e.get("title"), e.get("detail"))
                for e in json.loads(detail)["errors"]
            )
        except Exception:
            pass
        raise SystemExit("HTTP %s %s %s\n%s" % (error.code, method, url, detail))


def context():
    """The three ids everything else hangs off, looked up rather than pasted."""
    version = call("v1/apps/%s/appStoreVersions?limit=1" % APP_ID)["data"][0]
    info = call("v1/apps/%s/appInfos?limit=1" % APP_ID)["data"][0]
    declaration = call("v1/appInfos/%s/ageRatingDeclaration" % info["id"])["data"]
    return version, info, declaration


def check():
    app = call("v1/apps/%s" % APP_ID)["data"]["attributes"]
    version, _info, declaration = context()
    attrs = version["attributes"]
    answered = sum(1 for v in declaration["attributes"].values() if v is not None)

    print("app             %s (%s)" % (app["name"], app["bundleId"]))
    print("version         %s  %s  release=%s"
          % (attrs["versionString"], attrs["appStoreState"], attrs["releaseType"]))
    print("content rights  %s" % (app["contentRightsDeclaration"] or "NOT SET"))
    print("age rating      %d answers set (needs %d)" % (answered, len(AGE_RATING) + 3))

    detail = call("v1/appStoreVersions/%s/appStoreReviewDetail" % version["id"]).get("data")
    print("review detail   %s" % ("set" if detail else "NOT SET"))

    build = call("v1/appStoreVersions/%s/build" % version["id"]).get("data")
    print("build attached  %s" % (build["id"] if build else "none"))

    builds = call("v1/builds?filter[app]=%s&limit=3&sort=-uploadedDate" % APP_ID)["data"]
    for b in builds[:3]:
        print("  testflight    build %s  %s  %s"
              % (b["attributes"]["version"], b["attributes"]["processingState"],
                 b["attributes"]["uploadedDate"]))

    for group in call("v1/apps/%s/subscriptionGroups" % APP_ID)["data"]:
        for sub in call("v1/subscriptionGroups/%s/subscriptions" % group["id"])["data"]:
            shot = call("v1/subscriptions/%s/appStoreReviewScreenshot"
                        % sub["id"]).get("data")
            print("subscription    %s  %s  screenshot=%s"
                  % (sub["attributes"]["productId"], sub["attributes"]["state"],
                     "yes" if shot else "NO"))

    print("\nApp Privacy label is not in this API version -- panel only, "
          "answers in docs/ASC-FORMS.md section 2.")


def apply(phone: str):
    version, _info, declaration = context()
    version_id, declaration_id = version["id"], declaration["id"]

    call("v1/ageRatingDeclarations/%s" % declaration_id, "PATCH",
         {"data": {"type": "ageRatingDeclarations", "id": declaration_id,
                   "attributes": AGE_RATING}})
    print("age rating      set")

    call("v1/apps/%s" % APP_ID, "PATCH",
         {"data": {"type": "apps", "id": APP_ID,
                   "attributes": {"contentRightsDeclaration": CONTENT_RIGHTS}}})
    print("content rights  %s" % CONTENT_RIGHTS)

    call("v1/appStoreVersions/%s" % version_id, "PATCH",
         {"data": {"type": "appStoreVersions", "id": version_id,
                   "attributes": {"versionString": VERSION_STRING,
                                  "releaseType": RELEASE_TYPE}}})
    print("version         %s, release %s" % (VERSION_STRING, RELEASE_TYPE))

    detail = call("v1/appStoreVersions/%s/appStoreReviewDetail" % version_id).get("data")
    payload = {
        "contactFirstName": CONTACT_FIRST,
        "contactLastName": CONTACT_LAST,
        "contactPhone": phone,
        "contactEmail": CONTACT_EMAIL,
        "demoAccountRequired": False,
        "notes": REVIEW_NOTES,
    }
    if detail:
        call("v1/appStoreReviewDetails/%s" % detail["id"], "PATCH",
             {"data": {"type": "appStoreReviewDetails", "id": detail["id"],
                       "attributes": payload}})
    else:
        call("v1/appStoreReviewDetails", "POST",
             {"data": {"type": "appStoreReviewDetails", "attributes": payload,
                       "relationships": {"appStoreVersion": {"data": {
                           "type": "appStoreVersions", "id": version_id}}}}})
    print("review detail   set")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="report the state and change nothing (the default)")
    parser.add_argument("--apply", action="store_true",
                        help="write the fields; without it nothing is changed")
    parser.add_argument("--phone", help="App Review contact phone, required by Apple")
    args = parser.parse_args()

    if not args.apply:
        check()
        return
    if not args.phone:
        raise SystemExit("--phone is required: App Review will not accept a blank contact")
    apply(args.phone)
    print()
    check()


if __name__ == "__main__":
    main()
