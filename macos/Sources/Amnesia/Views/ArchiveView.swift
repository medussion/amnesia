import SwiftUI

struct ArchiveView: View {
    @ObservedObject var model: AppModel
    let archives: [ArchiveItem]
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("아카이브 영구 삭제")
                        .font(.title3.weight(.semibold))
                    Text("삭제는 되돌릴 수 없습니다. 아무 항목도 기본 선택되지 않습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if archives.isEmpty {
                EmptyState(
                    symbol: "archivebox",
                    title: "아카이브가 없습니다",
                    detail: "영구 삭제할 보관 세션을 찾지 못했습니다."
                )
            } else {
                List(archives) { archive in
                    Toggle(
                        isOn: Binding(
                            get: { model.selectedArchiveKeys.contains(archive.key) },
                            set: { selected in
                                if selected {
                                    model.selectedArchiveKeys.insert(archive.key)
                                } else {
                                    model.selectedArchiveKeys.remove(archive.key)
                                }
                            }
                        )
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(archive.label)
                                    .lineLimit(2)
                                Text(archive.linked ? "DB 연결됨" : "고아 파일")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formattedBytes(archive.bytes))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            HStack {
                TextField("영구 삭제", text: $confirmation)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Text("확인을 위해 ‘영구 삭제’를 입력하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("선택 항목 영구 삭제", role: .destructive) {
                    let phrase = confirmation
                    confirmation = ""
                    Task { await model.purge(confirmation: phrase) }
                }
                .disabled(
                    confirmation != "영구 삭제"
                        || model.selectedArchiveKeys.isEmpty
                        || model.codexIsRunning
                        || model.isBusy
                )
            }
        }
    }
}
