# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Dots**, a daily self-reflection iOS app built with SwiftUI. Users answer customizable questions each day and track their responses over time with charts and summaries.

## Key Architecture

- **Single-file SwiftUI app**: Nearly all code in `Dots/Dots/ContentView.swift` (553 lines)
- **MVVM pattern**: `DailyQuestionsViewModel` manages state, SwiftUI views handle UI
- **UserDefaults persistence**: Questions stored as `"questions"`, daily answers as `"answers_[date]"`
- **No external dependencies**: Pure SwiftUI + Foundation (optional Charts framework)

## Development Commands

```bash
# Open project in Xcode
open Dots/Dots.xcodeproj

# Build from command line
xcodebuild -project Dots/Dots.xcodeproj -scheme Dots build

# Run on iOS Simulator
xcodebuild -project Dots/Dots.xcodeproj -scheme Dots -destination 'platform=iOS Simulator,name=iPhone 15' test
```

## Core Components

- **TabView**: 3 tabs (Questions, Summary, Edit)
- **Question Types**: Yes/No, Slider (1-10), Free Text (Yes/No + optional description)
- **Data Models**: `Question`, `Answer`, `QuestionType` structs
- **Charts**: Conditional Swift Charts usage with fallback bars

## Data Flow & State

- **Today calculation**: `var today: Date { Calendar.current.startOfDay(for: Date()) }` (computed property to avoid stale dates)
- **Answer validation**: Save button disabled until all questions answered
- **Auto-navigation**: Switches to Summary tab after saving
- **Question editing**: Clears today's answers when questions are modified

## Important Patterns

- **Date-based data partitioning**: Each day's answers stored separately by date
- **Conditional compilation**: `#if canImport(Charts)` for chart availability
- **Default questions**: 5 pre-configured reflection questions on first launch
- **Universal app**: Supports both iPhone and iPad

## Testing & Quality

Currently no test files exist. When adding tests, focus on:
- ViewModel business logic (date handling, answer validation)
- Data persistence (UserDefaults encoding/decoding)
- UI state transitions

## Common Issues

- **Stale date bug**: The `today` property was changed from `let` to `var` (computed) to prevent yesterdays data showing when app stays in memory across date boundaries