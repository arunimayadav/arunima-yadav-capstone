import SwiftUI
import AppKit

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
    @State private var isClearHovered = false
    @State private var loadingPhraseIndex = 0

    /// Rotated through while `isLoading` is true (see `loadingView`'s `.task`) —
    /// a single static "Thinking…" gave no sense that anything was actually
    /// happening during what can be a 30s-150s+ local-model call.
    private static let loadingPhrases = ["Reading your files…", "Matching your instruction…", "Almost done…"]

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

            // A single Group so only the branch that actually renders
            // (`loadingView` uniquely opts into `maxHeight: .infinity` +
            // center alignment internally) affects layout — proposal/outcome/
            // error/empty all stay naturally top-anchored right below the
            // search field, which is what "12px below search bar" requires.
            Group {
                if isLoading {
                    loadingView
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(ArchivistType.body)
                        .foregroundStyle(.red)
                } else if let proposal {
                    proposalView(proposal)
                } else if let moveOutcome {
                    moveOutcomeView(moveOutcome)
                } else if instruction.isEmpty {
                    // No instructional text here — the field's own placeholder
                    // already shows an example of how to use this screen.
                    EmptyStateView(systemImage: "wand.and.stars")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 12)
    }

    /// Centered in whatever space is left below the search field — both axes,
    /// not just pinned under the field the way the old inline "Thinking…" row
    /// was.
    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
            Text(Self.loadingPhrases[loadingPhraseIndex])
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(ArchivistPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task(id: isLoading) {
            guard isLoading else { return }
            var index = 0
            while !Task.isCancelled {
                loadingPhraseIndex = index % Self.loadingPhrases.count
                index += 1
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
        }
    }

    /// Feedback after a move (or its undo) — folder name and location spelled out
    /// explicitly, plus a one-tap Undo while the outcome is still "moved". Same
    /// width as the search field (348pt, via `.frame(maxWidth: .infinity)`) so it
    /// never just hugs its own (shorter) text width instead.
    @ViewBuilder
    private func moveOutcomeView(_ outcome: MoveOutcome) -> some View {
        switch outcome {
        case .moved(let folderName, let locationName, let count, let records):
            VStack(alignment: .center, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Moved \(count) file\(count == 1 ? "" : "s") to “\(folderName)” in \(locationName).")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ArchivistPalette.secondaryText)
                        .multilineTextAlignment(.center)
                }
                Button("Undo") {
                    interpreter.undo(records)
                    moveOutcome = .undone(folderName: folderName, locationName: locationName)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(ArchivistPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                // The folder itself, not one of its files — derived from any
                // record's destination path rather than stored separately,
                // since every record in this batch shares the same parent.
                if let first = records.first {
                    let folder = URL(fileURLWithPath: first.dstPath).deletingLastPathComponent()
                    NSWorkspace.shared.open(folder)
                }
            }

        case .undone(let folderName, let locationName):
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Undone — files moved back from “\(folderName)” in \(locationName).")
                    .font(.system(size: 12, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ArchivistPalette.secondaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(ArchivistPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    /// Matches Search's search field exactly (color, corner radius, border,
    /// shadow, icon size/opacity, text color, clear button) so the two screens
    /// read as one consistent design system rather than two different ones.
    private var instructionField: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(ArchivistPalette.secondaryText.opacity(0.88))
            TextField("", text: $instruction,
                      prompt: Text("e.g. put my finance files in a folder").foregroundColor(ArchivistPalette.placeholderText))
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(ArchivistPalette.primaryText)
                .onSubmit(propose)
            if !instruction.isEmpty {
                Button {
                    instruction = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(StatefulIconButtonStyle(
                    isHovered: isClearHovered,
                    hitSize: 28,
                    normalColor: ArchivistPalette.placeholderText,
                    hoverColor: ArchivistPalette.secondaryText,
                    pressedColor: Color(hex: "4A4A4D")
                ))
                .onHover { isClearHovered = $0 }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, instruction.isEmpty ? 10 : 8)
        .frame(height: 32)
        .background(ArchivistPalette.searchFieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    private func proposalView(_ proposal: ProposedAction) -> some View {
        // A row is ~37pt (32pt content + 4pt spacing + a hair of rounding) — so a
        // short match list only takes as much height as it actually needs
        // instead of a fixed-160 ScrollView always reserving that much room and
        // leaving a dead gap between the files and the buttons below.
        let rowHeight: CGFloat = 37
        let listHeight = min(CGFloat(proposal.matchedNodes.count) * rowHeight, 160)

        return VStack(alignment: .leading, spacing: 8) {
            Text("I'll create “\(proposal.destinationFolderName)” and move these files:")
                .font(ArchivistType.title)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(proposal.matchedNodes) { node in
                        ProposedFileRow(node: node) {
                            self.proposal?.matchedNodes.removeAll { $0.id == node.id }
                        }
                    }
                }
            }
            .frame(height: listHeight)

            HStack(spacing: 8) {
                Button("Confirm and Move") { execute(proposal) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(proposal.matchedNodes.isEmpty)
                Button("Cancel") { self.proposal = nil }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .center)
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

/// One matched file in the proposal list, with its own trailing remove button —
/// styled identically to the search field's clear button (same component, same
/// hit target/states) so a user can exclude a file before confirming the move.
private struct ProposedFileRow: View {
    let node: Node
    let onRemove: () -> Void

    @State private var isRemoveHovered = false

    var body: some View {
        HStack(spacing: 8) {
            let glyph = FileTypeGlyph.symbol(for: node.filename)
            Image(systemName: glyph.name)
                .font(.system(size: 11))
                .foregroundStyle(glyph.tint)
            Text(node.filename)
                .font(ArchivistType.body)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
            }
            .buttonStyle(StatefulIconButtonStyle(
                isHovered: isRemoveHovered,
                hitSize: 22,
                normalColor: ArchivistPalette.placeholderText,
                hoverColor: ArchivistPalette.secondaryText,
                pressedColor: Color(hex: "4A4A4D")
            ))
            .onHover { isRemoveHovered = $0 }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .hoverHighlight(cornerRadius: 6)
    }
}
