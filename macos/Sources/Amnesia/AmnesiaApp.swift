import SwiftUI

@main
struct AmnesiaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 920, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1080, height: 760)

        Settings {
            SettingsView()
        }
    }
}

private struct SettingsView: View {
    var body: some View {
        Form {
            LabeledContent("앱") {
                Text("Amnesia")
            }
            LabeledContent("Bundle ID") {
                Text("medusia.com.amnesia")
                    .textSelection(.enabled)
            }
            Text("자동 정리는 수행하지 않습니다. 모든 변경은 사용자가 계획을 확인하고 실행해야 합니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 460)
    }
}
