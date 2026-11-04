import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()
    @State private var selectedProvider: AssistantProvider?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let selectedProvider {
                ProviderWorkspaceView(model: model, provider: selectedProvider)
            } else {
                ProviderPickerView(providers: AssistantProvider.catalog) { provider in
                    selectedProvider = provider
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
        .task(id: selectedProvider?.id) {
            if selectedProvider?.isAvailable == true, model.state == nil {
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
            if selectedProvider != nil {
                Button {
                    selectedProvider = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help("브랜드 선택으로 돌아가기")
            }
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 24))
                .foregroundStyle(.purple)
                .frame(width: 40, height: 40)
                .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text("Amnesia")
                    .font(.title2.weight(.bold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selectedProvider?.isAvailable == true, model.codexIsRunning {
                Label("Codex 실행 중", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            } else if selectedProvider?.isAvailable == true, model.state != nil {
                Label("변경 가능", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if selectedProvider?.isAvailable == true {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var headerSubtitle: String {
        if let selectedProvider {
            return "\(selectedProvider.name) 로컬 작업 공간"
        }
        return "AI 도구의 로컬 기억을 안전하게 정리합니다."
    }
}
