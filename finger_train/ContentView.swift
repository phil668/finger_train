import SwiftUI

struct ContentView: View {
    @StateObject private var timer = TrainingTimer()
    @StateObject private var store = TrainingStore()
    @AppStorage("edgeDepth") private var edgeDepth = 20.0
    @AppStorage("addedWeight") private var addedWeight = 0.0
    @AppStorage("gripType") private var gripType = GripType.halfCrimp.rawValue
    @AppStorage("trainingSide") private var trainingSide = TrainingSide.both.rawValue
    @State private var selectedTab = 0
    @State private var isShowingCheckIn = false

    var body: some View {
        TabView(selection: $selectedTab) {
            TrainingView(
                timer: timer,
                edgeDepth: $edgeDepth,
                addedWeight: $addedWeight,
                gripType: $gripType,
                trainingSide: $trainingSide,
                checkIn: { isShowingCheckIn = true }
            )
            .tag(0)
            .tabItem { Label("Train", systemImage: "timer") }

            HistoryView(store: store) { isShowingCheckIn = true }
                .tag(1)
                .tabItem { Label("History", systemImage: "chart.bar.fill") }
        }
        .tint(AppTheme.orange)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingCheckIn) {
            CheckInView(
                edgeDepth: $edgeDepth,
                addedWeight: $addedWeight,
                repetitionsPerSet: timer.repetitionsPerSet,
                initialCompletedSets: max(1, timer.completedSets),
                onSave: { details in
                    store.add(
                        edgeDepth: edgeDepth,
                        addedWeight: addedWeight,
                        gripType: gripType,
                        trainingSide: trainingSide,
                        repetitionsPerSet: timer.repetitionsPerSet,
                        hangSeconds: timer.hangSeconds,
                        restSeconds: timer.restSeconds,
                        preparationSeconds: timer.preparationSeconds,
                        details: details
                    )
                    timer.reset()
                    selectedTab = 1
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: timer.phase) { _, newPhase in
            if newPhase == .finished { isShowingCheckIn = true }
        }
        .onAppear {
            let gripMigration = [
                "开放式": GripType.openHand.rawValue,
                "半扣": GripType.halfCrimp.rawValue,
                "全扣": GripType.fullCrimp.rawValue,
                "三指": GripType.threeFinger.rawValue,
                "两指": GripType.twoFinger.rawValue
            ]
            let sideMigration = [
                "双手": TrainingSide.both.rawValue,
                "左手": TrainingSide.left.rawValue,
                "右手": TrainingSide.right.rawValue
            ]
            gripType = gripMigration[gripType] ?? gripType
            trainingSide = sideMigration[trainingSide] ?? trainingSide
        }
    }
}

private struct TrainingView: View {
    @ObservedObject var timer: TrainingTimer
    @Binding var edgeDepth: Double
    @Binding var addedWeight: Double
    @Binding var gripType: String
    @Binding var trainingSide: String
    let checkIn: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            TrainingWallBackground()

            ScrollView {
                VStack(spacing: 22) {
                    header
                    timerCard
                    roundStrip
                    controls
                    setupCard
                    checkInButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("HANGBEAT")
                    .font(.system(size: 36, weight: .black, design: .default))
                    .tracking(1.5)
                Text("Fingerboard repeaters · 7 / 3")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Button {
                timer.voiceEnabled.toggle()
            } label: {
                Image(systemName: timer.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 46, height: 46)
                    .background(AppTheme.panel)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel(timer.voiceEnabled ? "Turn voice off" : "Turn voice on")
        }
    }

    private var timerCard: some View {
        ZStack {
            Circle().stroke(AppTheme.track, lineWidth: 13)
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(timer.phaseColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.15), value: timer.progress)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [timer.phaseColor.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 130
                    )
                )
                .padding(20)
            VStack(spacing: 0) {
                Text(timer.phase.label)
                    .font(.system(size: 15, weight: .black, design: .default))
                    .tracking(4)
                    .foregroundStyle(timer.phaseColor)
                Text(timer.displayValue)
                    .font(.system(size: 112, weight: .black, design: .default))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .frame(maxWidth: 294)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timer.phase.label), \(timer.secondsRemaining) seconds, \(timer.statusLine)")
    }

    private var roundStrip: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SET \(timer.activeSetNumber) · HANGS")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Text("\(timer.currentRepetitionDisplay) / \(timer.repetitionsPerSet)")
                    .font(.system(size: 13, weight: .black, design: .default))
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                ForEach(1...timer.repetitionsPerSet, id: \.self) { repetition in
                    Capsule()
                        .fill(repetition <= timer.completedRepetitionMarkers ? AppTheme.orange : AppTheme.track)
                        .frame(height: 7)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var controls: some View {
        if timer.phase == .setComplete {
            HStack(spacing: 12) {
                Button { timer.finishSession() } label: {
                    Text("FINISH")
                        .font(.system(size: 15, weight: .black, design: .default))
                        .foregroundStyle(.white)
                        .frame(width: 104, height: 60)
                        .background(AppTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
                }
                primaryControl
            }
        } else {
            HStack(spacing: 12) {
                Button { timer.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 58, height: 58)
                        .background(AppTheme.panel)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                }
                .disabled(timer.phase == .ready)
                .opacity(timer.phase == .ready ? 0.4 : 1)
                .accessibilityLabel("Reset session")
                primaryControl
            }
        }
    }

    private var primaryControl: some View {
        Button { timer.toggle() } label: {
            HStack(spacing: 10) {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                Text(timer.primaryButtonTitle)
                    .minimumScaleFactor(0.75)
            }
            .font(.system(size: 17, weight: .black, design: .default))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(AppTheme.orange)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppTheme.orange.opacity(0.24), radius: 18, y: 8)
        }
    }

    private var setupCard: some View {
        VStack(spacing: 18) {
            HStack {
                Label("SETUP", systemImage: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .black, design: .default))
                Spacer()
                Text("PER SET · \(timer.estimatedSetDuration)")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.muted)
            }
            Divider().overlay(AppTheme.border)
            HStack(spacing: 0) {
                MetricStepper(title: "EDGE", value: $edgeDepth, range: 5...50, step: 1, unit: "mm")
                Rectangle().fill(AppTheme.border).frame(width: 1, height: 72).padding(.horizontal, 14)
                MetricStepper(title: "LOAD", value: $addedWeight, range: -50...100, step: 0.5, unit: "kg", signed: true)
            }
            configurationFields
            HStack {
                Text("Hangs per set")
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Stepper(value: $timer.repetitionsPerSet, in: 1...12) { EmptyView() }
                    .labelsHidden()
                Text("\(timer.repetitionsPerSet)")
                    .font(.system(size: 16, weight: .black, design: .default))
                    .frame(width: 46, alignment: .trailing)
            }
            .disabled(timer.phase != .ready)
            .opacity(timer.phase == .ready ? 1 : 0.45)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup time")
                        .font(.system(size: 14, weight: .bold, design: .default))
                    Text("Time to find and settle on the edge")
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Stepper(value: $timer.preparationSeconds, in: 2...10) { EmptyView() }
                    .labelsHidden()
                Text("\(timer.preparationSeconds)s")
                    .font(.system(size: 16, weight: .black, design: .default))
                    .monospacedDigit()
                    .frame(width: 46, alignment: .trailing)
            }
            .disabled(timer.phase != .ready)
            .opacity(timer.phase == .ready ? 1 : 0.45)
        }
        .padding(18)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private var configurationFields: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Grip")
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Menu {
                    ForEach(GripType.allCases) { grip in
                        Button {
                            gripType = grip.rawValue
                        } label: {
                            if gripType == grip.rawValue {
                                Label(grip.rawValue, systemImage: "checkmark")
                            } else {
                                Text(grip.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(gripType)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .black))
                    }
                    .font(.system(size: 14, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(AppTheme.track)
                    .clipShape(Capsule())
                }
            }

            HStack {
                Text("Side")
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(TrainingSide.allCases) { side in
                        Button {
                            trainingSide = side.rawValue
                        } label: {
                            Text(side.shortLabel)
                                .font(.system(size: 12, weight: .black, design: .default))
                                .foregroundStyle(trainingSide == side.rawValue ? .black : AppTheme.muted)
                                .padding(.horizontal, 11)
                                .frame(height: 32)
                                .background(trainingSide == side.rawValue ? AppTheme.orange : AppTheme.track)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .disabled(timer.phase != .ready)
        .opacity(timer.phase == .ready ? 1 : 0.45)
    }

    private var checkInButton: some View {
        Button(action: checkIn) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(AppTheme.mint)
                Text("Manual check-in")
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(AppTheme.muted)
            }
            .font(.system(size: 15, weight: .bold, design: .default))
            .padding(18)
            .background(AppTheme.panel.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct MetricStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var signed = false

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.muted)
            HStack(spacing: 10) {
                miniButton(systemName: "minus") { value = max(range.lowerBound, value - step) }
                Text(formattedValue)
                    .font(.system(size: 21, weight: .black, design: .default))
                    .monospacedDigit()
                    .frame(minWidth: 68)
                miniButton(systemName: "plus") { value = min(range.upperBound, value + step) }
            }
            Text(unit)
                .font(.system(size: 11, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedValue: String {
        let prefix = signed && value > 0 ? "+" : ""
        if value.rounded() == value { return "\(prefix)\(Int(value))" }
        return "\(prefix)\(String(format: "%.1f", value))"
    }

    private func miniButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .black))
                .frame(width: 26, height: 26)
                .background(AppTheme.track)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryView: View {
    @ObservedObject var store: TrainingStore
    let checkIn: () -> Void
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                TrainingWallBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        summaryCard
                        TrainingCalendarView(displayedMonth: $displayedMonth, records: store.records)
                        TrainingDashboardView(store: store)
                        recentHeader
                        if store.records.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(store.records) { record in
                                    RecordRow(record: record) { store.delete(record) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Training History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: checkIn) { Image(systemName: "plus").fontWeight(.bold) }
                        .accessibilityLabel("Add training record")
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.hasCheckedInToday ? "DONE FOR TODAY" : "TRAIN TODAY?")
                        .font(.system(size: 22, weight: .black, design: .default))
                    Text(store.hasCheckedInToday ? "Recovery is part of training" : "One focused set starts with one tap")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                ZStack {
                    Circle().fill((store.hasCheckedInToday ? AppTheme.mint : AppTheme.orange).opacity(0.13))
                    Image(systemName: store.hasCheckedInToday ? "checkmark" : "flame.fill")
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(store.hasCheckedInToday ? AppTheme.mint : AppTheme.orange)
                }
                .frame(width: 58, height: 58)
            }
            HStack(spacing: 10) {
                SummaryMetric(value: "\(store.currentStreak)", label: "DAY STREAK")
                SummaryMetric(value: "\(store.sessionsThisWeek)", label: "THIS WEEK")
                SummaryMetric(value: "\(store.records.count)", label: "SESSIONS")
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [AppTheme.panel, Color(red: 0.13, green: 0.12, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private var recentHeader: some View {
        HStack {
            Text("RECENT SESSIONS").font(.system(size: 18, weight: .black, design: .default))
            Spacer()
            Text("Hold to delete")
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fingers.spread")
                .font(.system(size: 38))
                .foregroundStyle(AppTheme.muted)
            Text("No training records yet").font(.system(size: 17, weight: .bold, design: .default))
            Text("Finish a session to create your first check-in")
                .font(.system(size: 13, design: .default))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .background(AppTheme.panel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SummaryMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 24, weight: .black, design: .default)).monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.track.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct TrainingCalendarView: View {
    @Binding var displayedMonth: Date
    let records: [TrainingRecord]

    private let calendar = Calendar.current
    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHECK-IN CALENDAR")
                        .font(.system(size: 17, weight: .black, design: .default))
                    Text(monthTitle)
                        .font(.system(size: 12, weight: .bold, design: .default))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                monthButton(systemName: "chevron.left", offset: -1)
                monthButton(systemName: "chevron.right", offset: 1)
            }

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.system(size: 10, weight: .black, design: .default))
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private var monthTitle: String {
        displayedMonth.formatted(
            Date.FormatStyle()
                .month(.wide)
                .year()
                .locale(Locale(identifier: "en_US"))
        )
        .uppercased()
    }

    private var calendarDays: [Date?] {
        guard
            let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth),
            let monthStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start
        else { return [] }

        let weekday = calendar.component(.weekday, from: monthStart)
        let mondayBasedOffset = (weekday + 5) % 7
        let padding = Array<Date?>(repeating: nil, count: mondayBasedOffset)
        let dates = monthRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        return padding + dates.map(Optional.some)
    }

    private func sessionCount(on date: Date) -> Int {
        records.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    private func dayCell(_ date: Date) -> some View {
        let count = sessionCount(on: date)
        let isToday = calendar.isDateInToday(date)
        return ZStack(alignment: .bottomTrailing) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 13, weight: count > 0 ? .black : .semibold, design: .default))
                .foregroundStyle(count > 0 ? Color.black : Color.white.opacity(0.82))
                .frame(width: 38, height: 38)
                .background(count > 0 ? AppTheme.orange : AppTheme.track.opacity(0.38))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isToday ? AppTheme.mint : Color.clear, lineWidth: 2)
                )

            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 8, weight: .black, design: .default))
                    .foregroundStyle(.black)
                    .frame(width: 15, height: 15)
                    .background(AppTheme.mint)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .accessibilityLabel("\(date.formatted(date: .long, time: .omitted)), \(count) sessions")
    }

    private func monthButton(systemName: String, offset: Int) -> some View {
        Button {
            if let next = calendar.date(byAdding: .month, value: offset, to: displayedMonth) {
                displayedMonth = next
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .black))
                .frame(width: 34, height: 34)
                .background(AppTheme.track)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(offset < 0 ? "Previous month" : "Next month")
    }
}

private struct TrainingDashboardView: View {
    @ObservedObject var store: TrainingStore
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DASHBOARD")
                    .font(.system(size: 17, weight: .black, design: .default))
                Spacer()
                Text("ALL TIME")
                    .font(.system(size: 10, weight: .black, design: .default))
                    .foregroundStyle(AppTheme.muted)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                DashboardMetric(icon: "checkmark.seal.fill", value: "\(store.records.count)", label: "SESSIONS", color: AppTheme.mint)
                DashboardMetric(icon: "square.stack.3d.up.fill", value: "\(store.totalSets)", label: "SETS", color: AppTheme.orange)
                DashboardMetric(icon: "hand.raised.fill", value: "\(store.totalHangs)", label: "HANGS", color: AppTheme.preparation)
                DashboardMetric(icon: "gauge.with.dots.needle.67percent", value: store.averageRPEText, label: "AVG RPE", color: AppTheme.mint)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("LAST 7 DAYS")
                        .font(.system(size: 12, weight: .black, design: .default))
                    Spacer()
                    Text("\(store.recentSevenDayVolume.reduce(0) { $0 + $1.hangs }) HANGS")
                        .font(.system(size: 11, weight: .black, design: .default))
                        .foregroundStyle(AppTheme.orange)
                }
                WeeklyVolumeChart(volume: store.recentSevenDayVolume)
            }
            .padding(15)
            .background(AppTheme.track.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(18)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }
}

private struct DashboardMetric: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.11))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .default))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .default))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.track.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WeeklyVolumeChart: View {
    let volume: [DailyTrainingVolume]

    var body: some View {
        GeometryReader { proxy in
            let maxHangs = max(1, volume.map(\.hangs).max() ?? 1)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(volume) { day in
                    VStack(spacing: 5) {
                        Text(day.hangs > 0 ? "\(day.hangs)" : "")
                            .font(.system(size: 8, weight: .black, design: .default))
                            .foregroundStyle(AppTheme.muted)
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Calendar.current.isDateInToday(day.date) ? AppTheme.mint : AppTheme.orange)
                            .frame(
                                height: day.hangs == 0
                                    ? 4
                                    : max(10, (proxy.size.height - 30) * CGFloat(day.hangs) / CGFloat(maxHangs))
                            )
                            .opacity(day.hangs == 0 ? 0.16 : 1)
                        Text(day.dayLabel)
                            .font(.system(size: 9, weight: .black, design: .default))
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? AppTheme.mint : AppTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 116)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seven day training volume")
    }
}

private struct RecordRow: View {
    let record: TrainingRecord
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(record.dayText).font(.system(size: 22, weight: .black, design: .default)).monospacedDigit()
                Text(record.monthText)
                    .font(.system(size: 10, weight: .black, design: .default))
                    .foregroundStyle(AppTheme.orange)
            }
            .frame(width: 48, height: 54)
            .background(AppTheme.track)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("\(record.edgeDepthText) mm · \(record.weightText) kg")
                    .font(.system(size: 16, weight: .black, design: .default))
                HStack(spacing: 7) {
                    Text(record.timeText)
                    if !record.trainingStyleText.isEmpty {
                        Text("·")
                        Text(record.trainingStyleText)
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(AppTheme.muted)
                HStack(spacing: 6) {
                    recordTag(record.volumeText, color: AppTheme.orange)
                    if let rpe = record.rpe {
                        recordTag("RPE \(rpe)", color: AppTheme.mint)
                    }
                    if let pain = record.painLevel, pain > 0 {
                        recordTag("PAIN \(pain)", color: .red)
                    }
                }
                if let painArea = record.painArea, !painArea.isEmpty {
                    Text("Discomfort: \(painArea)")
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundStyle(.red.opacity(0.85))
                        .lineLimit(1)
                }
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.mint)
        }
        .padding(15)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        .contextMenu {
            Button(role: .destructive, action: delete) { Label("Delete record", systemImage: "trash") }
        }
    }

    private func recordTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .default))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }
}

private struct CheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var edgeDepth: Double
    @Binding var addedWeight: Double
    let repetitionsPerSet: Int
    let onSave: (CheckInDetails) -> Void
    @State private var completedSets: Int
    @State private var rpe = 8
    @State private var painLevel = 0
    @State private var painArea = ""
    @State private var note = ""

    init(
        edgeDepth: Binding<Double>,
        addedWeight: Binding<Double>,
        repetitionsPerSet: Int,
        initialCompletedSets: Int,
        onSave: @escaping (CheckInDetails) -> Void
    ) {
        _edgeDepth = edgeDepth
        _addedWeight = addedWeight
        self.repetitionsPerSet = repetitionsPerSet
        self.onSave = onSave
        _completedSets = State(initialValue: max(1, initialCompletedSets))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 7) {
                            ZStack {
                                Circle().fill(AppTheme.mint.opacity(0.14))
                                Image(systemName: "checkmark")
                                    .font(.system(size: 29, weight: .black))
                                    .foregroundStyle(AppTheme.mint)
                            }
                            .frame(width: 68, height: 68)
                            Text("SESSION CHECK-IN")
                                .font(.system(size: 25, weight: .black, design: .default))
                            Text("Save your work and how your fingers felt")
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundStyle(AppTheme.muted)
                        }

                        HStack(spacing: 10) {
                            checkInField(title: "EDGE", value: $edgeDepth, range: 5...50, step: 1, unit: "mm")
                            checkInField(title: "LOAD", value: $addedWeight, range: -50...100, step: 0.5, unit: "kg")
                        }

                        completionCard
                        scaleCard(title: "Perceived effort", value: $rpe, range: 1...10, prefix: "RPE", tint: AppTheme.mint)
                        scaleCard(title: "Pain level", value: $painLevel, range: 0...10, prefix: "PAIN", tint: painLevel > 0 ? .red : AppTheme.mint)

                        if painLevel > 0 {
                            TextField("Pain location, e.g. right middle finger A2", text: $painArea)
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .padding(16)
                                .background(AppTheme.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        TextField("Optional note, e.g. felt strong today", text: $note)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .padding(16)
                            .background(AppTheme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button {
                            onSave(
                                CheckInDetails(
                                    completedSets: completedSets,
                                    rpe: rpe,
                                    painLevel: painLevel,
                                    painArea: painArea.trimmingCharacters(in: .whitespacesAndNewlines),
                                    note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                            )
                            dismiss()
                        } label: {
                            Text("SAVE CHECK-IN")
                                .font(.system(size: 17, weight: .black, design: .default))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(AppTheme.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundStyle(AppTheme.muted)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var completionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Sets completed")
                    .font(.system(size: 14, weight: .bold, design: .default))
                Spacer()
                Text("\(completedSets) SET\(completedSets == 1 ? "" : "S")")
                    .font(.system(size: 17, weight: .black, design: .default))
                    .foregroundStyle(AppTheme.orange)
                    .monospacedDigit()
            }
            HStack {
                Text("\(completedSets * repetitionsPerSet) total hangs")
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Stepper(value: $completedSets, in: 1...20) { EmptyView() }
                    .labelsHidden()
            }
        }
        .padding(16)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private func scaleCard(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        prefix: String,
        tint: Color
    ) -> some View {
        let sliderValue = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )
        return VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .default))
                Spacer()
                Text("\(prefix) \(value.wrappedValue)")
                    .font(.system(size: 16, weight: .black, design: .default))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            Slider(
                value: sliderValue,
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(tint)
            HStack {
                Text(range.lowerBound == 0 ? "NO PAIN" : "EASY")
                Spacer()
                Text(range.lowerBound == 0 ? "SEVERE" : "MAX")
            }
            .font(.system(size: 10, weight: .bold, design: .default))
            .foregroundStyle(AppTheme.muted)
        }
        .padding(16)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private func checkInField(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.muted)
            Text("\(value.wrappedValue, specifier: value.wrappedValue.rounded() == value.wrappedValue ? "%.0f" : "%.1f") \(unit)")
                .font(.system(size: 21, weight: .black, design: .default))
                .monospacedDigit()
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }
}

private struct TrainingWallBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 4) ? AppTheme.orange.opacity(0.06) : Color.white.opacity(0.025))
                        .frame(width: CGFloat(18 + (index % 3) * 8))
                        .position(
                            x: CGFloat((index * 83 + 31) % max(Int(proxy.size.width), 1)),
                            y: CGFloat(index * 117 + 34)
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

enum AppTheme {
    static let background = Color(red: 0.045, green: 0.047, blue: 0.045)
    static let panel = Color(red: 0.095, green: 0.098, blue: 0.092)
    static let track = Color(red: 0.16, green: 0.165, blue: 0.153)
    static let border = Color.white.opacity(0.08)
    static let muted = Color(red: 0.60, green: 0.61, blue: 0.56)
    static let orange = Color(red: 1.0, green: 0.43, blue: 0.12)
    static let preparation = Color(red: 1.0, green: 0.78, blue: 0.24)
    static let mint = Color(red: 0.36, green: 0.91, blue: 0.67)
}
