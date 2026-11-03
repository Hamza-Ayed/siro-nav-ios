#if canImport(UIKit)
import UIKit

/// Turn-by-Turn Navigation HUD View for iOS apps.
/// Displays top maneuver card, distance counter, speed badge, and bottom trip status bar.
public final class SiroNavView: UIView {
    private let topInstructionCard = UIView()
    private let instructionLabel = UILabel()
    private let distanceLabel = UILabel()
    private let speedBadge = UIView()
    private let speedLabel = UILabel()
    private let bottomStatusBar = UIView()
    private let remainingLabel = UILabel()
    private let exitButton = UIButton(type: .system)

    public var onExit: (() -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .clear

        // Top Banner Card
        topInstructionCard.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        topInstructionCard.layer.cornerRadius = 16
        topInstructionCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topInstructionCard)

        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.boldSystemFont(ofSize: 18)
        instructionLabel.numberOfLines = 2
        instructionLabel.textAlignment = .natural
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        topInstructionCard.addSubview(instructionLabel)

        distanceLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        distanceLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        topInstructionCard.addSubview(distanceLabel)

        // Speed Badge
        speedBadge.backgroundColor = UIColor.white
        speedBadge.layer.borderColor = UIColor.red.cgColor
        speedBadge.layer.borderWidth = 3
        speedBadge.layer.cornerRadius = 24
        speedBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedBadge)

        speedLabel.textColor = .black
        speedLabel.font = UIFont.boldSystemFont(ofSize: 16)
        speedLabel.textAlignment = .center
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedBadge.addSubview(speedLabel)

        // Bottom Status Bar
        bottomStatusBar.backgroundColor = UIColor(white: 0.12, alpha: 0.95)
        bottomStatusBar.layer.cornerRadius = 20
        bottomStatusBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomStatusBar)

        remainingLabel.textColor = .white
        remainingLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomStatusBar.addSubview(remainingLabel)

        exitButton.setTitle("خروج", for: .normal)
        exitButton.setTitleColor(.white, for: .normal)
        exitButton.backgroundColor = UIColor.systemRed
        exitButton.layer.cornerRadius = 12
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.addTarget(self, action: #selector(didTapExit), for: .touchUpInside)
        bottomStatusBar.addSubview(exitButton)

        NSLayoutConstraint.activate([
            topInstructionCard.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            topInstructionCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            topInstructionCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            instructionLabel.topAnchor.constraint(equalTo: topInstructionCard.topAnchor, constant: 14),
            instructionLabel.leadingAnchor.constraint(equalTo: topInstructionCard.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: topInstructionCard.trailingAnchor, constant: -16),

            distanceLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 6),
            distanceLabel.leadingAnchor.constraint(equalTo: topInstructionCard.leadingAnchor, constant: 16),
            distanceLabel.trailingAnchor.constraint(equalTo: topInstructionCard.trailingAnchor, constant: -16),
            distanceLabel.bottomAnchor.constraint(equalTo: topInstructionCard.bottomAnchor, constant: -14),

            speedBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            speedBadge.bottomAnchor.constraint(equalTo: bottomStatusBar.topAnchor, constant: -16),
            speedBadge.widthAnchor.constraint(equalToConstant: 48),
            speedBadge.heightAnchor.constraint(equalToConstant: 48),

            speedLabel.centerXAnchor.constraint(equalTo: speedBadge.centerXAnchor),
            speedLabel.centerYAnchor.constraint(equalTo: speedBadge.centerYAnchor),

            bottomStatusBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bottomStatusBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bottomStatusBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            bottomStatusBar.heightAnchor.constraint(equalToConstant: 64),

            remainingLabel.centerYAnchor.constraint(equalTo: bottomStatusBar.centerYAnchor),
            remainingLabel.leadingAnchor.constraint(equalTo: bottomStatusBar.leadingAnchor, constant: 16),

            exitButton.centerYAnchor.constraint(equalTo: bottomStatusBar.centerYAnchor),
            exitButton.trailingAnchor.constraint(equalTo: bottomStatusBar.trailingAnchor, constant: -16),
            exitButton.widthAnchor.constraint(equalToConstant: 72),
            exitButton.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    @objc private func didTapExit() {
        onExit?()
    }

    public func updateInstruction(_ instruction: NavInstructionEvent) {
        instructionLabel.text = instruction.instruction
        distanceLabel.text = formatDistance(instruction.distanceMeters)
    }

    public func updateProgress(_ progress: NavProgressEvent) {
        speedLabel.text = "\(Int(progress.currentSpeedKmh))"
        let km = String(format: "%.1f كم", progress.remainingDistanceMeters / 1000.0)
        let mins = "\(progress.remainingDurationSeconds / 60) دقيقة"
        remainingLabel.text = "\(km) • \(mins)"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "بعد %.1f كم", meters / 1000.0)
        } else {
            return "بعد \(Int(meters)) م"
        }
    }
}
#endif
