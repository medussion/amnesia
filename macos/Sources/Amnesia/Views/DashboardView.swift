import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    let state: BridgeState
    @State private var showingApply = false
    @State private var archiveAcknowledged = false

    private var selectedBytes: Int64 {
        state.items
            .filter { model.selectedPlanKeys.contains($0.key) }
            .reduce(0) { $0 + $1.bytes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                MetricCard(
                    title: "판정",
                    value: verdictLabel,
                    symbol: verdictSymbol,
                    tint: verdictTint
                )
                MetricCard(
                    title: "정리 가능",
                    value: formattedBytes(state.reclaimableBytes),
                    symbol: "externaldrive"
                )
                MetricCard(
                    title: "계획 항목",
                    value: "\(state.items.count)개",
                    symbol: "checklist"
                )
                MetricCard(
                    title: "Codex",
                    value: state.codexRunning.isEmpty ? "종료됨" : "실행 중",
                    symbol: state.codexRunning.isEmpty ? "checkmark.shield" : "lock.fill",
                    tint: state.codexRunning.isEmpty ? .green : .orange
                )
            }

            GroupBox("정리 계획") {
                if state.items.isEmpty {
                    EmptyState(
                        symbol: "checkmark.circle",
                        title: "정리할 항목이 없습니다",
                        detail: "현재 설정 기준으로 Codex 상태가 깨끗합니다."
                    )
                    .frame(height: 260)
                } else {
                    List(state.items) { item in
                        Toggle(
                            isOn: Binding(
                                get: { model.selectedPlanKeys.contains(item.key) },
                                set: { selected in
                                    if selected {
                                        model.selectedPlanKeys.insert(item.key)
                                    } else {
                                        model.selectedPlanKeys.remove(item.key)
                                    }
                                }
                            )
                        ) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.label)
                                    Text(item.task)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formattedBytes(item.bytes))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                    .frame(minHeight: 250)
                }
            }

            HStack {
                Text("백업: \(state.backupRoot)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Spacer()
                if state.lastJournal != nil {
                    Button("최근 작업 복원") {
                        Task { await model.restoreLatest() }
                    }
                    .disabled(model.codexIsRunning || model.isBusy)
                }
                Button {
                    archiveAcknowledged = false
                    showingApply = true
                } label: {
                    Label(
                        "\(formattedBytes(selectedBytes)) 정리",
                        systemImage: "sparkles"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.selectedPlanKeys.isEmpty || model.codexIsRunning || model.isBusy
                )
            }
        }
        .sheet(isPresented: $showingApply) {
            VStack(alignment: .leading, spacing: 18) {
                Text("정리 계획 실행")
                    .font(.title2.weight(.bold))
                Text("선택한 항목은 먼저 백업된 뒤 아카이브됩니다. Handoff 대상으로 선택하지 않은 세션도 포함될 수 있습니다.")
                    .foregroundStyle(.secondary)
                Toggle(
                    "계속할 프로젝트는 Handoff 탭에서 선택했으며, 나머지 세션의 아카이브를 확인했습니다.",
                    isOn: $archiveAcknowledged
                )
                Divider()
                HStack {
                    Button("취소", role: .cancel) {
                        showingApply = false
                    }
                    Spacer()
                    Button("백업 후 정리") {
                        showingApply = false
                        Task { await model.applyPlan(allowWithoutHandoff: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!archiveAcknowledged)
                }
            }
            .padding(24)
            .frame(width: 560)
        }
    }

    private var verdictLabel: String {
        switch state.assessment.verdict {
        case "now": return "정리 권장"
        case "soon": return "곧 점검"
        default: return "양호"
        }
    }

    private var verdictSymbol: String {
        state.assessment.verdict == "now" ? "exclamationmark.triangle" : "gauge.with.dots.needle.50percent"
    }

    private var verdictTint: Color {
        switch state.assessment.verdict {
        case "now": return .orange
        case "soon": return .yellow
        default: return .green
        }
    }
}
