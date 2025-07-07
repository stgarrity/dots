//
//  ContentView.swift
//  Dots
//
//  Created by Steve Garrity on 5/15/25.
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

// MARK: - Data Models

enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case yesNo
    case slider
    case freeText

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .yesNo: return "Yes/No"
        case .slider: return "Slider"
        case .freeText: return "Free Text"
        }
    }
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
    @Published var questions: [Question] = [] {
        didSet {
            saveQuestions()
        }
    }
    @Published var answers: [UUID: Answer] = [:] // keyed by questionID

    let today = Calendar.current.startOfDay(for: Date())

    init() {
        loadQuestions()
        checkForNewDay()
        loadTodayAnswers()
    }

    func loadQuestions() {
        if let data = UserDefaults.standard.data(forKey: "questions") {
            if let decoded = try? JSONDecoder().decode([Question].self, from: data) {
                questions = decoded
                return
            }
        }
        // If not found, use default questions
        questions = [
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "Did I make meaningful progress on something important today?", type: .yesNo),
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, text: "Was I able to finish work without guilt or mental spillover?", type: .yesNo),
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, text: "Did I do at least one thing that energized me outside of work?", type: .freeText),
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, text: "Did I feel present during non-work activities today?", type: .yesNo),
            Question(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, text: "Do I feel like I'm pacing myself in a sustainable way?", type: .yesNo)
        ]
        saveQuestions()
    }

    func saveQuestions() {
        if let data = try? JSONEncoder().encode(questions) {
            UserDefaults.standard.set(data, forKey: "questions")
        }
    }

    func checkForNewDay() {
        let lastOpenedDateKey = "lastOpenedDate"
        
        // Get the last date the app was opened
        if let lastOpenedData = UserDefaults.standard.data(forKey: lastOpenedDateKey),
           let lastOpenedDate = try? JSONDecoder().decode(Date.self, from: lastOpenedData) {
            
            let lastOpenedDay = Calendar.current.startOfDay(for: lastOpenedDate)
            
            // If today is different from the last opened day, clear today's answers
            if today != lastOpenedDay {
                clearTodayAnswers()
            }
        }
        
        // Update the last opened date to today
        if let todayData = try? JSONEncoder().encode(today) {
            UserDefaults.standard.set(todayData, forKey: lastOpenedDateKey)
        }
    }

    func loadTodayAnswers() {
        if let data = UserDefaults.standard.data(forKey: "answers_\(today)") {
            if let decoded = try? JSONDecoder().decode([UUID: Answer].self, from: data) {
                answers = decoded
                return
            }
        }
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
                let a = answers[q.id]
                if a?.yesNoValue == nil { return false }
            }
        }
        return true
    }

    // MARK: - Question Editing
    func addQuestion(text: String, type: QuestionType) {
        let newQ = Question(id: UUID(), text: text, type: type)
        questions.append(newQ)
        clearTodayAnswers()
    }

    func updateQuestion(_ question: Question, text: String, type: QuestionType) {
        if let idx = questions.firstIndex(where: { $0.id == question.id }) {
            questions[idx].text = text
            questions[idx].type = type
            clearTodayAnswers()
        }
    }

    func deleteQuestion(at offsets: IndexSet) {
        questions.remove(atOffsets: offsets)
        clearTodayAnswers()
    }

    func moveQuestion(from source: IndexSet, to destination: Int) {
        questions.move(fromOffsets: source, toOffset: destination)
        clearTodayAnswers()
    }

    func clearTodayAnswers() {
        UserDefaults.standard.removeObject(forKey: "answers_\(today)")
        loadTodayAnswers()
    }
}

// MARK: - Daily Questions View

struct ContentView: View {
    @StateObject private var vm = DailyQuestionsViewModel()
    @State private var showSaved = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
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
                                SliderQuestionView(answer: Binding(
                                    get: { vm.answers[question.id]?.sliderValue },
                                    set: { vm.answers[question.id]?.sliderValue = $0 }
                                ))
                            case .freeText:
                                FreeTextQuestionView(
                                    yesNo: Binding(
                                        get: { vm.answers[question.id]?.yesNoValue },
                                        set: { vm.setYesNo($0 ?? false, for: question) }
                                    ),
                                    answer: Binding(
                                        get: { vm.answers[question.id]?.freeTextValue ?? "" },
                                        set: { vm.setFreeText($0, for: question) }
                                    )
                                )
                            }
                        }
                    }
                    Button("Save") {
                        vm.saveAnswers()
                        showSaved = true
                        selectedTab = 1 // Switch to Summary tab
                    }
                    .disabled(!vm.isComplete())
                }
                .navigationTitle("Today's Questions")
                .alert(isPresented: $showSaved) {
                    Alert(title: Text("Saved!"), message: Text("Your answers have been saved."), dismissButton: .default(Text("OK")))
                }
            }
            .tabItem {
                Label("Questions", systemImage: "list.bullet")
            }
            .tag(0)

            SummaryView(questions: vm.questions)
                .tabItem {
                    Label("Summary", systemImage: "chart.bar")
                }
                .tag(1)

            QuestionsEditorView(vm: vm)
                .tabItem {
                    Label("Edit", systemImage: "pencil")
                }
                .tag(2)
        }
        .onAppear {
            // If today's answers are already complete, show the Summary tab
            if vm.isComplete() {
                selectedTab = 1
            }
        }
    }
}

// MARK: - Summary View

struct SummaryView: View {
    let questions: [Question]
    @State private var range: SummaryRange = .week
    @State private var historicalAnswers: [Date: [UUID: Answer]] = [:]

    var body: some View {
        NavigationView {
            VStack {
                Picker("Range", selection: $range) {
                    ForEach(SummaryRange.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    ForEach(questions) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.text)
                                .font(.headline)
                            switch question.type {
                            case .yesNo:
                                YesNoSummaryChart(question: question, answers: answersFor(question: question))
                            case .slider:
                                SliderSummaryChart(question: question, answers: answersFor(question: question))
                            case .freeText:
                                FreeTextSummaryList(question: question, answers: answersFor(question: question))
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Summary")
            .onAppear {
                loadHistoricalAnswers()
            }
            .onChange(of: range) { _ in
                loadHistoricalAnswers()
            }
        }
    }

    func answersFor(question: Question) -> [Answer] {
        historicalAnswers.values.compactMap { $0[question.id] }
    }

    func loadHistoricalAnswers() {
        // Load answers for the selected range from UserDefaults
        var result: [Date: [UUID: Answer]] = [:]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates: [Date]
        switch range {
        case .today:
            dates = [today]
        case .week:
            dates = (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        case .month:
            dates = (0..<30).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        }
        for date in dates {
            if let data = UserDefaults.standard.data(forKey: "answers_\(date)") {
                if let decoded = try? JSONDecoder().decode([UUID: Answer].self, from: data) {
                    result[date] = decoded
                }
            }
        }
        historicalAnswers = result
    }
}

enum SummaryRange: String, CaseIterable, Identifiable {
    case today, week, month
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

// MARK: - Summary Chart Views

struct YesNoSummaryChart: View {
    let question: Question
    let answers: [Answer]
    var yesCount: Int { answers.filter { $0.yesNoValue == true }.count }
    var noCount: Int { answers.filter { $0.yesNoValue == false }.count }
    var total: Int { yesCount + noCount }
    var yesPercent: Double { total > 0 ? Double(yesCount) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Yes: \(yesCount)")
                Text("No: \(noCount)")
            }
            #if canImport(Charts)
            Chart {
                BarMark(
                    x: .value("Answer", "Yes"),
                    y: .value("Count", yesCount)
                )
                BarMark(
                    x: .value("Answer", "No"),
                    y: .value("Count", noCount)
                )
            }
            .frame(height: 120)
            #else
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(yesPercent), height: 20)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geo.size.width * CGFloat(1 - yesPercent), height: 20)
                }
            }
            .frame(height: 20)
            #endif
        }
    }
}

struct SliderSummaryChart: View {
    let question: Question
    let answers: [Answer]
    var values: [Double] { answers.compactMap { $0.sliderValue } }
    var avg: Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
    var body: some View {
        if values.isEmpty {
            Text("No data yet.")
        } else {
            Text("Average: \(String(format: "%.1f", avg))")
        }
    }
}

struct FreeTextSummaryList: View {
    let question: Question
    let answers: [Answer]
    var body: some View {
        let filtered = answers.filter { $0.yesNoValue == true }
        if filtered.isEmpty {
            Text("No responses yet.")
                .italic()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(filtered) { answer in
                    if let text = answer.freeTextValue, !text.isEmpty {
                        Text("• \(text)")
                    } else {
                        Text("• (No details provided)")
                            .italic()
                    }
                }
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
    @Binding var yesNo: Bool?
    @Binding var answer: String
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: { yesNo = true }) {
                    Label("Yes", systemImage: yesNo == true ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.bordered)
                Button(action: { yesNo = false }) {
                    Label("No", systemImage: yesNo == false ? "xmark.circle.fill" : "circle")
                }
                .buttonStyle(.bordered)
            }
            if yesNo == true {
                TextField("Please describe...", text: $answer)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Questions Editor View

struct QuestionsEditorView: View {
    @ObservedObject var vm: DailyQuestionsViewModel
    @State private var newText: String = ""
    @State private var newType: QuestionType = .yesNo
    @State private var editingQuestion: Question? = nil
    @State private var editingText: String = ""
    @State private var editingType: QuestionType = .yesNo

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(vm.questions) { question in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(question.text)
                                Text(question.type.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                editingQuestion = question
                                editingText = question.text
                                editingType = question.type
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .onDelete(perform: vm.deleteQuestion)
                    .onMove(perform: vm.moveQuestion)
                }
                .environment(\ .editMode, .constant(.active))
                .navigationTitle("Edit Questions")
                .toolbar {
                    EditButton()
                }
                Divider()
                VStack(spacing: 8) {
                    Text("Add New Question")
                        .font(.headline)
                    TextField("Question text", text: $newText)
                        .textFieldStyle(.roundedBorder)
                    Picker("Type", selection: $newType) {
                        ForEach(QuestionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button("Add") {
                        guard !newText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        vm.addQuestion(text: newText, type: newType)
                        newText = ""
                        newType = .yesNo
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .sheet(item: $editingQuestion) { question in
                NavigationView {
                    Form {
                        Section(header: Text("Edit Question")) {
                            TextField("Question text", text: $editingText)
                            Picker("Type", selection: $editingType) {
                                ForEach(QuestionType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Button("Save") {
                            vm.updateQuestion(question, text: editingText, type: editingType)
                            editingQuestion = nil
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Cancel", role: .cancel) {
                            editingQuestion = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .navigationTitle("Edit Question")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
