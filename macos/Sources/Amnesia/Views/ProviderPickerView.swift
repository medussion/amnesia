import AppKit
import SwiftUI

struct ProviderPickerView: View {
    let providers: [AssistantProvider]
    let onSelect: (AssistantProvider) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 240), spacing: 18, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("정리할 AI 작업 공간을 선택하세요")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("각 도구의 로컬 기록을 별도 어댑터로 읽고, 안전하게 백업·Handoff·정리합니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(providers) { provider in
                        ProviderCard(provider: provider) {
                            onSelect(provider)
                        }
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 30)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ProviderCard: View {
    let provider: AssistantProvider
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    providerMark
                    Spacer()
                    statusBadge
                }

                Spacer(minLength: 20)

                Text(provider.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(provider.company)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
                Text(provider.summary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 184, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.78))
                    .shadow(
                        color: provider.accent.opacity(hovering ? 0.20 : 0.08),
                        radius: hovering ? 18 : 9,
                        y: 7
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        hovering ? provider.accent.opacity(0.62) : Color.white.opacity(0.07),
                        lineWidth: hovering ? 1.2 : 1
                    )
            }
            .scaleEffect(hovering ? 1.015 : 1)
            .animation(.easeOut(duration: 0.16), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityHint(provider.isAvailable ? "정리 작업 공간 열기" : "지원 준비 상태 보기")
    }

    private var providerMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 64, height: 64)
                .shadow(color: provider.accent.opacity(0.28), radius: 12, y: 4)
            if let image = provider.logoImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else {
                Image(systemName: provider.symbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var statusBadge: some View {
        Text(provider.isAvailable ? "사용 가능" : "준비 중")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(provider.isAvailable ? Color.green : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                (provider.isAvailable ? Color.green : Color.secondary).opacity(0.10),
                in: Capsule()
            )
    }
}

private extension AssistantProvider {
    var accent: Color {
        switch id {
        case "codex": return Color(red: 0.20, green: 0.78, blue: 0.62)
        case "claude-code": return Color(red: 0.86, green: 0.47, blue: 0.30)
        case "gemini-cli": return Color(red: 0.42, green: 0.51, blue: 0.96)
        case "cursor": return Color(red: 0.72, green: 0.48, blue: 0.96)
        case "windsurf": return Color(red: 0.10, green: 0.73, blue: 0.91)
        default: return Color(red: 0.32, green: 0.39, blue: 0.48)
        }
    }

    var logoImage: NSImage? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let url = resources
            .appendingPathComponent("BrandLogos", isDirectory: true)
            .appendingPathComponent("\(id).png")
        return NSImage(contentsOf: url)
    }

    var symbol: String {
        switch id {
        case "codex": return "terminal.fill"
        case "claude-code": return "sparkles"
        case "gemini-cli": return "diamond.fill"
        case "cursor": return "cursorarrow.motionlines"
        case "windsurf": return "wind"
        default: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
