import SwiftUI
import CoreDomain
import DesignSystem

/// Sheet for exporting annotated PDFs with mode selection.
public struct ExportAnnotationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: PDFExportMode = .flattened
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportError: String?

    let onExport: (PDFExportMode) async -> Result<URL, Error>

    public init(onExport: @escaping (PDFExportMode) async -> Result<URL, Error>) {
        self.onExport = onExport
    }

    public var body: some View {
        VStack(spacing: ASSpacing.lg) {
            // Header
            HStack {
                Text("Export Annotated Score")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Mode picker
            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                ForEach(PDFExportMode.allCases) { mode in
                    exportModeRow(mode)
                }
            }

            // Status
            if let error = exportError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            if exportComplete {
                Label("Export complete", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ASColors.success)
            }

            // Export button
            Button {
                Task {
                    isExporting = true
                    exportError = nil
                    let result = await onExport(selectedMode)
                    isExporting = false
                    switch result {
                    case .success:
                        exportComplete = true
                    case .failure(let error):
                        exportError = error.localizedDescription
                    }
                }
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isExporting ? "Exporting..." : "Export")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ASSpacing.sm)
                .background(ASColors.accentFallback)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
        .padding(ASSpacing.lg)
        .frame(width: 300)
    }

    private func exportModeRow(_ mode: PDFExportMode) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: ASSpacing.md) {
                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selectedMode == mode ? AnyShapeStyle(ASColors.accentFallback) : AnyShapeStyle(.tertiary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(mode.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(ASSpacing.sm)
            .background(
                selectedMode == mode
                    ? ASColors.accentFallback.opacity(0.06)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
