import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: BridgeState?
    @Published var selectedPlanKeys: Set<String> = []
    @Published var continuingSessionKeys: Set<String> = []
    @Published var selectedArchiveKeys: Set<String> = []
    @Published var isBusy = false
    @Published var message: String?

    private let client = EngineClient()

    var codexIsRunning: Bool {
        !(state?.codexRunning.isEmpty ?? true)
    }

    var capacityFill: Double {
        guard let state, state.capacityGaugeBytes > 0 else { return 0 }
        return min(
            max(Double(state.activeFootprintBytes) / Double(state.capacityGaugeBytes), 0),
            1
        )
    }

    func refresh() async {
        await execute {
            let latest = try await client.state()
            let available = Set(latest.items.map(\.key))
            if selectedPlanKeys.isEmpty {
                selectedPlanKeys = available
            } else {
                selectedPlanKeys.formIntersection(available)
            }
            continuingSessionKeys.formIntersection(Set(latest.sessions.map(\.key)))
            selectedArchiveKeys.formIntersection(Set(latest.archives.map(\.key)))
            state = latest
        }
    }

    func generateHandoffs() async {
        let keys = Array(continuingSessionKeys)
        await action(
            command: "handoff",
            payload: ["session_keys": keys]
        )
    }

    func applyPlan(allowWithoutHandoff: Bool) async {
        guard let state else { return }
        let excluded = state.items.map(\.key).filter { !selectedPlanKeys.contains($0) }
        await action(
            command: "apply",
            payload: [
                "excluded": excluded,
                "handoff_required": Array(continuingSessionKeys),
                "allow_without_handoff": allowWithoutHandoff,
            ]
        )
    }

    func restoreLatest() async {
        await action(command: "restore", payload: [:])
    }

    func purge(confirmation: String) async {
        await action(
            command: "purge",
            payload: [
                "archive_keys": Array(selectedArchiveKeys),
                "confirmation": confirmation,
            ]
        )
    }

    private func action(command: String, payload: [String: Any]) async {
        await execute {
            let result = try await client.action(command: command, payload: payload)
            message = result.message
            if result.ok {
                state = try await client.state()
                selectedPlanKeys = Set(state?.items.map(\.key) ?? [])
                selectedArchiveKeys.removeAll()
            }
        }
    }

    private func execute(_ operation: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await operation()
        } catch {
            message = error.localizedDescription
        }
    }
}
