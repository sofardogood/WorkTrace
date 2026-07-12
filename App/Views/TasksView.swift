import SwiftUI
import WTCore

struct TasksView: View {
    @Environment(AppState.self) private var appState

    @State private var projects: [Project] = []
    @State private var tasksByProject: [Int64: [WorkTask]] = [:]
    @State private var newProjectName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("tasks.projects").font(.title2).bold()
                Spacer()
            }
            .padding()

            HStack {
                TextField("tasks.projectName", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                Button("tasks.addProject", action: addProject)
                    .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)

            if projects.isEmpty {
                ContentUnavailableView("tasks.empty", systemImage: "folder")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(projects) { project in
                        projectSection(project)
                    }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 460)
        .task { reload() }
    }

    private func projectSection(_ project: Project) -> some View {
        Section {
            ForEach(tasksByProject[project.id ?? -1] ?? []) { task in
                HStack {
                    Circle().fill(.blue.opacity(0.6)).frame(width: 8, height: 8)
                    Text(task.name)
                    if task.billable {
                        Text("tasks.billable").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                    Spacer()
                    Button(role: .destructive) {
                        if let id = task.id { try? appState.tasks.delete(id: id); reload() }
                    } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
            AddTaskRow { name in addTask(name, to: project) }
        } header: {
            HStack {
                Text(project.name).font(.headline)
                Spacer()
                Button(role: .destructive) {
                    if let id = project.id { try? appState.projects.delete(id: id); reload() }
                } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Actions

    private func addProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        _ = try? appState.projects.save(Project(name: name))
        newProjectName = ""
        reload()
    }

    private func addTask(_ name: String, to project: Project) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        _ = try? appState.tasks.save(WorkTask(projectId: project.id, name: trimmed))
        reload()
    }

    private func reload() {
        projects = (try? appState.projects.all()) ?? []
        let all = (try? appState.tasks.all(includeArchived: false)) ?? []
        tasksByProject = Dictionary(grouping: all, by: { $0.projectId ?? -1 })
    }
}

/// Inline "add task" field shown at the bottom of each project section.
private struct AddTaskRow: View {
    let onAdd: (String) -> Void
    @State private var name: String = ""

    var body: some View {
        HStack {
            TextField("tasks.taskName", text: $name)
                .textFieldStyle(.roundedBorder)
            Button("tasks.addTask") {
                onAdd(name)
                name = ""
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
