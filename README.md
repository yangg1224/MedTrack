# MedTrack

An iOS app that helps elderly users track their daily medications and receive push notifications when it's time to take a dose.

## Features

- **Add medications** — name, dosage, unit, and one or more daily schedule times
- **Today checklist** — see all doses for the day, mark each one as taken
- **Push notifications** — local reminders fire at each scheduled time
- **Adherence history** — view a per-day log of taken vs. missed doses with a color-coded percentage

## Screenshots

| Today | My Meds | History |
|---|---|---|
| Daily dose checklist | Add & manage medications | Adherence log |

## Tech Stack

| | |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Storage | SwiftData (local, no backend) |
| Notifications | UserNotifications framework |
| Minimum iOS | 17.0 |

## Project Structure

```
MedTrack/
├── Models/
│   ├── Medication.swift          # Medication definition (name, dosage, schedule)
│   └── DoseRecord.swift          # Per-dose record (pending / taken / missed)
├── ViewModels/
│   ├── MedicationStore.swift     # CRUD + notification sync
│   ├── TodayViewModel.swift      # Generate today's records, reconcile missed doses
│   └── HistoryViewModel.swift    # Adherence stats grouped by day
├── Views/
│   ├── Today/                    # Daily checklist tab
│   ├── Medications/              # Medication list + add/edit form
│   └── History/                  # Adherence history tab
├── Notifications/
│   └── NotificationManager.swift # Schedule & cancel local notifications
└── Utilities/
    ├── DateHelpers.swift
    └── AccessibilityConstants.swift
```

## Getting Started

### Requirements

- macOS 14+
- Xcode 16+
- iOS 17.0+ simulator or device

### Run the app

1. Clone the repo
   ```bash
   git clone https://github.com/yangg1224/MedTrack.git
   cd MedTrack
   ```

2. Open in Xcode
   ```bash
   open MedTrack.xcodeproj
   ```

3. Select an iPhone simulator (iOS 17+) and press **Run** (`⌘R`)

### Or generate the project with XcodeGen

```bash
brew install xcodegen
xcodegen generate
open MedTrack.xcodeproj
```

## Accessibility

Designed with elderly users in mind:

- Minimum font size `.title3` throughout — no small text
- All interactive rows have a minimum height of 60 pt
- Full VoiceOver support with labels and hints on every control
- Notification permission denied banner with a direct link to Settings

## How Missed Doses Work

The app uses **lazy on-open reconciliation** instead of unreliable background tasks. Every time the app comes to the foreground it:

1. Creates dose records for today's schedule (idempotent)
2. Marks any pending dose whose scheduled time + 1 hour has passed as **missed**

This gives a 1-hour grace period after each notification fires before a dose is counted as missed.

## License

MIT
