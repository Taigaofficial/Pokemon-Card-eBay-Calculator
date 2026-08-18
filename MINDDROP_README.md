# MindDrop 🎙️

Capture a thought with one press of the Action Button. MindDrop records your
voice, transcribes it with OpenAI Whisper, and uses an LLM to turn the rambling
into a titled, summarized, categorized note with action items — stored locally
with SwiftData.

**Requires iOS 18+ / Xcode 16+.**

## Features

- **One-press capture** — `CaptureThoughtIntent` (AppIntents) toggles recording,
  so it can be assigned to the Action Button or triggered via Siri/Shortcuts.
- **High-quality audio** — AAC/M4A at 48 kHz via `AVAudioRecorder`, with the
  audio session configured for Bluetooth mics (AirPods) using
  `.allowBluetoothHFP`.
- **AI pipeline** — audio → Whisper (`whisper-1`) → `gpt-4o-mini` with a JSON
  extraction prompt returning `title`, `summary`, `category`, `action_items`.
- **Offline-safe** — if the network or API fails, the recording is kept and
  saved as an "Unprocessed thought" you can retry later.
- **Minimal dark UI** — notes grouped by day, search across title/summary/
  transcript/category, tap-to-expand cards with action items and raw transcript.

## Project layout

```
MindDrop/
├── App/MindDropApp.swift              # App entry, SwiftData container
├── Models/Note.swift                  # SwiftData @Model
├── Services/
│   ├── AudioService.swift             # AVAudioRecorder + AVAudioSession
│   ├── APIService.swift               # Whisper + LLM extraction
│   └── CaptureCoordinator.swift       # record → transcribe → extract → save
├── Intents/CaptureThoughtIntent.swift # AppIntent + AppShortcutsProvider
└── Views/
    ├── NotesListView.swift            # Grouped list, search, record button
    ├── NoteCardView.swift             # Expanding card
    └── SettingsView.swift             # OpenAI API key entry
```

## Building

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open MindDrop.xcodeproj
```

Then set your signing team and run on a device (the microphone and Action
Button don't exist in the simulator).

## Setup

1. Launch the app, open **Settings (gear icon)** and paste your OpenAI API key.
2. Assign the intent to the Action Button:
   **Settings → Action Button → Shortcut → MindDrop → Capture Thought**.
3. Press the Action Button to start recording; press again to stop.
   The processed note appears in the list a few seconds later.

## Notes on design decisions

- The App Intent uses `openAppWhenRun = true` so the microphone session runs in
  the foregrounded app — the most reliable way to record from an intent. The
  `audio` background mode keeps an in-progress recording alive if the user
  switches away mid-thought.
- The API key is intentionally kept on-device (`@AppStorage`) and the app talks
  to OpenAI directly; for a production app, proxy these calls through your own
  backend instead of shipping user-provided keys.
