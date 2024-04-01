import SwiftUI
import HealthKit
import Charts

struct HRVTrendsGraph: View {
    var hrvDataPoints: [HRVDataPoint]

    var body: some View {
        Chart {
            ForEach(hrvDataPoints, id: \.date) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("HRV", dataPoint.value)
                )
                .foregroundStyle(dataPoint.status.color)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: .stride(by: Calendar.Component.day)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
    }
}

struct HRVDataPoint {
    var date: Date
    var value: Double
    var status: StressLevel
}

enum StressLevel {
    case normal, attention, excellent
    
    var color: Color {
        switch self {
        case .normal:
            return .blue
        case .attention:
            return .orange
        case .excellent:
            return .green
        }
    }
}

struct StressMonitorView: View {
    @State private var hrvValue: Double = 0.0
    @State private var stressLevel: String = "Unknown"
    @State private var selectedDate = Date()
    private let healthStore = HKHealthStore()
    @State private var hrvDataPoints: [HRVDataPoint] = []

    var body: some View {
        VStack {
            // Date Header
            DateHeaderView(selectedDate: $selectedDate)

            // Gauge View
            GaugeView(hrvValue: $hrvValue)

            // Status Message
            Text("HRV Status: \(stressLevelEmoji()) \(stressLevel)")
                .font(.headline)
                .padding()

            // Action Button
            Button("Measure HRV") {
                fetchHRVData()
            }
            .padding()
            .background(Color.gray.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(10)

            // HRV Trends Graph
            HRVTrendsGraph(hrvDataPoints: hrvDataPoints)
                .padding()
        }
        .padding()
        .onAppear {
            requestHealthAuthorization()
        }
    }

    private func requestHealthAuthorization() {
        let readTypes = Set([HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!])
        
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if !success {
                // Handle the error here.
                print("Authorization not granted: \(error?.localizedDescription ?? "N/A")")
            }
        }
    }

    private func fetchHRVData() {
        guard let sampleType = HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            fatalError("*** This should never fail ***")
        }
        
        let mostRecentPredicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sampleType, predicate: mostRecentPredicate, limit: 1, sortDescriptors: [sortDescriptor]) { [self] _, results, error in
            guard let sample = results?.first as? HKQuantitySample else {
                print("Failed to fetch HRV: \(error?.localizedDescription ?? "N/A")")
                return
            }
            
            let hrvValue = sample.quantity.doubleValue(for: HKUnit(from: "ms"))
            DispatchQueue.main.async {
                self.hrvValue = hrvValue
                self.analyzeHRV(hrv: hrvValue)
            }
        }

        healthStore.execute(query)
    }

    private func analyzeHRV(hrv: Double) {
        // Assume gender and age determination logic has been implemented here
        let isBoy = true // Replace with actual logic to determine gender
        let age = 10 // Replace with actual logic to determine age

        // Analyze the HRV value and determine stress level
        self.stressLevel = determineStressLevel(for: hrv, isBoy: isBoy, age: age)
        
        // Optionally, send a notification if the stress level is high
        if stressLevel == "Overload" || stressLevel == "Attention" {
            sendStressNotification()
        }
    }

    private func determineStressLevel(for hrv: Double, isBoy: Bool, age: Int) -> String {
        if isBoy {
            // Logic for boys
            switch hrv {
            case ...20:
                return "Overload"
            case 21...40:
                return "Attention"
            case 41...80:
                return "Normal"
            case 81...:
                return "Excellent"
            default:
                return "Unknown"
            }
        } else {
            // Logic for girls
            switch age {
            case 0..<18:
                if hrv <= 18 {
                    return "Overload"
                } else if hrv <= 38 {
                    return "Attention"
                } else if hrv <= 78 {
                    return "Normal"
                } else {
                    return "Excellent"
                }
            case 18...:
                if hrv <= 20 {
                    return "Overload"
                } else if hrv <= 40 {
                    return "Attention"
                } else if hrv <= 80 {
                    return "Normal"
                } else {
                    return "Excellent"
                }
            default:
                return "Unknown"
            }
        }
    }

    private func sendStressNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Stress Alert"
        content.body = "Your HRV indicates high stress levels. Consider taking a moment to relax."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error when sending notification: \(error.localizedDescription)")
            }
        }
    }

    private func stressLevelEmoji() -> String {
        switch stressLevel {
        case "Overload":
            return "😫"
        case "Attention":
            return "😟"
        case "Normal":
            return "😊"
        case "Excellent":
            return "😌"
        default:
            return ""
        }
    }
}

struct StressMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        StressMonitorView()
    }
}

struct DateHeaderView: View {
    @Binding var selectedDate: Date

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<7) { index in
                Text("\(self.dayOfWeek(index: index))")
                    .foregroundColor(self.textColor(index: index))
                    .padding(2)
                    .frame(width: 40, height: 60)
                    .background(self.backgroundColor(index: index))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(self.borderColor(index: index), lineWidth: 2)
                    )
            }
        }
    }

    private func dayOfWeek(index: Int) -> String {
        let weekdaySymbols = Calendar.current.shortWeekdaySymbols
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1
        return weekdaySymbols[(todayIndex + index) % 7]
    }

    private func textColor(index: Int) -> Color {
        isSelectedDate(index: index) ? .white : .black
    }

    private func backgroundColor(index: Int) -> Color {
        isSelectedDate(index: index) ? .black : .clear
    }

    private func borderColor(index: Int) -> Color {
        isSelectedDate(index: index) ? .clear : .gray
    }

    private func isSelectedDate(index: Int) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let todayIndex = calendar.component(.weekday, from: Date()) - 2
        let dateToCheck = calendar.date(byAdding: .day, value: index - todayIndex, to: startOfDay)!
        return calendar.isDate(dateToCheck, inSameDayAs: selectedDate)
    }
}

struct DateHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        DateHeaderView(selectedDate: .constant(Date()))
    }
}

// Gauge View
struct GaugeView: View {
    @Binding var hrvValue: Double

    var body: some View {
        VStack {
            Text("HRV")
                .font(.title)
                .padding(.bottom, 5)
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 150, height: 150)
                Circle()
                    .trim(from: 0, to: CGFloat(min(self.hrvValue / 100, 1)))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(Angle(degrees: -90))
                    .frame(width: 150, height: 150)
                    .animation(.linear)
                Text("\(Int(hrvValue))")
                    .font(.title)
            }
        }
    }
}
