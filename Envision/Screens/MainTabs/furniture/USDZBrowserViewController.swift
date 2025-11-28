//
//  USDZBrowserViewController.swift
//  Envision
//
//  Created by admin55 on 15/11/25.
//

import UIKit
import QuickLook
import UniformTypeIdentifiers

class USDZBrowserViewController: UIViewController,
                                 UIDocumentPickerDelegate,
                                 QLPreviewControllerDataSource,
                                 QLPreviewControllerDelegate {

    private var selectedUSDZURL: URL?

    override func viewDidLoad() {
//        super.viewDidLoad()
        view.backgroundColor = .systemPink
        browseUSDZ()
    }

    private func browseUSDZ() {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType(filenameExtension: "usdz")!]
        )
        documentPicker.delegate = self
        present(documentPicker, animated: true)
    }

    // MARK: - UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {

        guard let pickedURL = urls.first else { return }
        selectedUSDZURL = pickedURL

        // Dismiss picker BEFORE showing the preview
        controller.dismiss(animated: true) { [weak self] in
            self?.showPreview()
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }

    // MARK: - Preview
    private func showPreview() {
        guard let _ = selectedUSDZURL else { return }
        let preview = QLPreviewController()
        preview.dataSource = self
        preview.delegate = self      // ← IMPORTANT
        present(preview, animated: true)
    }

    // MARK: - QLPreviewControllerDataSource
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return selectedUSDZURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController,
                           previewItemAt index: Int) -> QLPreviewItem {
        return selectedUSDZURL! as QLPreviewItem
    }

    // MARK: - QLPreviewControllerDelegate
    func previewControllerWillDismiss(_ controller: QLPreviewController) {

        controller.dismiss(animated: true) { [weak self] in
            self?.dismiss(animated: true) {

                // Switch back to tab bar
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first,
                   let tabBar = window.rootViewController as? UITabBarController {
                    tabBar.selectedIndex = 1   // <-- index of ScanFurniture tab
                }
            }
        }
    }
}
