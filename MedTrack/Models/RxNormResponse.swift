import Foundation

struct RxNormNDCResponse: Decodable {
    let ndcPropertyList: NDCPropertyList?

    struct NDCPropertyList: Decodable {
        let ndcProperty: [NDCProperty]?
    }

    struct NDCProperty: Decodable {
        let rxcui: String?
        let ndc10: String?
        let ndcItem: NDCItem?
    }

    struct NDCItem: Decodable {
        /// e.g. "Metformin Hydrochloride 500 MG Oral Tablet"
        let labeledName: String?
        let dosageFormName: String?
        let strengthDesc: String?
    }
}
