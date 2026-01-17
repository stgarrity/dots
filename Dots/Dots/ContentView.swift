//
//  ContentView.swift
//  Dots
//
//  Created by Steve Garrity on 5/15/25.
//

import SwiftUI
import UserNotifications
#if canImport(Charts)
import Charts
#endif

// MARK: - Color Scheme

extension Color {
    static let primaryApp = Color(red: 0.2, green: 0.6, blue: 0.9) // Soft blue
    static let secondaryApp = Color(red: 0.9, green: 0.4, blue: 0.2) // Coral
    static let accentApp = Color(red: 0.3, green: 0.8, blue: 0.6) // Mint green
    static let backgroundApp = Color(red: 0.98, green: 0.98, blue: 1.0) // Very light blue tint
    static let cardBackground = Color.white
    static let textPrimary = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let textSecondary = Color(red: 0.4, green: 0.4, blue: 0.4)
}

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
    @Published var currentDay: Date = Calendar.current.startOfDay(for: Date())

    private var lastLoadedDay: Date = Calendar.current.startOfDay(for: Date())

    init() {
        loadQuestions()
        loadTodayAnswers()
    }

    var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    func checkForDayChangeAndReload() {
        let newDay = today
        if newDay != lastLoadedDay {
            lastLoadedDay = newDay
            currentDay = newDay
            loadTodayAnswers()
        }
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

    func loadTodayAnswers() {
        let key = "answers_\(today)"
        if let data = UserDefaults.standard.data(forKey: key) {
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

// MARK: - Notification Manager

class NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // Handle errors or denied permissions if needed
        }
    }

    func getNotificationTime() -> Date {
        if let timeData = UserDefaults.standard.data(forKey: "notificationTime"),
           let time = try? JSONDecoder().decode(Date.self, from: timeData) {
            return time
        }
        // Default to 10:00 PM today
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 22
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    func setNotificationTime(_ date: Date) {
        if let data = try? JSONEncoder().encode(date) {
            UserDefaults.standard.set(data, forKey: "notificationTime")
        }
    }

    func scheduleDailyNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyDotsReminder"])
        let notifDate = getNotificationTime()
        let comps = Calendar.current.dateComponents([.hour, .minute], from: notifDate)
        var dateComponents = DateComponents()
        dateComponents.hour = comps.hour
        dateComponents.minute = comps.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Dots Reminder"
        content.body = "Don't forget to answer your daily questions!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "dailyDotsReminder", content: content, trigger: trigger)
        center.add(request)
    }
}

// MARK: - Daily Questions View

struct ContentView: View {
    @StateObject private var vm = DailyQuestionsViewModel()
    @State private var showSaved = false
    @State private var selectedTab = 0
    @State private var lastDay: Date = Calendar.current.startOfDay(for: Date())
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                Form {
                    // Header section
                    Section {
                        VStack(spacing: 16) {
                            // App logo/icon area
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.primaryApp, Color.accentApp]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.primaryApp.opacity(0.3), radius: 8, x: 0, y: 4)

                                Image(systemName: "circle.grid.3x3.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white)
                            }

                            Text("Daily Dots")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)

                            Text("Track your daily progress")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)

                            Text(vm.currentDay, style: .date)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.backgroundApp, Color.white]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
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
                    .buttonStyle(.borderedProminent)
                    .tint(Color.primaryApp)
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
        .background(Color.backgroundApp)
        .onAppear {
            NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.scheduleDailyNotification()
            vm.checkForDayChangeAndReload()
            if lastDay != vm.today {
                selectedTab = 0 // Show Questions tab on new day
                lastDay = vm.today
            } else if vm.isComplete() {
                selectedTab = 1
            }
        }
        .onReceive(vm.$currentDay) { newDay in
            if lastDay != newDay {
                selectedTab = 0 // Show Questions tab on new day
                lastDay = newDay
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                vm.checkForDayChangeAndReload()
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
                .foregroundStyle(Color.accentApp)
                BarMark(
                    x: .value("Answer", "No"),
                    y: .value("Count", noCount)
                )
                .foregroundStyle(Color.secondaryApp)
            }
            .frame(height: 120)
            #else
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.accentApp)
                        .frame(width: geo.size.width * CGFloat(yesPercent), height: 20)
                    Rectangle()
                        .fill(Color.secondaryApp)
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
        HStack(spacing: 12) {
            Button(action: { answer = true }) {
                HStack {
                    Image(systemName: answer == true ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(answer == true ? .accentApp : .textSecondary)
                    Text("Yes")
                        .fontWeight(answer == true ? .semibold : .regular)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(answer == true ? Color.accentApp.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(answer == true ? Color.accentApp : Color.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button(action: { answer = false }) {
                HStack {
                    Image(systemName: answer == false ? "xmark.circle.fill" : "circle")
                        .foregroundColor(answer == false ? .secondaryApp : .textSecondary)
                    Text("No")
                        .fontWeight(answer == false ? .semibold : .regular)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(answer == false ? Color.secondaryApp.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(answer == false ? Color.secondaryApp : Color.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

struct SliderQuestionView: View {
    @Binding var answer: Double?
    var body: some View {
        VStack(spacing: 8) {
            Slider(value: Binding(
                get: { answer ?? 5 },
                set: { answer = $0 }
            ), in: 1...10, step: 1)
            .tint(Color.primaryApp)

            Text("\(Int(answer ?? 5))")
                .font(.headline)
                .foregroundColor(.primaryApp)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primaryApp.opacity(0.1))
                )
        }
    }
}

struct FreeTextQuestionView: View {
    @Binding var yesNo: Bool?
    @Binding var answer: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { yesNo = true }) {
                    HStack {
                        Image(systemName: yesNo == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(yesNo == true ? .accentApp : .textSecondary)
                        Text("Yes")
                            .fontWeight(yesNo == true ? .semibold : .regular)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(yesNo == true ? Color.accentApp.opacity(0.1) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(yesNo == true ? Color.accentApp : Color.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Button(action: { yesNo = false }) {
                    HStack {
                        Image(systemName: yesNo == false ? "xmark.circle.fill" : "circle")
                            .foregroundColor(yesNo == false ? .secondaryApp : .textSecondary)
                        Text("No")
                            .fontWeight(yesNo == false ? .semibold : .regular)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(yesNo == false ? Color.secondaryApp.opacity(0.1) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(yesNo == false ? Color.secondaryApp : Color.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            if yesNo == true {
                TextField("Please describe...", text: $answer)
                    .textFieldStyle(.roundedBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primaryApp.opacity(0.3), lineWidth: 1)
                    )
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
    @State private var notificationTime: Date = NotificationManager.shared.getNotificationTime()

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
                    // Notification time picker section
                    Section(header: Text("Notification Time")) {
                        DatePicker(
                            "Daily Reminder Time",
                            selection: $notificationTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .onChange(of: notificationTime) { newValue in
                            NotificationManager.shared.setNotificationTime(newValue)
                            NotificationManager.shared.scheduleDailyNotification()
                        }
                    }
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
                    .tint(Color.primaryApp)
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
                        .tint(Color.primaryApp)
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
