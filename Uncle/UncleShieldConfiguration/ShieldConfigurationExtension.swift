import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import UIKit

private let appGroupID = "group.uncle.app.v3"

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let subtitleText = "Open Uncle and tap Call Uncle to unlock."

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.5),
            icon: nil,
            title: ShieldConfiguration.Label(text: "Blocked by Uncle", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitleText, color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: nil
        )
    }
}
