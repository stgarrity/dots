//
//  ContentView.swift
//  Dots
//
//  Created by Steve Garrity on 5/15/25.
//

import SwiftUI

// MARK: - Data Models

enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case yesNo
    case slider
    case freeText

    var id: String { rawValue }
}

struct Question: Identifiable, Codable {
    let id: UUID
    var text: String
    var type: QuestionType
}

struct Answer: Identifiable, Codable {
    let id: UUID
    let questionID: UUID
    var date: Date
    var yesNoValue: Bool?
    var sliderValue: Double?
    var freeTextValue: String?
}

// MARK: - ViewModel

class DailyQuestionsViewModel: ObservableObject {
    @Published var questions: [Question] = []
    @Published var answers: [UUID: Answer] = [:] // keyed by questionID

    let today = Calendar.current.startOfDay(for: Date())

    init() {
        loadQuestions()
        loadTodayAnswers()
    }

    func loadQuestions() {
        // For MVP, use hardcoded questions
        questions = [
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "Did I make meaningful progress on something important today?", type: .yesNo),
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, text: "Was I able to finish work without guilt or mental spillover?", type: .yesNo),
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, text: "Did I do at least one thing that energized me outside of work?", type: .freeText),
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, text: "Did I feel present during non-work activities today?", type: .yesNo),
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, text: "Do I feel like I'm pacing myself in a sustainable way?", type: .yesNo)
        ]
    }

    func loadTodayAnswers() {
        // Load from UserDefaults for MVP
        if let data = UserDefaults.standard.data(forKey: "answers_\(today)") {
            if let decoded = try? JSONDecoder().decode([UUID: Answer].self, from: data) {
                answers = decoded
                return
            }
        }
        // If not found, initialize empty answers
        answers = [:]
        for q in questions {
            answers[q.id] = Answer(id: UUID(), questionID: q.id, date: today, yesNoValue: nil, sliderValue: nil, freeTextValue: nil)
        }
    }

    func saveAnswers() {
        if let data = try? JSONEncoder().encode(answers) {
            UserDefaults.standard.set(data, forKey: "answers_\(today)")
        }
    }

    func setYesNo(_ value: Bool, for question: Question) {
        answers[question.id]?.yesNoValue = value
    }

    func setFreeText(_ value: String, for question: Question) {
        answers[question.id]?.freeTextValue = value
    }

    func isComplete() -> Bool {
        for q in questions {
            switch q.type {
            case .yesNo:
                if answers[q.id]?.yesNoValue == nil { return false }
            case .slider:
                if answers[q.id]?.sliderValue == nil { return false }
            case .freeText:
                if (answers[q.id]?.freeTextValue ?? "").isEmpty { return false }
            }
        }
        return true
    }
}

// MARK: - Daily Questions View

struct ContentView: View {
    @StateObject private var vm = DailyQuestionsViewModel()
    @State private var showSaved = false

    var body: some View {
        NavigationView {
            Form {
                ForEach(vm.questions) { question in
                    Section(header: Text(question.text)) {
                        switch question.type {
                        case .yesNo:
                            YesNoQuestionView(answer: Binding(
                                get: { vm.answers[question.id]?.yesNoValue },
                                set: { vm.setYesNo($0 ?? false, for: question) }
                            ))
                        case .slider:
                            // Not used in initial set, but placeholder for future
                            SliderQuestionView(answer: Binding(
                                get: { vm.answers[question.id]?.sliderValue },
                                set: { vm.answers[question.id]?.sliderValue = $0 }
                            ))
                        case .freeText:
                            FreeTextQuestionView(answer: Binding(
                                get: { vm.answers[question.id]?.freeTextValue ?? "" },
                                set: { vm.setFreeText($0, for: question) }
                            ))
                        }
                    }
                }
                Button("Save") {
                    vm.saveAnswers()
                    showSaved = true
                }
                .disabled(!vm.isComplete())
            }
            .navigationTitle("Today's Questions")
            .alert(isPresented: $showSaved) {
                Alert(title: Text("Saved!"), message: Text("Your answers have been saved."), dismissButton: .default(Text("OK")))
            }
        }
    }
}

// MARK: - Question Type Views

struct YesNoQuestionView: View {
    @Binding var answer: Bool?
    var body: some View {
        HStack {
            Button(action: { answer = true }) {
                Label("Yes", systemImage: answer == true ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.bordered)
            Button(action: { answer = false }) {
                Label("No", systemImage: answer == false ? "xmark.circle.fill" : "circle")
            }
            .buttonStyle(.bordered)
        }
    }
}

struct SliderQuestionView: View {
    @Binding var answer: Double?
    var body: some View {
        Slider(value: Binding(
            get: { answer ?? 5 },
            set: { answer = $0 }
        ), in: 1...10, step: 1)
        Text("\(Int(answer ?? 5))")
    }
}

struct FreeTextQuestionView: View {
    @Binding var answer: String
    var body: some View {
        TextField("Enter your answer", text: $answer)
    }
}

#Preview {
    ContentView()
}
