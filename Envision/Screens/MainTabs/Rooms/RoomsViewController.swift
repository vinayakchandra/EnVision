import UIKit

final class RoomsViewController: UIViewController {

    // MARK: - UI Elements
    private var collectionView: UICollectionView!
    private let addRoomButton = PrimaryButton()
    private let emptyStateStack = UIStackView()
    
    // MARK: - Data
    private var rooms: [RoomModel] = [] {
        didSet { updateUI() }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupCollectionView()
        setupEmptyState()
        setupAddRoomButton()
        updateUI()
    }

    // MARK: - Setup UI
    private func setupView() {
        title = "My Rooms"
        view.backgroundColor = AppColors.background
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = .init(top: 16, left: 16, bottom: 16, right: 16)
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 12
        layout.itemSize = CGSize(width: (UIScreen.main.bounds.width - 48) / 2, height: 180)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(RoomCell.self, forCellWithReuseIdentifier: "RoomCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        let icon = UIImageView(image: UIImage(systemName: "cube.transparent"))
        icon.tintColor = AppColors.textSecondary
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "No rooms yet"
        title.font = AppFonts.semibold(18)
        title.textColor = AppColors.textPrimary

        let subtitle = UILabel()
        subtitle.text = "Add your first scanned room to get started."
        subtitle.font = AppFonts.regular(15)
        subtitle.textColor = AppColors.textSecondary

        let vstack = UIStackView(arrangedSubviews: [icon, title, subtitle])
        vstack.axis = .vertical
        vstack.alignment = .center
        vstack.spacing = 10

        emptyStateStack.axis = .vertical
        emptyStateStack.alignment = .center
        emptyStateStack.addArrangedSubview(vstack)
        emptyStateStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateStack)

        NSLayoutConstraint.activate([
            emptyStateStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupAddRoomButton() {
        addRoomButton.setTitle("+ Add Room", for: .normal)
        addRoomButton.addTarget(self, action: #selector(addRoomTapped), for: .touchUpInside)
        addRoomButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addRoomButton)

        NSLayoutConstraint.activate([
            addRoomButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addRoomButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            addRoomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addRoomButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    // MARK: - Actions
    @objc private func addRoomTapped() {
        let arIntroVC = ARIntroViewController()
        navigationController?.pushViewController(arIntroVC, animated: true)

        // Simulated new room for demo purposes
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
//            let newRoom = RoomModel(id: UUID().uuidString,
//                                    name: "Living Room",
//                                    preview: UIImage(systemName: "sofa.fill"))
//            self.rooms.append(newRoom)
//        }
    }

    // MARK: - Logic
    private func updateUI() {
        let isEmpty = rooms.isEmpty
        emptyStateStack.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        addRoomButton.isHidden = false
        collectionView.reloadData()
    }
}

extension RoomsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        rooms.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RoomCell", for: indexPath) as? RoomCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: rooms[indexPath.item])
//        cell.onOptionsTapped = { [weak self] in
//            self?.showRoomOptions(for: indexPath)
//        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedRoom = rooms[indexPath.item]
        let previewVC = UIViewController()
        previewVC.view.backgroundColor = .systemBackground
        previewVC.title = selectedRoom.name
        navigationController?.pushViewController(previewVC, animated: true)
    }

    private func showRoomOptions(for indexPath: IndexPath) {
        let alert = UIAlertController(title: "Manage Room", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { _ in
            // rename logic placeholder
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.rooms.remove(at: indexPath.item)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
