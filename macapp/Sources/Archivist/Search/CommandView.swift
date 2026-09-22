import SwiftUI

/// "create a folder for anything related to my bank and put those files in it" —
/// always proposes the matched files and destination before moving anything;
/// see plan.md section 5/6/8.
struct CommandView: View {
    let interpreter: CommandInterpreter
    @State private var instruction: String = ""
    @State private var proposal: ProposedAction?
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let examples = [
        "Put my bank files in one folder",
        "Group all lecture slides",
        "Organize receipts by month"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            instructionField

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Thinking…").font(ArchivistType.caption).foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(ArchivistType.body)
                    .foregroundStyle(.red)
            }

            if let proposal {
                proposalView(proposal)
            } else if !isLoading && errorMessage == nil && instruction.isEmpty {
                EmptyStateView(
                    systemImage: "wand.and.stars",
                    instruction: "Describe how you'd like your files organized.",
                    examples: examples,
                    onSelectExample: { example in
                        instruction = example
                        propose()
                    }
                )
            }
        }
        .padding(14)
    }

    private var instructionField: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("What should Archivist organize?", text: $instruction, onCommit: propose)
                .textFieldStyle(.plain)
                .font(ArchivistType.body)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func proposalView(_ proposal: ProposedAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create “\(proposal.destinationFolderName)” and move:")
                .font(ArchivistType.title)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(proposal.matchedNodes) { node in
                        HStack(spacing: 8) {
                            let glyph = FileTypeGlyph.symbol(for: node.filename)
                            Image(systemName: glyph.name)
                                .font(.system(size: 11))
                                .foregroundStyle(glyph.tint)
                            Text(node.filename)
                                .font(ArchivistType.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: 160)

            HStack(spacing: 8) {
                Button("Confirm and Move") { execute(proposal) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Cancel") { self.proposal = nil }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func propose() {
        errorMessage = nil
        proposal = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                proposal = try await interpreter.propose(for: instruction)
            } catch CommandInterpreterError.noMatches {
                errorMessage = "No indexed files matched that."
            } catch {
                errorMessage = "Couldn't interpret that: \(error)"
            }
        }
    }

    private func execute(_ action: ProposedAction) {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        do {
            _ = try interpreter.execute(action, into: downloads)
            proposal = nil
            instruction = ""
        } catch {
            errorMessage = "Move failed: \(error)"
        }
    }
}
