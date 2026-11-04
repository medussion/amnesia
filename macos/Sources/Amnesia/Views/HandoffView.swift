import SwiftUI

struct HandoffView: View {
    @ObservedObject var model: AppModel
    let sessions: [SessionItem]

    private var visibleSessions: [SessionItem] {
        sessions.filter { !$0.isChild && $0.importance.level != "archived" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("계속할 프로젝트")
                        .font(.title3.weight(.semibold))
                    Text("새 대화에서 이어갈 세션만 선택해 bounded Handoff를 생성합니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.generateHandoffs() }
                } label: {
                    Label("Handoff 생성", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.continuingSessionKeys.isEmpty || model.isBusy)
            }

            if visibleSessions.isEmpty {
                EmptyState(
                    symbol: "text.bubble",
                    title: "세션이 없습니다",
                    detail: "Handoff를 생성할 활성 세션을 찾지 못했습니다."
                )
            } else {
                List(visibleSessions) { session in
                    Toggle(
                        isOn: Binding(
                            get: { model.continuingSessionKeys.contains(session.key) },
                            set: { selected in
                                if selected {
                                    model.continuingSessionKeys.insert(session.key)
                                } else {
                                    model.continuingSessionKeys.remove(session.key)
                                }
                            }
                        )
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: session.handoff.ready == true ? "checkmark.seal.fill" : "doc.text")
                                .foregroundStyle(session.handoff.ready == true ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.label)
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    if let project = session.project {
                                        Text(project)
                                    }
                                    Text(session.importance.label)
                                    Text(formattedBytes(session.bytes))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if session.pinned {
                                Label("고정", systemImage: "pin.fill")
                                    .font(.caption)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}
