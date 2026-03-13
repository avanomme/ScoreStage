import SwiftUI
import UniformTypeIdentifiers

public struct FileImportModifier: ViewModifier {
    @Binding var isPresented: Bool
    let allowedTypes: [UTType]
    let allowMultiple: Bool
    let onImport: ([URL]) -> Void

    public func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: allowMultiple
        ) { result in
            switch result {
            case .success(let urls):
                onImport(urls)
            case .failure:
                break
            }
        }
    }
}

extension View {
    public func scoreFileImporter(
        isPresented: Binding<Bool>,
        allowMultiple: Bool = true,
        onImport: @escaping ([URL]) -> Void
    ) -> some View {
        modifier(FileImportModifier(
            isPresented: isPresented,
            allowedTypes: [.pdf, .xml, .midi, .png, .jpeg, .tiff],
            allowMultiple: allowMultiple,
            onImport: onImport
        ))
    }
}
