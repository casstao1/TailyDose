# TailyDose App Store Connect Values

Last updated: April 22, 2026

## Public URLs

- Privacy Policy URL: `https://casstao1.github.io/TailyDose/privacy-policy.html`
- Support URL: `https://casstao1.github.io/TailyDose/support.html`
- Terms of Use URL: `https://casstao1.github.io/TailyDose/terms-of-use.html`
- Marketing URL (optional): `https://casstao1.github.io/TailyDose/`

If GitHub Pages is not configured to publish from `docs/`, use the GitHub blob URLs instead.

## Suggested App Information

- Name: `TailyDose`
- Subtitle: `Pet medication reminders`
- Primary Category: `Medical`
- Secondary Category: `Utilities`

## Suggested Promotional Text

Track every pet’s medications, reminders, dose history, and vet-ready summaries in one calm place.

## Suggested Description

TailyDose helps you stay on top of pet medications without juggling notes, texts, and memory.

Track medications for multiple pets, schedule reminders, mark doses as taken, skipped, or missed, and keep a clean history you can review anytime. When it’s time for a vet visit, generate a readable medication summary to share.

Features:

- Track medications for multiple pets
- Schedule reminder times for each medication
- Log taken, missed, and skipped doses
- Keep pet notes, weights, vet contacts, and records together
- Share a clean medication summary before appointments
- Unlock push alerts and vet export with TailyDose Pro

TailyDose is an organizational tool for pet care and does not replace veterinary advice.

## Suggested Keywords

`pet meds,pet medication,dog meds,cat meds,pet reminder,medication reminder,vet records,pet care`

## Suggested Review Notes

No account or login is required.

The app stores pet and medication data locally on device.

In-app purchases:

- `com.castao.tailydose.pro.monthly`
- `com.castao.tailydose.pro.yearly`

Pro unlocks:

- push medication alerts
- multiple pets
- vet-ready export and sharing

The annual subscription includes a 7-day free trial when configured in App Store Connect.

## Draft App Privacy Answers

Based on the current codebase, the recommended App Privacy answer is:

- `No, we do not collect data from this app`

Reasoning:

- Pet data is stored locally with SwiftData
- Reminder notifications are scheduled locally
- Camera and photo library access are used only for local images and attachments
- StoreKit handles purchases through Apple
- No analytics, ad SDKs, or remote data collection were found in the app code

Re-check this before submission if you add:

- analytics or crash-reporting SDKs
- remote sync or cloud backup
- web views that transmit user-entered data
- a backend for support, messaging, or accounts

## Permissions Used

- Camera: pet profile photos and care document capture
- Photo Library: attaching vet records and care documents
- Notifications: medication reminders
