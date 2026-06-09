//
//  WorkoutManager.swift
//  SwiftLap (watchOS)
//
//  Migrated from SwiftLapWatch. HealthKit logic unchanged; the only change is
//  that saving now uses the shared APIClient + WatchStore instead of the old
//  per-app APIService.
//

import Foundation
import HealthKit
import Combine
import WatchKit

/// A finished workout awaiting upload. Persisted to disk when a sync fails so it
/// survives app quit / loss of connectivity, then retried on launch/foreground.
private struct PendingWorkout: Codable {
    let swimmerId: String
    let duration: Int
    let distance: Double
    let laps: Int
    let strokeCount: Int
    let avgHeartRate: Double
    let calories: Double
    let lapTimes: [Double]
    let lapStrokes: [Int]
    let fatigueLevel: String
    let poolLength: Double
}

class WorkoutManager: NSObject, ObservableObject {

    @Published var isWorkoutActive = false
    @Published var elapsedSeconds: Int = 0
    @Published var heartRate: Double = 0
    @Published var strokeCount: Int = 0
    @Published var lapCount: Int = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var fatigueLevel: String = "Fresh 💪"
    @Published var currentPace: String = "--:--"
    @Published var avgStrokesPerLap: Double = 0
    @Published var pendingSyncCount: Int = 0

    // Only 25 m and 50 m are supported. Snap any legacy stored value (incl. the
    // old 25 yd / 50 yd options, 22.86 / 45.72) to the nearest of the two.
    @Published var poolLength: Double = {
        let v = UserDefaults.standard.double(forKey: "poolLengthMeters")
        if v == 25.0 || v == 50.0 { return v }
        if v == 0.0 { return 25.0 }
        return v < 37.5 ? 25.0 : 50.0
    }() {
        didSet { UserDefaults.standard.set(poolLength, forKey: "poolLengthMeters") }
    }
    private var workoutStartTime: Date?
    private var lapTimes: [Double] = []
    private var lapStrokes: [Int] = []
    private var heartRates: [Double] = []

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var timer: Timer?

    override init() {
        super.init()
        requestAuthorization()
        refreshPendingCount()
        retryPendingSyncs()
        // Retry whenever the app comes back to the foreground (e.g. connectivity restored).
        NotificationCenter.default.addObserver(
            forName: WKApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.retryPendingSyncs() }
    }

    func requestAuthorization() {
        #if targetEnvironment(simulator)
        print("Running in simulator - HealthKit limited")
        return
        #else
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.swimmingStrokeCount),
            HKQuantityType(.distanceSwimming)
        ]
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        #endif
    }

    func startWorkout() {
        resetWorkoutState()
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.isWorkoutActive = true
            self.workoutStartTime = Date()
            self.startTimer()
        }
        return
        #else
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .swimming
        configuration.locationType = .indoor
        configuration.swimmingLocationType = .pool
        configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: poolLength)
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isWorkoutActive = true
                        self.workoutStartTime = startDate
                        self.startTimer()
                    }
                }
            }
        } catch {
            print("Failed to start workout: \(error.localizedDescription)")
        }
        #endif
    }

    func stopWorkout() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.isWorkoutActive = false
            self.stopTimer()
            self.saveWorkoutToSwiftLap()
        }
        return
        #else
        workoutSession?.end()
        #endif
    }

    func markLap() {
        let lapTime = Double(elapsedSeconds) - lapTimes.reduce(0, +)
        lapTimes.append(lapTime)
        lapStrokes.append(strokeCount - lapStrokes.reduce(0, +))
        lapCount += 1
        distance = Double(lapCount) * poolLength
        #if targetEnvironment(simulator)
        heartRate = Double.random(in: 120...160)
        heartRates.append(heartRate)
        strokeCount += Int.random(in: 14...20)
        #endif
        updatePace()
        updateFatigue()
    }

    private func resetWorkoutState() {
        elapsedSeconds = 0
        lapCount = 0
        distance = 0
        strokeCount = 0
        heartRate = 0
        calories = 0
        currentPace = "--:--"
        avgStrokesPerLap = 0
        fatigueLevel = "Fresh 💪"
        lapTimes = []
        lapStrokes = []
        heartRates = []
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async { self.elapsedSeconds += 1 }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePace() {
        if lapCount > 0 && elapsedSeconds > 0 {
            let avgSecondsPerLap = Double(elapsedSeconds) / Double(lapCount)
            currentPace = String(format: "%d:%02d", Int(avgSecondsPerLap) / 60, Int(avgSecondsPerLap) % 60)
        }
    }

    private func updateFatigue() {
        guard lapTimes.count >= 1 else { return }
        var fatigueScore = 0.0
        if lapTimes.count >= 2 {
            let recentLaps = lapTimes.suffix(3)
            let firstLaps = lapTimes.prefix(3)
            let recentAvg = recentLaps.reduce(0, +) / Double(recentLaps.count)
            let firstAvg = firstLaps.reduce(0, +) / Double(firstLaps.count)
            fatigueScore = ((recentAvg - firstAvg) / firstAvg) * 100
        }
        if heartRates.count >= 2 {
            let recentHR = heartRates.suffix(5).reduce(0, +) / Double(min(5, heartRates.count))
            let startHR = heartRates.prefix(5).reduce(0, +) / Double(min(5, heartRates.count))
            let hrFactor = ((recentHR - startHR) / max(startHR, 1)) * 100
            fatigueScore += (hrFactor * 0.5)
        }
        DispatchQueue.main.async {
            if self.lapCount <= 2 { self.fatigueLevel = "Fresh 💪" }
            else if fatigueScore < 5 { self.fatigueLevel = "Fresh 💪" }
            else if fatigueScore < 10 { self.fatigueLevel = "Moderate 😊" }
            else if fatigueScore < 18 { self.fatigueLevel = "Tired 😓" }
            else { self.fatigueLevel = "Exhausted 🥵" }
        }
    }

    private func saveWorkoutToSwiftLap() {
        guard let swimmerId = WatchStore.swimmerId() else {
            print("No swimmer ID stored - workout saved locally only")
            return
        }
        let avgHR = heartRates.isEmpty ? 0.0 : heartRates.reduce(0, +) / Double(heartRates.count)
        // Capture the values now (before the async hop) into the persistable payload.
        let payload = PendingWorkout(
            swimmerId: swimmerId, duration: elapsedSeconds, distance: distance, laps: lapCount,
            strokeCount: strokeCount, avgHeartRate: avgHR, calories: calories,
            lapTimes: lapTimes, lapStrokes: lapStrokes, fatigueLevel: fatigueLevel, poolLength: poolLength
        )
        Task {
            do {
                try await send(payload)
                print("Workout synced to SwiftLap!")
            } catch {
                // Network/server failure — persist to disk and retry on next launch/foreground.
                print("Sync failed, queuing for retry: \(error.localizedDescription)")
                queueWorkout(payload)
            }
        }
    }

    private func send(_ p: PendingWorkout) async throws {
        try await APIClient.shared.sendWatchWorkout(
            swimmerId: p.swimmerId, duration: p.duration, distance: p.distance, laps: p.laps,
            strokeCount: p.strokeCount, avgHeartRate: p.avgHeartRate, calories: p.calories,
            lapTimes: p.lapTimes, lapStrokes: p.lapStrokes, fatigueLevel: p.fatigueLevel,
            poolLength: p.poolLength, watchToken: WatchStore.watchToken()
        )
    }

    // MARK: - Pending sync queue (offline resilience)

    private var pendingDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending")
    }

    private func ensurePendingDir() {
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)
    }

    private func queueWorkout(_ payload: PendingWorkout) {
        ensurePendingDir()
        let file = pendingDir.appendingPathComponent("\(UUID().uuidString).json")
        try? JSONEncoder().encode(payload).write(to: file)
        refreshPendingCount()
    }

    private func refreshPendingCount() {
        let count = (try? FileManager.default.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "json" }.count ?? 0
        DispatchQueue.main.async { self.pendingSyncCount = count }
    }

    /// Re-upload any workouts that previously failed to sync; delete each on success.
    func retryPendingSyncs() {
        ensurePendingDir()
        guard let files = try? FileManager.default.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let payload = try? JSONDecoder().decode(PendingWorkout.self, from: data) else { continue }
            Task {
                do {
                    try await send(payload)
                    try? FileManager.default.removeItem(at: file)
                    refreshPendingCount()
                } catch {
                    // Still failing — keep the file for the next retry.
                }
            }
        }
    }

    func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .ended else { return }
        workoutBuilder?.endCollection(withEnd: date) { _, _ in
            self.workoutBuilder?.finishWorkout { _, _ in
                DispatchQueue.main.async {
                    self.isWorkoutActive = false
                    self.stopTimer()
                    self.saveWorkoutToSwiftLap()
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType(.heartRate):
                    let hr = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
                    self.heartRate = hr
                    self.heartRates.append(hr)
                case HKQuantityType(.swimmingStrokeCount):
                    self.strokeCount = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                case HKQuantityType(.activeEnergyBurned):
                    self.calories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                case HKQuantityType(.distanceSwimming):
                    let dist = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                    if dist > self.distance {
                        self.distance = dist
                        self.lapCount = Int(dist / self.poolLength)
                    }
                default:
                    break
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
