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
  * Categories -- Productivity, then Utilities. These were never set, and an app with no
    category cannot be submitted at all
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

# Must match MARKETING_VERSION in project.yml and the version record in ASC. A build
# whose CFBundleShortVersionString does not match an *open* version cannot be uploaded:
# once 1.0.0 went READY_FOR_SALE, every build still stamped 1.0.0 was refused, and the
# failure only shows up after the archive and the signing have both succeeded.
VERSION_STRING = "1.0.4"

# Productivity, because that is the shelf this competes on and the one docs/LAUNCH.md
# already priced against. Utilities second: an alarm is a utility, and the obvious
# alternative -- Health & Fitness -- is the one category this app must stay out of, since
# sitting there invites the health claim the store copy is forbidden from making.
PRIMARY_CATEGORY = "PRODUCTIVITY"
SECONDARY_CATEGORY = "UTILITIES"
RELEASE_TYPE = "MANUAL"
CONTENT_RIGHTS = "DOES_NOT_USE_THIRD_PARTY_CONTENT"

CONTACT_FIRST = os.environ.get("ASC_CONTACT_FIRST", "Kivanc")
CONTACT_LAST = os.environ.get("ASC_CONTACT_LAST", "Karahasan")
CONTACT_EMAIL = os.environ.get("ASC_CONTACT_EMAIL", "info@kivanckarahasan.pro")

# What App Review reads before touching the app, and the reason 1.0.0 was rejected the
# first time: Guideline 2.1, Information Needed. The old note explained how to test and
# nothing else. Review asks seven things -- a recording, the devices it was tested on, what
# the app is for, how to reach every feature, which external services it depends on,
# whether behaviour varies by region, and whether any of it is regulated or licensed -- and
# a note that answers six of them still comes back. So this answers all seven, numbered the
# way they were asked, because a reviewer looking for item 5 should not have to read prose
# to find it.
#
# Kept identical to docs/STORE.md. Two things earn their space: that dismissing on purpose
# is the feature (otherwise the alarm returning IS the bug they were about to report), and
# Rehearse, which shows the whole mechanic in a minute instead of asking someone to wait
# two and then wait again.
#
# App Store Connect caps this field at 4000 characters.
REVIEW_NOTES = """Nagg is an alarm you have to prove yourself to. Answering the review questions in order.

1. SCREEN RECORDING
A full recording is available on request. The rehearsal in section 4 reproduces the whole
mechanic on the device in under a minute -- ringing in Silent, returning after Dismiss, and
clearing on proof.

2. DEVICES AND OS TESTED
iPhone 14 Pro Max, iOS 26.6 (physical device). Silent/Focus behaviour, the alarm chain, the
camera proof and a sandbox purchase were verified on it.

3. WHAT IT DOES, AND FOR WHOM
For people who miss deadlines they set themselves, students above all. The problem is
starting, not waking: an ordinary reminder is swiped away in one gesture, so the task
slides another day. You commit to a task and a time. At that time the
alarm rings through Silent and Focus, and the only way to silence it for good is to prove
you started -- a photo of your desk, a 25-minute focus timer, or scanning a QR "desk code"
you print and tape to your desk. Dismissing without proof reschedules up to five times,
then stops. The value is a commitment device that asks for evidence, and a streak that only
counts days you actually began.

4. SETUP AND ACCESS TO EVERY FEATURE
No account, no login, no demo credentials, no sample files. Nothing is stored off-device.

FASTEST PATH: a built-in rehearsal replays the whole mechanic in about a minute (rings
after 20s, nags 30s apart) instead of waiting for a real alarm. It asks which proof type to
demonstrate. Rehearsals do not affect streaks or the excuse count.

It moves once the list is no longer empty, so it is in two places:
* No commitments yet: the button at the bottom of the main screen, "Try it now".
* Always, including after creating one: press and hold the "nagg" wordmark, then
  "Test the alarm now". Use this route if the button is not on screen.

The real thing, if you prefer:
a. Tap + and create a commitment two minutes out. Pick a proof type.
b. Put the device in Silent mode and turn on any Focus.
c. It rings full screen and audible. This is AlarmKit, the framework behind Apple's own
   Clock app; ringing through Silent and Focus is the system's intended behaviour.
d. Tap Dismiss WITHOUT proving. It returns in two minutes. This is the feature, not a bug,
   and it is capped at five returns before stopping on its own.
e. Tap "I'm starting" for the proof screen. Any photo of a desk clears it; the image is
   checked on device and discarded immediately.
f. Diagnostics: the same wordmark long-press also shows permissions, camera availability
   and how many alarms are in the chain.

WHERE THE TWO PRO FEATURES ARE (both reported as not found in review 25):
* Weekly report -- tap the streak / today / excuses strip under the header. It now carries
  a "report" label and chevron at its right edge.
* Unlimited commitments -- free limit is two. Create two, tap + again: the paywall opens
  instead of the editor.

SUBSCRIPTION: free for two commitments; a third opens the paywall. Nagg Pro Monthly and
Nagg Pro Annual, each with a 3-day free trial, each showing title, duration and price beside
links to the Terms and privacy policy. Apple handles payment.

PERMISSIONS: Alarms (AlarmKit), so a commitment can ring through Silent and Focus; this is
the whole product. Camera, only to photograph a desk or scan a desk code as proof. Photo
library, only as a fallback when no camera is available.

5. EXTERNAL SERVICES
RevenueCat, for subscription state only: an anonymous device-generated identifier plus the
receipt Apple issues -- never a name, email, commitment or photo. StoreKit handles payment.
No backend, no analytics or advertising SDK, no AI service, no third-party sign-in.
Commitments, streaks and proof never leave the device.

6. REGIONAL DIFFERENCES
None. Identical in every storefront, English only, Apple's regional pricing.

7. REGULATED INDUSTRY
Neither. A personal productivity app with no third-party or licensed material, no medical
claims, not directed at children."""

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
    # Apple added these six in the 2025 questionnaire and rejects the PATCH without them.
    # All false, and two of them are the same decision made elsewhere: no advertising SDK
    # of any kind, and no health or wellness content -- the app is about starting a task,
    # and calling it a wellness tool is the first step toward a claim it cannot make.
    "advertising": False,
    "parentalControls": False,
    "healthOrWellnessTopics": False,
    "ageAssurance": False,
    "messagingAndChat": False,
    "userGeneratedContent": False,
    # Added by Apple in August 2026 and, per the banner, required immediately for a new app
    # rather than in September. Both false and not a close call: Nagg has no profiles, no
    # feed, no way to reach another person, and nothing leaves the device. The commitment
    # you make is between you and an alarm.
    "socialMedia": False,
    "socialMediaAgeRestricted": False,
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


def categories(info_id):
    """Read them with `include`; without it the relationship comes back with no data key
    and every category looks unset, which is a convincing way to fix the same thing twice."""
    info = call("v1/appInfos/%s?include=primaryCategory,secondaryCategory" % info_id)
    found = [i["id"] for i in info.get("included", [])]
    return found


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
    print("categories      %s" % (", ".join(categories(_info["id"])) or "NOT SET"))
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

    call("v1/appInfos/%s" % _info["id"], "PATCH",
         {"data": {"type": "appInfos", "id": _info["id"], "relationships": {
             "primaryCategory": {"data": {"type": "appCategories",
                                          "id": PRIMARY_CATEGORY}},
             "secondaryCategory": {"data": {"type": "appCategories",
                                            "id": SECONDARY_CATEGORY}}}}})
    print("categories      %s, %s" % (PRIMARY_CATEGORY, SECONDARY_CATEGORY))

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
