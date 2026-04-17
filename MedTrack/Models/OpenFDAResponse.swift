import Foundation

struct OpenFDAResponse: Decodable {
    let results: [DrugResult]?
    let error: OpenFDAError?
}

struct OpenFDAError: Decodable {
    let code: String?
    let message: String?
}

struct DrugResult: Decodable {
    let brand_name: String?
    let generic_name: String?
    let dosage_form: String?
    let route: [String]?
    let active_ingredients: [ActiveIngredient]?
    let packaging: [DrugPackaging]?
}

struct ActiveIngredient: Decodable {
    let name: String?
    /// e.g. "500 mg/1", "10 mg/mL", "5 %/1"
    let strength: String?
}

struct DrugPackaging: Decodable {
    let package_ndc: String?
    let description: String?
}
