#if os(iOS)
import Foundation
import UIKit

/// Perfil de produto gravado no `Info.plist` durante cada compilação dedicada.
///
/// O sistema operacional restringe instalação por família de aparelho, não por modelo comercial.
/// O perfil abaixo escolhe a composição visual calibrada para o tamanho solicitado, enquanto
/// `TARGETED_DEVICE_FAMILY` impede que o IPA do iPhone seja instalado no iPad e vice-versa.
enum VWARDeviceEdition: String, Sendable {
    case iPhone16ProMax = "iphone-16-pro-max"
    case iPadProM2 = "ipad-pro-m2-12-9"
    case adaptive = "adaptive"

    static var current: VWARDeviceEdition {
        if let rawValue = Bundle.main.object(forInfoDictionaryKey: "VWARDeviceEdition") as? String,
           let edition = VWARDeviceEdition(rawValue: rawValue) {
            return edition
        }
        return UIDevice.current.userInterfaceIdiom == .pad ? .iPadProM2 : .iPhone16ProMax
    }

    var usesCommandRail: Bool {
        switch self {
        case .iPadProM2: return true
        case .iPhone16ProMax: return false
        case .adaptive: return UIDevice.current.userInterfaceIdiom == .pad
        }
    }

    var shortLabel: String {
        switch self {
        case .iPhone16ProMax: return "EDIÇÃO IPHONE 16 PRO MAX"
        case .iPadProM2: return "EDIÇÃO IPAD PRO M2 12,9"
        case .adaptive: return "EDIÇÃO ADAPTATIVA"
        }
    }

    var interfaceDescription: String {
        switch self {
        case .iPhone16ProMax:
            return "Fluxo vertical, alcance com uma mão e inspeção tátil dos gráficos"
        case .iPadProM2:
            return "Central lateral persistente e painéis simultâneos para 12,9 polegadas"
        case .adaptive:
            return "Composição responsiva para iPhone e iPad"
        }
    }
}
#endif
