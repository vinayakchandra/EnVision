//
// Created by Vinayak Suryavanshi on 20/12/25.
//

import QuickLook
import UIKit

// MARK: - UIDocumentPickerDelegate
extension MyRoomsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        importRoomFiles(urls)
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension MyRoomsViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        section == 0 ? allChipsData.count : displayFiles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChipCell.reuseID, for: indexPath) as! ChipCell
            let chip = allChipsData[indexPath.item]

            // Determine if chip is selected
            let isSelected: Bool
            if chip.category == nil && chip.roomType == nil {
                // "All" chip
                isSelected = selectedCategory == nil && selectedRoomType == nil
            } else if let category = chip.category {
                isSelected = category == selectedCategory
            } else if let roomType = chip.roomType {
                isSelected = roomType == selectedRoomType
            } else {
                isSelected = false
            }

            cell.configure(title: chip.title, icon: chip.icon, category: chip.category, roomType: chip.roomType, isSelected: isSelected)
            cell.button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            return cell
        } else {
            // Room cell - UPDATED VERSION WITH BADGES
            let url = displayFiles[indexPath.item]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoomCell.reuseID, for: indexPath) as! RoomCell
            let metadata = loadMetadata(for: url)

            // Configure with metadata for badge display
            cell.configure(
                fileName: url.lastPathComponent,
                size: fileSizeString(for: url),
                thumbnail: nil,
                category: metadata?.category,
                roomType: metadata?.roomType
            )

            generateThumbnail(for: url) { [weak self] image in
                guard let self = self,
                    let cell = self.collectionView.cellForItem(at: indexPath) as? RoomCell
                else { return }
                let metadata = self.loadMetadata(for: url)

                // Update with thumbnail and metadata
                cell.configure(
                    fileName: url.lastPathComponent,
                    size: self.fileSizeString(for: url),
                    thumbnail: image,
                    category: metadata?.category,
                    roomType: metadata?.roomType
                )
            }

            return cell
        }
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 1, !collectionView.allowsMultipleSelection else { return }

        let url = displayFiles[indexPath.item]
        navigationController?.pushViewController(RoomViewerViewController(roomURL: url), animated: true)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard indexPath.section == 1 else { return nil }

        let url = displayFiles[indexPath.item]
        let currentMetadata = loadMetadata(for: url)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "View in AR", image: UIImage(systemName: "arkit")) { _ in
                    self?.quickLook(url: url)
                },
                UIAction(title: "Edit Category", image: UIImage(systemName: "tag")) { _ in
                    self?.showEditCategoryDialog(for: url, currentMetadata: currentMetadata)
                },
                UIAction(title: "Edit Room Type", image: UIImage(systemName: "cube")) { _ in
                    self?.showEditRoomTypeDialog(for: url, currentMetadata: currentMetadata)
                },
                UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                    self?.showRenameDialog(for: url)
                },
                UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    self?.shareRoom(url: url)
                },
                UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    self?.confirmDelete(url: url)
                },
            ])
        }
    }


    // MARK: - Edit Category/Type Methods

    private func showEditCategoryDialog(for url: URL, currentMetadata: RoomMetadata?) {
        let alert = UIAlertController(
            title: "Change Category",
            message: "Select a new category for this room",
            preferredStyle: .actionSheet
        )

        for category in RoomCategory.allCases {
            let action = UIAlertAction(
                title: "  \(category.displayName)",
                style: .default
            ) { [weak self] _ in
                self?.updateRoomCategory(url: url, newCategory: category, currentMetadata: currentMetadata)
            }

            // Add icon with color
            if let image = UIImage(systemName: category.sfSymbol)?
                .withTintColor(category.color, renderingMode: .alwaysOriginal)
            {
                action.setValue(image, forKey: "image")
            }

            // Mark current category
            if category == currentMetadata?.category {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showEditRoomTypeDialog(for url: URL, currentMetadata: RoomMetadata?) {
        let alert = UIAlertController(
            title: "Change Room Type",
            message: "Select the type of 3D model",
            preferredStyle: .actionSheet
        )

        for roomType in RoomType.allCases {
            let action = UIAlertAction(
                title: "  \(roomType.displayName) - \(roomType.description)",
                style: .default
            ) { [weak self] _ in
                self?.updateRoomType(url: url, newRoomType: roomType, currentMetadata: currentMetadata)
            }

            // Add icon with color
            if let image = UIImage(systemName: roomType.sfSymbol)?
                .withTintColor(roomType.color, renderingMode: .alwaysOriginal)
            {
                action.setValue(image, forKey: "image")
            }

            // Mark current type
            if roomType == currentMetadata?.roomType {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func updateRoomCategory(url: URL, newCategory: RoomCategory, currentMetadata: RoomMetadata?) {
        let filename = url.lastPathComponent

        // If no metadata exists, create new one with defaults
        guard var metadata = currentMetadata else {
            let newMetadata = RoomMetadata(
                category: newCategory,
                roomType: .parametric,  // Default
                createdAt: Date(),
                dimensions: nil,
                tags: [],
                notes: nil
            )
            MetadataManager.shared.updateMetadata(for: filename, metadata: newMetadata)

            // Reload to update chips and UI
            collectionView.reloadData()
            showToast(message: "Category updated to \(newCategory.displayName)")
            return
        }

        // Update existing metadata
        metadata.category = newCategory
        MetadataManager.shared.updateMetadata(for: filename, metadata: metadata)

        // Reload to update chips and UI
        collectionView.reloadData()
        showToast(message: "Category updated to \(newCategory.displayName)")
    }

    private func updateRoomType(url: URL, newRoomType: RoomType, currentMetadata: RoomMetadata?) {
        let filename = url.lastPathComponent

        // If no metadata exists, create new one with defaults
        guard var metadata = currentMetadata else {
            let newMetadata = RoomMetadata(
                category: .livingRoom,  // Default
                roomType: newRoomType,
                createdAt: Date(),
                dimensions: nil,
                tags: [],
                notes: nil
            )
            MetadataManager.shared.updateMetadata(for: filename, metadata: newMetadata)

            // Reload to update chips and UI
            collectionView.reloadData()
            showToast(message: "Room type updated to \(newRoomType.displayName)")
            return
        }

        // Update existing metadata
        metadata.roomType = newRoomType
        MetadataManager.shared.updateMetadata(for: filename, metadata: metadata)

        // Reload to update chips and UI
        collectionView.reloadData()
        showToast(message: "Room type updated to \(newRoomType.displayName)")
    }


    private func showRenameDialog(for url: URL) {
        let alert = UIAlertController(title: "Rename Room", message: "Enter a new name for this room", preferredStyle: .alert)
        alert.addTextField {
            $0.text = url.deletingPathExtension().lastPathComponent
            $0.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Rename", style: .default) { [weak self, weak alert] _ in
                guard let newName = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                    !newName.isEmpty
                else { return }
                self?.performRename(url: url, newName: newName)
            })
        present(alert, animated: true)
    }

    private func performRename(url: URL, newName: String) {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let newURL = dir.appendingPathComponent("\(newName).usdz")
        let oldFilename = url.lastPathComponent
        let newFilename = newURL.lastPathComponent

        do {
            try fm.moveItem(at: url, to: newURL)

            // Update metadata with new filename
            MetadataManager.shared.renameMetadata(from: oldFilename, to: newFilename)

            loadRoomFiles()
            showToast(message: "Renamed to \(newName)")
        } catch {
            showAlert(title: "Rename Failed", message: error.localizedDescription)
        }
    }

    private func shareRoom(url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = vc.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(vc, animated: true)
    }

    private func confirmDelete(url: URL) {
        showConfirmation(title: "Delete Room?", message: "This action cannot be undone.") { [weak self] in
            let filename = url.lastPathComponent

            SaveManager.shared.deleteModel(at: url) { [weak self] success in
                if success {
                    // Delete metadata
                    MetadataManager.shared.deleteMetadata(for: filename)

                    self?.loadRoomFiles()
                    self?.showToast(message: "Room deleted")
                } else {
                    self?.showAlert(title: "Delete Failed", message: "Could not delete the room model.")
                }
            }
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else { return nil }

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }
            let url = self.displayFiles[indexPath.item]
            try? FileManager.default.removeItem(at: url)
            self.roomFiles.removeAll { $0 == url }
            self.thumbnailCache.removeObject(forKey: url as NSURL)
            collectionView.deleteItems(at: [indexPath])
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [delete])
    }
}

// MARK: - UISearchResultsUpdating
extension MyRoomsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        collectionView.reloadData()
    }
}

// MARK: - QLPreviewControllerDataSource
extension MyRoomsViewController: QLPreviewControllerDataSource {
    func quickLook(url: URL) {
        previewURL = url
        let preview = QLPreviewController()
        preview.dataSource = self
        present(preview, animated: true)
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewURL as NSURL
    }
}
