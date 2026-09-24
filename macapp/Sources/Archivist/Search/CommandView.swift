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
    @State private var moveOutcome: MoveOutcome?

    /// What to tell the user after Confirm and Move (or Undo) actually finishes —
    /// clicking the button previously gave no feedback at all once the move
    /// completed, so there was no way to tell it had worked, what it was called,
    /// or where to find it without opening Finder yourself.
    private enum MoveOutcome {
        case moved(folderName: String, locationName: String, count: Int, records: [MoveRecord])
        case undone(folderName: String, locationName: String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            } else if let moveOutcome {
                moveOutcomeView(moveOutcome)
            } else if !isLoading && errorMessage == nil && instruction.isEmpty {
                // No instructional text here — the field's own placeholder already
                // shows an example of how to use this screen.
                EmptyStateView(systemImage: "wand.and.stars")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    /// Feedback after a move (or its undo) — folder name and location spelled out
    /// explicitly, plus a one-tap Undo while the outcome is still "moved".
    @ViewBuilder
    private func moveOutcomeView(_ outcome: MoveOutcome) -> some View {
        switch outcome {
        case .moved(let folderName, let locationName, let count, let records):
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Moved \(count) file\(count == 1 ? "" : "s") to “\(folderName)” in \(locationName).")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                }
                Button("Undo") {
                    interpreter.undo(records)
                    moveOutcome = .undone(folderName: folderName, locationName: locationName)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(ArchivistPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        case .undone(let folderName, let locationName):
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Undone — files moved back from “\(folderName)” in \(locationName).")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(ArchivistPalette.secondaryText)
            }
            .padding(12)
            .background(ArchivistPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var instructionField: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14))
                .foregroundStyle(ArchivistPalette.placeholderText)
            TextField("", text: $instruction,
                      prompt: Text("e.g. put my finance files in a folder").foregroundColor(ArchivistPalette.placeholderText))
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .onSubmit(propose)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(ArchivistPalette.searchFieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        .hoverHighlight(cornerRadius: 6)
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
        moveOutcome = nil
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
            let records = try interpreter.execute(action, into: downloads)
            proposal = nil
            instruction = ""
            moveOutcome = .moved(folderName: action.destinationFolderName, locationName: downloads.lastPathComponent,
                                  count: records.count, records: records)
        } catch {
            errorMessage = "Move failed: \(error)"
        }
    }
}
