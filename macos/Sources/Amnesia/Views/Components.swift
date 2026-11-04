import SwiftUI

func formattedBytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
}

struct BrainCapacityGauge: View {
    let progress: Double
    let activeBytes: Int64?
    let capacityBytes: Int64?

    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var statusText: String {
        guard let activeBytes, let capacityBytes else {
            return "용량을 측정하려면 도구를 선택하세요."
        }
        return "활성 데이터 \(formattedBytes(activeBytes)) / \(formattedBytes(capacityBytes))"
    }

    var body: some View {
        ZStack {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.secondary.opacity(0.52))

            Image(systemName: "brain.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.72), .purple],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .mask {
                    GeometryReader { proxy in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .frame(height: proxy.size.height * normalizedProgress)
                        }
                    }
                }
                .offset(x: -3.5, y: -5.5)
        }
        .font(.system(size: 27, weight: .medium))
        .frame(width: 34, height: 40)
        .animation(.spring(response: 0.44, dampingFraction: 0.86), value: normalizedProgress)
        .help(statusText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("활성 데이터 용량")
        .accessibilityValue(statusText)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
