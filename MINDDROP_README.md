# MindDrop 🎙️

Capture a thought with one press of the Action Button. MindDrop records your
voice, transcribes it with Google Gemini (which understands audio natively),
and uses Gemini or Claude to turn the rambling into a titled, summarized,
categorized note with action items — stored locally
with SwiftData.

**Requires iOS 18+ / Xcode 16+.**

## Features

- **One-press capture** — `CaptureThoughtIntent` (AppIntents) toggles recording,
  so it can be assigned to the Action Button or triggered via Siri/Shortcuts.
- **High-quality audio** — AAC/M4A at 48 kHz via `AVAudioRecorder`, with the
  audio session configured for Bluetooth mics (AirPods) using
  `.allowBluetoothHFP`.
- **AI pipeline** — the M4A goes straight to Gemini (`gemini-2.5-flash`), which
  transcribes it. Extraction of `title`, `summary`, `category`, `action_items`
  (as JSON) runs on your choice of Gemini (single call — audio in, structured
  note out) or Claude (`claude-opus-5` via the Anthropic Messages API).
- **Offline-safe** — if the network or API fails, the recording is kept and
  saved as an "Unprocessed thought" you can retry later.
- **Organized your way** — group notes by day, topic (category), or folder;
  notes stay time-sorted inside every group. Long-press a card to file it into
  a folder (or create one on the spot). Search covers title, summary,
  transcript, category, and folder name.
- **Playback & sharing** — replay the original recording from an expanded
  card, or share a note (title, summary, action items) as text via the
  system share sheet.
- **"Aurora" dark UI, themeable** — near-black with violet/amber ambient
  glows, warm amber record button, teal metadata, glassy separated cards.
  All colors live in `Theme/Theme.swift` as design tokens; swap or edit a
  palette there (the original mint `midnight` look is kept as an alternate).

## Project layout

```
MindDrop/
├── App/MindDropApp.swift              # App entry, SwiftData container
├── Models/
│   ├── Note.swift                     # SwiftData @Model
│   └── Folder.swift                   # User folders (SwiftData)
├── Theme/Theme.swift                  # Design tokens (colors, palettes)
├── Services/
│   ├── AudioService.swift             # AVAudioRecorder + AVAudioSession
│   ├── APIService.swift               # Gemini transcription + Gemini/Claude extraction
│   ├── PlaybackService.swift          # Replay a note's original audio
│   └── CaptureCoordinator.swift       # record → transcribe → extract → save
├── Intents/CaptureThoughtIntent.swift # AppIntent + AppShortcutsProvider
└── Views/
    ├── NotesListView.swift            # Grouped list, search, record button
    ├── NoteCardView.swift             # Expanding card
    └── SettingsView.swift             # API keys + extraction model picker
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

1. Launch the app, open **Settings (gear icon)** and paste your Gemini API key
   (from aistudio.google.com/apikey). Optionally pick Claude for extraction and
   add an Anthropic API key.
2. Assign the intent to the Action Button:
   **Settings → Action Button → Shortcut → MindDrop → Capture Thought**.
3. Press the Action Button to start recording; press again to stop.
   The processed note appears in the list a few seconds later.

## Notes on design decisions

- The App Intent uses `openAppWhenRun = true` so the microphone session runs in
  the foregrounded app — the most reliable way to record from an intent. The
  `audio` background mode keeps an in-progress recording alive if the user
  switches away mid-thought.
- API keys are stored in the iOS Keychain (see `KeychainStore.swift`) and the app talks
  to Google/Anthropic directly; for a production app, proxy these calls through
  your own backend instead of shipping user-provided keys.
- Gemini handles transcription because it accepts audio directly — no separate
  speech-to-text service is needed. The Claude API is text-only, so when Claude
  is selected it runs the extraction step on Gemini's transcript.
