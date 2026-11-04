import Foundation

struct BridgeState: Decodable {
    let ok: Bool
    let home: String
    let backupRoot: String
    let assessment: Assessment
    let items: [PlanItem]
    let sessions: [SessionItem]
    let archives: [ArchiveItem]
    let findings: [Finding]
    let operationCount: Int
    let reclaimableBytes: Int64
    let activeFootprintBytes: Int64
    let capacityGaugeBytes: Int64
    let codexRunning: [CodexProcess]
    let lastJournal: String?

    enum CodingKeys: String, CodingKey {
        case ok, home, assessment, items, sessions, archives, findings
        case backupRoot = "backup_root"
        case operationCount = "operation_count"
        case reclaimableBytes = "reclaimable_bytes"
        case activeFootprintBytes = "active_footprint_bytes"
        case capacityGaugeBytes = "capacity_gauge_bytes"
        case codexRunning = "codex_running"
        case lastJournal = "last_journal"
    }
}

struct Assessment: Decodable {
    let verdict: String
    let reclaimableBytes: Int64
    let blocked: Bool

    enum CodingKeys: String, CodingKey {
        case verdict, blocked
        case reclaimableBytes = "reclaimable_bytes"
    }
}

struct PlanItem: Decodable, Identifiable, Hashable {
    let key: String
    let task: String
    let label: String
    let bytes: Int64
    let operations: Int

    var id: String { key }
}

struct SessionItem: Decodable, Identifiable {
    let key: String
    let label: String
    let project: String?
    let updatedAt: Int64?
    let pinned: Bool
    let isChild: Bool
    let bytes: Int64
    let handoff: HandoffStatus
    let importance: Importance

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, label, project, pinned, bytes, handoff, importance
        case updatedAt = "updated_at"
        case isChild = "is_child"
    }
}

struct HandoffStatus: Decodable {
    let state: String?
    let ready: Bool?
    let document: String?
    let reason: String?
}

struct Importance: Decodable {
    let level: String
    let label: String
    let reason: String
    let ageDays: Int?

    enum CodingKeys: String, CodingKey {
        case level, label, reason
        case ageDays = "age_days"
    }
}

struct ArchiveItem: Decodable, Identifiable {
    let key: String
    let label: String
    let bytes: Int64
    let updatedAt: Int64
    let linked: Bool
    let project: String?

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, label, bytes, linked, project
        case updatedAt = "updated_at"
    }
}

struct Finding: Decodable, Identifiable {
    let task: String
    let code: String
    let level: String
    let message: String
    let count: Int
    let bytes: Int64

    var id: String { "\(task):\(code):\(message)" }
}

struct CodexProcess: Decodable, Identifiable {
    let pid: Int
    let name: String
    let reason: String

    var id: Int { pid }
}

struct ActionResult: Decodable {
    let ok: Bool
    let blocked: [String]?
    let notes: [String]?
    let completed: Int?
    let planned: Int?
    let generated: Int?
    let requested: Int?
    let deleted: Int?
    let deletedBytes: Int64?
    let undone: Int?
    let journal: String?
    let backupRoot: String?
    let nothingToDo: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, blocked, notes, completed, planned, generated, requested
        case deleted, undone, journal, error
        case deletedBytes = "deleted_bytes"
        case backupRoot = "backup_root"
        case nothingToDo = "nothing_to_do"
    }

    var message: String {
        if let blocked, !blocked.isEmpty {
            return blocked.joined(separator: "\n")
        }
        if let error, !error.isEmpty {
            return error
        }
        if let generated {
            return "Handoff \(generated)개를 생성했습니다."
        }
        if let deleted {
            return "아카이브 \(deleted)개를 영구 삭제했습니다."
        }
        if let undone {
            return "작업 \(undone)개를 복원했습니다."
        }
        if nothingToDo == true {
            return "정리할 항목이 없습니다."
        }
        if let completed {
            return "계획한 작업 중 \(completed)개를 완료했습니다."
        }
        return ok ? "작업을 완료했습니다." : "작업을 완료하지 못했습니다."
    }
}
