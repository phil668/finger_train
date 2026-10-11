import Combine
import Foundation

enum GripType: String, CaseIterable, Identifiable {
    case openHand = "Open hand"
    case halfCrimp = "Half crimp"
    case fullCrimp = "Full crimp"
    case threeFinger = "Three finger"
    case twoFinger = "Two finger"

    var id: String { rawValue }
}

enum TrainingSide: String, CaseIterable, Identifiable {
    case both = "Both hands"
    case left = "Left hand"
    case right = "Right hand"

    var id: String { rawValue }
    var shortLabel: String {
        switch self {
        case .both: "Both"
        case .left: "Left"
        case .right: "Right"
        }
    }
}

struct CheckInDetails {
    let completedSets: Int
    let rpe: Int
    let painLevel: Int
    let painArea: String
    let note: String
}

struct DailyTrainingVolume: Identifiable {
    let date: Date
    let hangs: Int

    var id: Date { date }
    var dayLabel: String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.narrow)
                .locale(Locale(identifier: "en_US"))
        )
    }
}

struct TrainingRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let edgeDepth: Double
    let addedWeight: Double
    let rounds: Int
    let hangSeconds: Int
    let restSeconds: Int
    let preparationSeconds: Int?
    let note: String
    // Optional fields keep records created by earlier versions readable.
    let gripType: String?
    let trainingSide: String?
    let plannedRounds: Int?
    let repetitionsPerSet: Int?
    let completedSets: Int?
    let rpe: Int?
    let painLevel: Int?
    let painArea: String?

    var dayText: String { date.formatted(.dateTime.day(.twoDigits)) }
    var monthText: String {
        date.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .locale(Locale(identifier: "en_US"))
        )
        .uppercased()
    }
    var timeText: String { date.formatted(date: .omitted, time: .shortened) }
    var edgeDepthText: String { Self.format(edgeDepth, signed: false) }
    var weightText: String { Self.format(addedWeight, signed: true) }

    var volumeText: String {
        if let completedSets, let repetitionsPerSet {
            return "\(completedSets) sets × \(repetitionsPerSet) hangs"
        }
        if let plannedRounds, plannedRounds > 0 {
            return "\(rounds)/\(plannedRounds) hangs"
        }
        return rounds > 0 ? "\(rounds) hangs" : "Manual entry"
    }

    var trainingStyleText: String {
        var parts = [Self.englishGrip(gripType), Self.englishSide(trainingSide)].compactMap { $0 }
        if let preparationSeconds {
            parts.append("\(preparationSeconds)s setup")
        }
        return parts.joined(separator: " · ")
    }

    private static func englishGrip(_ value: String?) -> String? {
        switch value {
        case "开放式": "Open hand"
        case "半扣": "Half crimp"
        case "全扣": "Full crimp"
        case "三指": "Three finger"
        case "两指": "Two finger"
        default: value
        }
    }

    private static func englishSide(_ value: String?) -> String? {
        switch value {
        case "双手": "Both hands"
        case "左手": "Left hand"
        case "右手": "Right hand"
        default: value
        }
    }

    private static func format(_ value: Double, signed: Bool) -> String {
        let prefix = signed && value > 0 ? "+" : ""
        if value.rounded() == value { return "\(prefix)\(Int(value))" }
        return "\(prefix)\(String(format: "%.1f", value))"
    }
}

@MainActor
final class TrainingStore: ObservableObject {
    @Published private(set) var records: [TrainingRecord] = []

    private let storageKey = "finger-training-records-v1"
    private let calendar = Calendar.current

    init() { load() }

    var hasCheckedInToday: Bool {
        records.contains { calendar.isDateInToday($0.date) }
    }

    var sessionsThisWeek: Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return records.filter { interval.contains($0.date) }.count
    }

    var totalSets: Int {
        records.reduce(0) { total, record in
            total + (record.completedSets ?? (record.rounds > 0 ? 1 : 0))
        }
    }

    var totalHangs: Int {
        records.reduce(0) { $0 + $1.rounds }
    }

    var averageRPEText: String {
        let values = records.compactMap(\.rpe)
        guard !values.isEmpty else { return "—" }
        let average = Double(values.reduce(0, +)) / Double(values.count)
        return String(format: "%.1f", average)
    }

    var recentSevenDayVolume: [DailyTrainingVolume] {
        let today = calendar.startOfDay(for: Date())
        return (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let hangs = records
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.rounds }
            return DailyTrainingVolume(date: date, hangs: hangs)
        }
    }

    func sessionCount(on date: Date) -> Int {
        records.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    var currentStreak: Int {
        let uniqueDays = Set(records.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        if !uniqueDays.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yesterday
        }

        var streak = 0
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func add(
        edgeDepth: Double,
        addedWeight: Double,
        gripType: String,
        trainingSide: String,
        repetitionsPerSet: Int,
        hangSeconds: Int,
        restSeconds: Int,
        preparationSeconds: Int,
        details: CheckInDetails
    ) {
        records.insert(
            TrainingRecord(
                id: UUID(),
                date: Date(),
                edgeDepth: edgeDepth,
                addedWeight: addedWeight,
                rounds: details.completedSets * repetitionsPerSet,
                hangSeconds: hangSeconds,
                restSeconds: restSeconds,
                preparationSeconds: preparationSeconds,
                note: details.note,
                gripType: gripType,
                trainingSide: trainingSide,
                plannedRounds: nil,
                repetitionsPerSet: repetitionsPerSet,
                completedSets: details.completedSets,
                rpe: details.rpe,
                painLevel: details.painLevel,
                painArea: details.painLevel > 0 && !details.painArea.isEmpty ? details.painArea : nil
            ),
            at: 0
        )
        save()
    }

    func delete(_ record: TrainingRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([TrainingRecord].self, from: data)
        else { return }
        records = decoded.sorted { $0.date > $1.date }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
