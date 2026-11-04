import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if let state = model.state {
                    TabView {
                        DashboardView(model: model, state: state)
                            .tabItem { Label("정리", systemImage: "sparkles") }
                        HandoffView(model: model, sessions: state.sessions)
                            .tabItem { Label("Handoff", systemImage: "doc.text") }
                        ArchiveView(model: model, archives: state.archives)
                            .tabItem { Label("아카이브", systemImage: "archivebox") }
                    }
                    .padding(18)
                } else if model.isBusy {
                    ProgressView("Codex 상태를 읽는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyState(
                        symbol: "externaldrive.badge.questionmark",
                        title: "Codex 상태를 읽지 못했습니다",
                        detail: "새로고침을 눌러 다시 시도하세요."
                    )
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if model.isBusy, model.state != nil {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .task {
            if model.state == nil {
                await model.refresh()
            }
        }
        .alert(
            "Amnesia",
            isPresented: Binding(
                get: { model.message != nil },
                set: { if !$0 { model.message = nil } }
            )
        ) {
            Button("확인") { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 24))
                .foregroundStyle(.purple)
                .frame(width: 40, height: 40)
                .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text("Amnesia")
                    .font(.title2.weight(.bold))
                Text("Codex 로컬 상태를 안전하게 정리하고 되돌립니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.codexIsRunning {
                Label("Codex 실행 중", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            } else if model.state != nil {
                Label("변경 가능", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Button {
                Task { await model.refresh() }
            } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
