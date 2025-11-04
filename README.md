## ReadRight

ReadRight is a Flutter mobile app that helps children practice reading words aloud, receive pronunciation feedback, and track progress over time. The current milestone focuses on getting the core student experience working end-to-end with mock backends.

## Current Milestone Highlights

- **Authentication with roles** – Students and teachers sign in with demo accounts. Session state is persisted with `SharedPreferences` so reopening the app restores the previous login.
- **Seed word lists** – Dolch and Phonics lists (plus optional Minimal Pairs) load from `assets/seed_words.csv`, with 2–3 sample sentences per word for practice context.
- **Practice flow with live STT** – Students see the next unmastered word, record up to 7 s, and get real speech-to-text transcription using the `speech_to_text` plugin. A Levenshtein-based scorer compares the transcript to the target word and provides feedback. Correct attempts mark the word as mastered and progress to the next list; mastery is stored per user in `SharedPreferences`.
- **Attempt provider** – `AttemptController` + `MockAttemptRepository` expose a shared in-memory history with transcripts, scores, accuracy, and durations for future teacher reporting.
- **Progress screen** – Displays total attempts, average score, a simple bar chart of recent attempts, and a list view backed by the shared provider.

## Project Structure

```
lib/
├── main.dart                  # Providers, navigation
├── login_screen.dart          # Student/teacher sign in & account card
├── practice_screen.dart       # Word practice loop with STT + mastery logic
├── progress_screen.dart       # Aggregate stats + chart
├── word_list_screen.dart      # Word lists sourced from CSV assets
├── word_detail_screen.dart    # Expandable word sentences
├── feedback_screen.dart       # Placeholder for richer feedback
├── teacher_dashboard_screen.dart # Placeholder for teacher view
├── models/
│   ├── attempt_model.dart     # Attempt data shape
│   └── word_model.dart        # Word + CSV parsing helpers
└── services/
    ├── auth_service.dart      # Auth controller + mock repo
    ├── attempt_repository.dart # Attempt controller + mock repo
    └── pronunciation_service.dart # Mock assessor (kept for future swaps)
```

### Demo Accounts

- Student: `student@readright.app` / `student123`
- Teacher: `teacher@readright.app` / `teacher123`

## Testing & Tooling

- Static analysis: `flutter analyze`
- Widget tests: `flutter test`

## Permissions

- **Microphone** is required to capture pronunciation attempts.
- **Speech Recognition** (iOS) is required for on-device STT using `speech_to_text`.

## Notes & Next Steps

- Attempts are held in memory; persistence per student will come in a future milestone.
- The practice flow uses the system STT engine plus a Levenshtein scorer; swapping in a cloud or custom provider only requires implementing `PronunciationAssessor`.
- Teacher dashboard and richer analytics are placeholders pending later milestones.
