# TailyDose App Store Submission Checklist

## Repo-side

- Final privacy policy added
- Final terms of use added
- Support page added
- Placeholder legal copy removed from the paywall
- Debug-only Pro unlock remains scoped to `#if DEBUG`
- Screenshot/demo seed remains scoped to screenshot mode only

## App Store Connect

- Add Privacy Policy URL
- Add Support URL
- Complete App Privacy questionnaire
- Verify subscription products are approved and selectable for review
- Verify the annual trial matches App Store Connect configuration
- Add screenshots and marketing copy
- Add review notes describing how Pro features are tested

## Final Validation

- Archive a Release build
- Test purchase, restore, and paywall flows in TestFlight
- Test notification permission flow on device
- Test export/share flow on device
