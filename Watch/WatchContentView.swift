//
//  WatchContentView.swift
//  SwiftLap (watchOS)
//
//  Migrated from SwiftLapWatch. Fix vs the original: the START screen is now
//  wrapped in a ScrollView so the gear/logout buttons are reachable on small
//  watch faces (previously they were clipped with no way to scroll).
//

import SwiftUI

struct WatchContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    @State private var showingSettings = false
    @State private var isLoggedIn = WatchStore.swimmerId() != nil

    var body: some View {
        NavigationStack {
            if !isLoggedIn {
                WatchLoginView(isLoggedIn: $isLoggedIn)
            } else if workoutManager.isWorkoutActive {
                ScrollView {
                    VStack(spacing: 12) {
                        Text(workoutManager.formatTime(workoutManager.elapsedSeconds))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            StatBox(title: "Laps", value: "\(workoutManager.lapCount)", icon: "arrow.triangle.2.circlepath")
                            StatBox(title: "Heart", value: "\(Int(workoutManager.heartRate))", icon: "heart.fill", color: .red)
                            StatBox(title: "Strokes", value: "\(workoutManager.strokeCount)", icon: "figure.pool.swim")
                            StatBox(title: "Pace", value: workoutManager.currentPace, icon: "speedometer")
                        }
                        HStack {
                            Image(systemName: "ruler")
                            Text("\(Int(workoutManager.distance))m").font(.title3.bold())
                        }
                        .foregroundColor(.green)
                        Text(workoutManager.fatigueLevel)
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(fatigueColor.opacity(0.3))
                            .cornerRadius(8)
                        HStack(spacing: 20) {
                            Button(action: { workoutManager.markLap() }) {
                                Image(systemName: "flag.fill").font(.title2)
                            }
                            .buttonStyle(.borderedProminent).tint(.orange)
                            Button(action: { workoutManager.stopWorkout() }) {
                                Image(systemName: "stop.fill").font(.title2)
                            }
                            .buttonStyle(.borderedProminent).tint(.red)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.pool.swim")
                            .font(.system(size: 50))
                            .foregroundColor(.cyan)
                        Text("SwiftLap").font(.title2.bold())
                        Text("Pool: \(Int(workoutManager.poolLength))m")
                            .font(.caption).foregroundColor(.secondary)
                        Button(action: { workoutManager.startWorkout() }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Swim")
                            }
                            .font(.headline)
                        }
                        .buttonStyle(.borderedProminent).tint(.cyan)
                        if workoutManager.pendingSyncCount > 0 {
                            Button(action: { workoutManager.retryPendingSyncs() }) {
                                Text("↑ \(workoutManager.pendingSyncCount) pending sync\(workoutManager.pendingSyncCount == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                            .buttonStyle(.bordered)
                            Button(action: logout) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                            }
                            .buttonStyle(.bordered).tint(.red)
                        }
                    }
                    .padding()
                }
                .sheet(isPresented: $showingSettings) {
                    WatchSettingsView(poolLength: $workoutManager.poolLength)
                }
            }
        }
    }

    var fatigueColor: Color {
        switch workoutManager.fatigueLevel {
        case let level where level.contains("Fresh"): return .green
        case let level where level.contains("Moderate"): return .yellow
        case let level where level.contains("Tired"): return .orange
        default: return .red
        }
    }

    func logout() {
        WatchStore.clear()
        isLoggedIn = false
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .cyan

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color)
            Text(value).font(.headline.bold())
            Text(title).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

struct WatchSettingsView: View {
    @Binding var poolLength: Double
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Pool Length").font(.headline)
            Picker("Pool", selection: $poolLength) {
                Text("25 m").tag(25.0)
                Text("50 m").tag(50.0)
            }
            .pickerStyle(.wheel)
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
