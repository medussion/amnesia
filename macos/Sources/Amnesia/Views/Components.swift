import SwiftUI

func formattedBytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
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
