import Foundation
import WTCore

/// Report-language strings. These are deliberately separate from the app UI's
/// `.xcstrings`: report language is chosen independently of UI language, so a
/// Japanese UI can emit an English client report from the same session data.
enum ReportStrings {
    static func dailyTitle(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "業務日報"
        case .english:  return "Daily Work Report"
        }
    }

    static func sectionWorkDone(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "本日の作業内容"
        case .english:  return "Work Done"
        }
    }

    static func sectionResults(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "成果"
        case .english:  return "Results"
        }
    }

    static func sectionIssues(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "課題"
        case .english:  return "Issues"
        }
    }

    static func sectionPlan(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "明日の予定"
        case .english:  return "Plan for Tomorrow"
        }
    }

    static func sectionUnclassified(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "未分類時間"
        case .english:  return "Unclassified Time"
        }
    }

    static func sectionQuestions(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "確認事項"
        case .english:  return "Questions"
        }
    }

    static func totalLabel(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "合計時間"
        case .english:  return "Total"
        }
    }

    static func noTask(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "（タスク未設定）"
        case .english:  return "(No task)"
        }
    }

    static func placeholder(_ lang: ReportLanguage) -> String {
        switch lang {
        case .japanese: return "（記入してください）"
        case .english:  return "(to be filled in)"
        }
    }

    // CSV column headers.
    static func csvHeader(_ lang: ReportLanguage) -> [String] {
        switch lang {
        case .japanese:
            return ["日付", "開始", "終了", "時間(分)", "タスク", "プロジェクト", "請求可否", "メモ"]
        case .english:
            return ["Date", "Start", "End", "Minutes", "Task", "Project", "Billable", "Memo"]
        }
    }
}
