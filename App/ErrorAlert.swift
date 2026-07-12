import SwiftUI

/// A user-facing, localized error. Views hold an optional `AppError` and present
/// it with `.errorAlert(_:)`. Messages are bilingual through the string catalog,
/// so the same failure reads correctly in whichever UI language is active.
struct AppError: Identifiable {
    let id = UUID()
    let messageKey: LocalizedStringKey

    static let database        = AppError(messageKey: "error.database")
    static let backupFailed    = AppError(messageKey: "error.backupFailed")
    static let restoreFailed   = AppError(messageKey: "error.restoreFailed")
    static let exportFailed    = AppError(messageKey: "error.exportFailed")
    static let permission      = AppError(messageKey: "error.permission")
    static let splitFailed     = AppError(messageKey: "error.splitFailed")
    static let mergeFailed     = AppError(messageKey: "error.mergeFailed")

    // Restore validation failures, each explaining exactly why the chosen file
    // was rejected. In every case the live database is left untouched.
    static let backupFileMissing = AppError(messageKey: "error.backup.fileMissing")
    static let backupNotReadable = AppError(messageKey: "error.backup.notReadable")
    static let backupNotSQLite   = AppError(messageKey: "error.backup.notSQLite")
    static let backupNotWorkTrace = AppError(messageKey: "error.backup.notWorkTrace")
}

extension View {
    /// Presents `error` as a dismissible alert with a localized title.
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        alert(
            Text("error.title"),
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { _ in
            Button("common.done", role: .cancel) { error.wrappedValue = nil }
        } message: { err in
            Text(err.messageKey)
        }
    }
}
