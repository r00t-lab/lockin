# Play production access application

Google gates production behind a form, not a button. Once the closed test has run
12 testers × 14 continuous days, **Üretime başvur** unlocks on the app dashboard
and asks a short set of questions about the testing period. This file is the
answers, written while the facts were still fresh.

As of 4 Sep 2026 the counter read *"12 test kullanıcısı kesintisiz olarak 13
gündür kayıtlı"* — one day short. Nothing to submit until it reads 14.

## What the reviewers are checking

They are looking for evidence the closed test was real: that testers were people
who could actually give feedback, that feedback arrived, and that it changed the
app. A form that says "I tested it and it works" is what gets rejected.

## Answers

**How did you recruit your testers?**

> Directly, from people who have the problem the app is about: fellow first-year
> university students who had told me they keep putting off work they had planned
> to start. 16 are enrolled. I did not use a tester-exchange group or a paid
> service — everyone in the test knows me and had a reason to want the app to
> work.

**What feedback did you receive?**

> ⚠️ FILL THIS IN YOURSELF. Write what testers actually told you, in their words
> where you can. Do not let me draft it — I was not in those conversations, and
> inventing tester quotes on a Google form is the one thing here that could cost
> the account rather than a week.
>
> If the honest answer is that little came back, say so and describe what you
> found yourself while testing on device. That is a weaker answer than real
> quotes but it is a true one, and reviewers see far more fabricated feedback
> than thin feedback.

**How did you use the feedback to improve your app?**

Real changes made during the closed test, all verifiable in the repo:

> - **The paywall was a door with nothing behind it.** The free tier stops at two
>   commitments, but the Play products were not live, so the paywall opened with
>   nothing on it. A tester who created two commitments could neither add a third
>   nor pay to. Fixed by making the gate aware of whether anything is actually on
>   sale, and covered by five tests so it cannot come back. (`0672895`)
> - **The price did not say what you were buying.** The paywall showed an amount
>   with no billing period next to it. Now it prints /month and /year. (`9c02b1b`)
> - **The paywall advertised a feature that does not exist yet** — syllabus
>   import, planned for a later release. Removed. (`d88f31d`)
> - **Billing library update.** Moved to a RevenueCat version that ships Play
>   Billing 8, ahead of the deadline rather than after it. (`bc20c5a`)
> - **A streak test had been green for a year by never running.** Android tests
>   were not wired into CI. They are now, and the first honest run found a real
>   timezone bug in how a commitment's fire time is resolved. (`8840cae`)
> - **The app now keeps a day-by-day record** of days started and alarms let run
>   out, instead of only a running total — added deliberately before production,
>   because a day that is never written down cannot be recovered afterwards.
>   Fixing that also closed a silent data-loss path: a save could previously
>   overwrite a file the app had failed to read. (`97f94b7`)

**What does the app do?** (asked in some variants of the form)

> Nagg is an alarm you have to prove yourself to. You name a thing you keep
> putting off and a time you will start it. At that time the alarm rings, and
> dismissing it does not end it — it returns, up to five times. The only way to
> stop it is evidence that you started: a photo of your desk, a 25-minute focus
> timer, or scanning a QR code you print and tape to the desk you are meant to be
> at. It keeps a streak of the days you actually began and a count of the alarms
> you let run out. No account, no server; nothing leaves the device.

## After it is approved

Publish **versionCode 63**, not 54. 54 is what the testers have had; 63 adds the
day record, the data-loss guard and the tests above. Both are on the internal and
closed tracks already, so it is a promote, not an upload.

Release note:

> Nagg now keeps a day-by-day record of the days you started and the alarms you
> let run out.
