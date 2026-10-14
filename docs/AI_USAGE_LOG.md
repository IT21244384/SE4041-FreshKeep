# AI-Assisted Development Log

The assignment brief allows AI tools as long as the interactions are documented. This log
records how **Claude (Anthropic, via Claude Code)** was used on FreshKeep: the prompts,
what the AI produced, and what I checked, changed or decided myself.

| # | Date | Prompt (summary / verbatim) | AI response / output | How it was used & verified |
|---|---|---|---|---|
| 1 | 2026-10-14 | "Install all the development environment and help me to complete the project … proposal document, UI documentation, use Figma to create the UI, and a final report." (with the assignment PDF attached) | Read the brief. Explained that Xcode only runs on macOS and proposed writing code on Windows, building/testing on GitHub Actions macOS runners, and borrowing a Mac for the viva. Asked me to choose the app idea, Part B platform and scope. | I chose: food freshness scanner (CoreML/Vision), visionOS for Part B, full scope, GitHub Actions + Mac for demo, public repo. |
| 2 | 2026-10-14 | (continuation) Build the shared logic first | Generated `FreshKeepCore` package: shelf-life catalog, Vision label → food matcher, best-before date parser, freshness calculator, waste insights, recipe ranking, reminder planner + 33 XCTest cases. | Ran `swift test` locally on Windows: one failing case (31/02/2026 was re-read as "02/2026") exposed a real parser bug, which was fixed so invalid dates are rejected. All 33 tests pass. |
| 3 | 2026-10-14 | (continuation) iOS app, tests, visionOS prototype, CI | Generated SwiftUI views, SwiftData model, Vision services, design system, unit/UI tests, RealityKit prototype, XcodeGen spec and GitHub Actions workflow. | Reviewed each file; compile/test results from CI are recorded in the final report's testing chapter. |

## How AI helped

* **Speed on boilerplate:** asset catalog JSON, XcodeGen spec, CI scripts.
* **Design exploration:** discussed which emerging technology best fits the problem
  (Vision on-device classification + OCR rather than a cloud API, for privacy and offline use).
* **Testing:** suggested edge cases for the date parser (MFD vs EXP, month-only dates,
  impossible dates) that found a real bug.

## Where my own judgement was needed

* Choosing the problem (food waste in Sri Lankan households), target audience and scope.
* Deciding to read dates day-first (local packaging convention) and to price items in LKR.
* Verifying shelf-life values against FoodKeeper guidance and adjusting for a warm climate.
* Testing on a real device and preparing the demo.

> Keep adding rows as development continues (new prompts, fixes after CI runs, Figma work,
> documentation drafts). Paste the exact prompt text where possible.
