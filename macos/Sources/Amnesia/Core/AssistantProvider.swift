import Foundation

enum ProviderSupport: String {
    case available
    case planned
}

struct AssistantProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let company: String
    let summary: String
    let support: ProviderSupport

    var isAvailable: Bool { support == .available }

    static let catalog: [AssistantProvider] = [
        AssistantProvider(
            id: "codex",
            name: "Codex",
            company: "OpenAI",
            summary: "세션 · Worktree · 로그",
            support: .available
        ),
        AssistantProvider(
            id: "claude-code",
            name: "Claude Code",
            company: "Anthropic",
            summary: "프로젝트 · 대화 기록",
            support: .planned
        ),
        AssistantProvider(
            id: "gemini-cli",
            name: "Gemini CLI",
            company: "Google",
            summary: "채팅 · 프로젝트 캐시",
            support: .planned
        ),
        AssistantProvider(
            id: "cursor",
            name: "Cursor",
            company: "Anysphere",
            summary: "Workspace · Composer",
            support: .planned
        ),
        AssistantProvider(
            id: "windsurf",
            name: "Devin Desktop",
            company: "Cognition · Windsurf",
            summary: "Workspace · Cascade",
            support: .planned
        ),
        AssistantProvider(
            id: "copilot",
            name: "GitHub Copilot",
            company: "GitHub",
            summary: "대화 · 작업 공간",
            support: .planned
        ),
    ]
}
