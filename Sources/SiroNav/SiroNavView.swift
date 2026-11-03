#if canImport(UIKit)
import UIKit

/// Turn-by-Turn Navigation HUD View for iOS apps.
/// Matches Siro Limestone design:
/// - 3D Chase Camera synced with GPS Heading
/// - Directional Chevron marker with white disc casing
/// - Elevated speedometer badge
/// - Bilingual metrics (Arabic / English)
/// - Developer-controlled optional Fare & Distance panel with custom currency
public final class SiroNavView: UIView {
    public var locale: String = "ar" // "ar" or "en"
    public var showFareMetrics: BooleanLiteralType = true
    public var onExit: (() -> Void)?

    private let topInstructionCard = UIView()
    private let iconBox = UIView()
    private let maneuverLabel = UILabel()
    private let instructionLabel = UILabel()
    private let distanceLabel = UILabel()
    private let streetLabel = UILabel()

    private let speedBadge = UIView()
    private let speedLabel = UILabel()
    private let speedUnitLabel = UILabel()

    private let bottomCard = UIView()
    private let exitButton = UIButton(type: .system)
    private let etaLabel = UILabel()
    private let etaClockLabel = UILabel()
    private let remainingLabel = UILabel()
    private let fareContainer = UIView()
    private let fareMetricsLabel = UILabel()

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

        // 1. Top Instruction Card
        topInstructionCard.backgroundColor = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 0.96) // Slate 900
        topInstructionCard.layer.cornerRadius = 20
        topInstructionCard.layer.borderWidth = 1
        topInstructionCard.layer.borderColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 0.4).cgColor
        topInstructionCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topInstructionCard)

        iconBox.backgroundColor = UIColor(red: 2/255, green: 132/255, blue: 199/255, alpha: 1.0) // Sky 600
        iconBox.layer.cornerRadius = 14
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        topInstructionCard.addSubview(iconBox)

        maneuverLabel.text = "↱"
        maneuverLabel.textColor = .white
        maneuverLabel.font = UIFont.boldSystemFont(ofSize: 24)
        maneuverLabel.textAlignment = .center
        maneuverLabel.translatesAutoresizingMaskIntoConstraints = false
        iconBox.addSubview(maneuverLabel)

        distanceLabel.textColor = UIColor(red: 56/255, green: 189/255, blue: 248/255, alpha: 1.0)
        distanceLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        topInstructionCard.addSubview(distanceLabel)

        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        instructionLabel.numberOfLines = 2
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        topInstructionCard.addSubview(instructionLabel)

        streetLabel.textColor = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)
        streetLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        streetLabel.translatesAutoresizingMaskIntoConstraints = false
        topInstructionCard.addSubview(streetLabel)

        // 2. Elevated Speed Badge (Positioned high above bottom card)
        speedBadge.backgroundColor = .white
        speedBadge.layer.borderColor = UIColor.systemRed.cgColor
        speedBadge.layer.borderWidth = 3.5
        speedBadge.layer.cornerRadius = 28
        speedBadge.layer.shadowColor = UIColor.black.cgColor
        speedBadge.layer.shadowOpacity = 0.35
        speedBadge.layer.shadowOffset = CGSize(width: 0, height: 4)
        speedBadge.layer.shadowRadius = 8
        speedBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedBadge)

        speedLabel.text = "0"
        speedLabel.textColor = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
        speedLabel.font = UIFont.boldSystemFont(ofSize: 20)
        speedLabel.textAlignment = .center
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedBadge.addSubview(speedLabel)

        speedUnitLabel.text = locale == "ar" ? "كم/س" : "km/h"
        speedUnitLabel.textColor = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
        speedUnitLabel.font = UIFont.boldSystemFont(ofSize: 9)
        speedUnitLabel.textAlignment = .center
        speedUnitLabel.translatesAutoresizingMaskIntoConstraints = false
        speedBadge.addSubview(speedUnitLabel)

        // 3. Bottom Status Card
        bottomCard.backgroundColor = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 0.98)
        bottomCard.layer.cornerRadius = 24
        bottomCard.layer.borderWidth = 1
        bottomCard.layer.borderColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 0.4).cgColor
        bottomCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomCard)

        exitButton.setTitle("✕", for: .normal)
        exitButton.setTitleColor(UIColor.systemRed, for: .normal)
        exitButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        exitButton.backgroundColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 1.0)
        exitButton.layer.cornerRadius = 22
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.addTarget(self, action: #selector(didTapExit), for: .touchUpInside)
        bottomCard.addSubview(exitButton)

        etaLabel.textColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)
        etaLabel.font = UIFont.systemFont(ofSize: 21, weight: .bold)
        etaLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomCard.addSubview(etaLabel)

        etaClockLabel.textColor = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)
        etaClockLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        etaClockLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomCard.addSubview(etaClockLabel)

        remainingLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        remainingLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomCard.addSubview(remainingLabel)

        // Sub-panel for developer fare metrics
        fareContainer.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.5)
        fareContainer.layer.cornerRadius = 12
        fareContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomCard.addSubview(fareContainer)

        fareMetricsLabel.textColor = UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1.0) // Amber gold
        fareMetricsLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        fareMetricsLabel.adjustsFontSizeToFitWidth = true
        fareMetricsLabel.minimumScaleFactor = 0.75
        fareMetricsLabel.textAlignment = .center
        fareMetricsLabel.translatesAutoresizingMaskIntoConstraints = false
        fareContainer.addSubview(fareMetricsLabel)

        NSLayoutConstraint.activate([
            topInstructionCard.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            topInstructionCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            topInstructionCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            iconBox.leadingAnchor.constraint(equalTo: topInstructionCard.leadingAnchor, constant: 14),
            iconBox.centerYAnchor.constraint(equalTo: topInstructionCard.centerYAnchor),
            iconBox.widthAnchor.constraint(equalToConstant: 46),
            iconBox.heightAnchor.constraint(equalToConstant: 46),

            maneuverLabel.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            maneuverLabel.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            distanceLabel.topAnchor.constraint(equalTo: topInstructionCard.topAnchor, constant: 12),
            distanceLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 12),
            distanceLabel.trailingAnchor.constraint(equalTo: topInstructionCard.trailingAnchor, constant: -14),

            instructionLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 2),
            instructionLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 12),
            instructionLabel.trailingAnchor.constraint(equalTo: topInstructionCard.trailingAnchor, constant: -14),

            streetLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 2),
            streetLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 12),
            streetLabel.trailingAnchor.constraint(equalTo: topInstructionCard.trailingAnchor, constant: -14),
            streetLabel.bottomAnchor.constraint(equalTo: topInstructionCard.bottomAnchor, constant: -12),

            // Speedometer elevated 148pt above bottom card
            speedBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            speedBadge.bottomAnchor.constraint(equalTo: bottomCard.topAnchor, constant: -24),
            speedBadge.widthAnchor.constraint(equalToConstant: 56),
            speedBadge.heightAnchor.constraint(equalToConstant: 56),

            speedLabel.centerXAnchor.constraint(equalTo: speedBadge.centerXAnchor),
            speedLabel.centerYAnchor.constraint(equalTo: speedBadge.centerYAnchor, constant: -4),
            speedUnitLabel.centerXAnchor.constraint(equalTo: speedBadge.centerXAnchor),
            speedUnitLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: -2),

            bottomCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            bottomCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            bottomCard.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -14),

            exitButton.leadingAnchor.constraint(equalTo: bottomCard.leadingAnchor, constant: 16),
            exitButton.topAnchor.constraint(equalTo: bottomCard.topAnchor, constant: 16),
            exitButton.widthAnchor.constraint(equalToConstant: 44),
            exitButton.heightAnchor.constraint(equalToConstant: 44),

            etaLabel.topAnchor.constraint(equalTo: bottomCard.topAnchor, constant: 14),
            etaLabel.leadingAnchor.constraint(equalTo: exitButton.trailingAnchor, constant: 14),

            etaClockLabel.centerYAnchor.constraint(equalTo: etaLabel.centerYAnchor),
            etaClockLabel.leadingAnchor.constraint(equalTo: etaLabel.trailingAnchor, constant: 8),

            remainingLabel.topAnchor.constraint(equalTo: etaLabel.bottomAnchor, constant: 2),
            remainingLabel.leadingAnchor.constraint(equalTo: exitButton.trailingAnchor, constant: 14),

            fareContainer.topAnchor.constraint(equalTo: remainingLabel.bottomAnchor, constant: 12),
            fareContainer.leadingAnchor.constraint(equalTo: bottomCard.leadingAnchor, constant: 14),
            fareContainer.trailingAnchor.constraint(equalTo: bottomCard.trailingAnchor, constant: -14),
            fareContainer.bottomAnchor.constraint(equalTo: bottomCard.bottomAnchor, constant: -14),

            fareMetricsLabel.topAnchor.constraint(equalTo: fareContainer.topAnchor, constant: 6),
            fareMetricsLabel.bottomAnchor.constraint(equalTo: fareContainer.bottomAnchor, constant: -6),
            fareMetricsLabel.leadingAnchor.constraint(equalTo: fareContainer.leadingAnchor, constant: 10),
            fareMetricsLabel.trailingAnchor.constraint(equalTo: fareContainer.trailingAnchor, constant: -10)
        ])
    }

    @objc private func didTapExit() {
        onExit?()
    }

    public func updateInstruction(_ instruction: NavInstructionEvent) {
        instructionLabel.text = instruction.instruction
        distanceLabel.text = formatDistance(instruction.distanceMeters)
        if !instruction.streetName.isEmpty {
            streetLabel.isHidden = false
            streetLabel.text = instruction.streetName
        } else {
            streetLabel.isHidden = true
        }
        maneuverLabel.text = instruction.maneuverType == 1 ? "↱" : (instruction.maneuverType == -1 ? "↰" : "↑")
    }

    public func updateProgress(_ progress: NavProgressEvent, totals: NavTripTotals? = nil, startTime: Date? = nil) {
        speedLabel.text = "\(Int(progress.currentSpeedKmh))"
        let mins = max(1, progress.remainingDurationSeconds / 60)
        etaLabel.text = locale == "ar" ? "\(mins) دقيقة" : "\(mins) min"

        let arrivalTime = Date().addingTimeInterval(TimeInterval(progress.remainingDurationSeconds))
        let formatter = DateFormatter()
        formatter.dateFormat = locale == "ar" ? "h:mm a" : "h:mm a"
        etaClockLabel.text = "(\(formatter.string(from: arrivalTime)))"

        let km = progress.remainingDistanceMeters / 1000.0
        remainingLabel.text = locale == "ar" ? String(format: "%.1f كم متبقية", km) : String(format: "%.1f km remaining", km)

        if showFareMetrics, let t = totals {
            fareContainer.isHidden = false
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "h:mm a"
            let startStr = startFormatter.string(from: startTime ?? Date())
            if locale == "ar" {
                fareMetricsLabel.text = "انطلاق: \(startStr)  •  المسافة: \(String(format: "%.2f", t.distanceKm)) كم  •  الأجرة: \(t.fareLabel)"
            } else {
                fareMetricsLabel.text = "Start: \(startStr)  •  Distance: \(String(format: "%.2f", t.distanceKm)) km  •  Fare: \(t.fareLabel)"
            }
        } else {
            fareContainer.isHidden = true
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if locale == "ar" {
            return meters >= 1000 ? String(format: "بعد %.1f كم", meters / 1000.0) : "بعد \(Int(meters)) م"
        } else {
            return meters >= 1000 ? String(format: "In %.1f km", meters / 1000.0) : "In \(Int(meters)) m"
        }
    }
}
#endif
