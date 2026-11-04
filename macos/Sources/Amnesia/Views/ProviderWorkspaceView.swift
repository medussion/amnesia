import SwiftUI

struct ProviderWorkspaceView: View {
    @ObservedObject var model: AppModel
    let provider: AssistantProvider

    var body: some View {
        if provider.isAvailable {
            codexWorkspace
        } else {
            UnsupportedProviderView(provider: provider)
        }
    }

    @ViewBuilder
    private var codexWorkspace: some View {
        if let state = model.state {
            TabView {
                workspacePage {
                    DashboardView(model: model, state: state)
                }
                .tabItem { Label("정리", systemImage: "sparkles") }

                workspacePage {
                    HandoffView(model: model, sessions: state.sessions)
                }
                .tabItem { Label("Handoff", systemImage: "doc.text") }

                workspacePage {
                    ArchiveView(model: model, archives: state.archives)
                }
                .tabItem { Label("아카이브", systemImage: "archivebox") }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
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

    private func workspacePage<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 30)
            .padding(.top, 28)
            .padding(.bottom, 26)
    }
}

private struct UnsupportedProviderView: View {
    let provider: AssistantProvider

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "shippingbox.and.arrow.backward")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 82, height: 82)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 22))
            Text("\(provider.name) 어댑터 준비 중")
                .font(.title2.weight(.bold))
            Text("이 브랜드의 로컬 데이터 구조를 검증한 뒤 정리·Handoff·아카이브를 연결합니다.\n현재 Codex 데이터를 대신 표시하거나 수정하지 않습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Label(provider.summary, systemImage: "folder.badge.gearshape")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.quaternary.opacity(0.35), in: Capsule())
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
