import Foundation

struct UPCItemDBResponse: Decodable {
    let items: [UPCItem]?
}

struct UPCItem: Decodable {
    /// Full product title, e.g. "Natrol Lutein 20 mg Softgels"
    let title: String?
    let brand: String?
    let description: String?
}
