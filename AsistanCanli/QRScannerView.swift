// Asistan Canlı — Mac'teki eşleştirme QR kodunu kamerayla okur (VisionKit, iOS 16+)

import SwiftUI
import VisionKit

struct QRScannerView: UIViewControllerRepresentable {
    /// Okunan metni döndürür; true dönerse tarama biter
    let onCode: (String) -> Bool

    @MainActor static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced,
                                                recognizesMultipleItems: false,
                                                isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Bool
        private var done = false
        init(onCode: @escaping (String) -> Bool) { self.onCode = onCode }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for case let .barcode(code) in items {
                if let text = code.payloadStringValue, onCode(text) { done = true; scanner.stopScanning(); return }
            }
        }
    }
}
