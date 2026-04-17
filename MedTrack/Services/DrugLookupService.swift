import Foundation

struct DrugInfo {
    let name: String
    let dosage: String
    let unit: String
    let dosageForm: String
}

enum DrugLookupError: LocalizedError {
    case notFound
    case networkError(Error)
    case invalidBarcode

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Drug not found. Please fill in the details manually."
        case .networkError:
            return "Could not reach the drug database. Check your connection."
        case .invalidBarcode:
            return "Barcode format not recognised. Please fill in manually."
        }
    }
}

enum DrugLookupService {

    // MARK: - Public

    /// Looks up drug info from a raw barcode string (UPC-A / EAN-13).
    static func lookup(barcode: String) async throws -> DrugInfo {
        let ndc = try extractNDC(from: barcode)
        return try await fetchFromOpenFDA(ndc: ndc)
    }

    // MARK: - NDC Extraction

    /// Converts a 12-digit UPC-A (or 13-digit EAN-13) to candidate NDC strings.
    /// UPC-A: prepend "0" → EAN-13 on iOS. Strip leading "0" or "3", strip check digit.
    static func extractNDC(from barcode: String) throws -> String {
        var digits = barcode.filter(\.isNumber)

        // EAN-13 from iOS AVFoundation adds a leading "0" to UPC-A.
        // Pharmaceutical UPC-A starts with "3" (or "03" in EAN-13).
        if digits.count == 13 && digits.hasPrefix("0") {
            digits = String(digits.dropFirst()) // strip the leading 0 → 12-digit UPC-A
        }

        guard digits.count == 12 else { throw DrugLookupError.invalidBarcode }

        // 12-digit UPC-A for drugs: first digit is "3", last digit is check digit.
        // Middle 10 digits are the NDC (without formatting dashes).
        let ndcDigits = String(digits.dropFirst().dropLast()) // 10 raw digits
        guard ndcDigits.count == 10 else { throw DrugLookupError.invalidBarcode }

        return ndcDigits
    }

    // MARK: - API

    private static func fetchFromOpenFDA(ndc: String) async throws -> DrugInfo {
        // openFDA stores NDC in packaging.package_ndc with dashes, but we can
        // search by the raw 10 digits using a wildcard approach across both fields.
        let candidates = formatNDCCandidates(from: ndc)

        for formatted in candidates {
            let encoded = formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? formatted
            let urlString = "https://api.fda.gov/drug/ndc.json?search=packaging.package_ndc:\"\(encoded)\"&limit=1"

            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    continue
                }

                let decoded = try JSONDecoder().decode(OpenFDAResponse.self, from: data)
                if let result = decoded.results?.first {
                    return parseDrugInfo(from: result)
                }
            } catch {
                // Try next candidate
                continue
            }
        }

        // Fallback: search by product_ndc
        for formatted in formatProductNDCCandidates(from: ndc) {
            let encoded = formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? formatted
            let urlString = "https://api.fda.gov/drug/ndc.json?search=product_ndc:\"\(encoded)\"&limit=1"

            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let decoded = try JSONDecoder().decode(OpenFDAResponse.self, from: data)
                if let result = decoded.results?.first {
                    return parseDrugInfo(from: result)
                }
            } catch { continue }
        }

        throw DrugLookupError.notFound
    }

    // MARK: - NDC Formatting

    /// Generate packaging NDC candidates (11-digit with dashes) from 10 raw digits.
    /// openFDA packaging.package_ndc is 11 digits formatted as XXXXX-XXXX-XX.
    private static func formatNDCCandidates(from digits: String) -> [String] {
        guard digits.count == 10 else { return [] }
        // Common packaging NDC formats: 5-4-2, 5-3-2+pad, 4-4-2+pad, 4-3-2+pad
        // All map to 11-digit by prefixing zeros in specific segments.
        return [
            // 5-4-2 → the most common OTC format
            "\(digits.prefix(5))-\(digits.dropFirst(5).prefix(4))-\(digits.suffix(2))",
            // 4-4-2 → pad labeler to 5
            "0\(digits.prefix(4))-\(digits.dropFirst(4).prefix(4))-\(digits.suffix(2))",
            // 5-3-2 → pad product to 4
            "\(digits.prefix(5))-0\(digits.dropFirst(5).prefix(3))-\(digits.suffix(2))",
        ]
    }

    /// Generate product NDC candidates (without packaging segment) for the product_ndc field.
    private static func formatProductNDCCandidates(from digits: String) -> [String] {
        guard digits.count == 10 else { return [] }
        let d = digits
        return [
            "\(d.prefix(5))-\(d.dropFirst(5).prefix(4))",   // 5-4
            "0\(d.prefix(4))-\(d.dropFirst(4).prefix(4))",  // 4-4 padded
            "\(d.prefix(5))-0\(d.dropFirst(5).prefix(3))",  // 5-3 padded
        ]
    }

    // MARK: - Parsing

    private static func parseDrugInfo(from result: DrugResult) -> DrugInfo {
        let name = [result.brand_name, result.generic_name]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty })
            .map { $0.capitalized }
            ?? "Unknown Drug"

        var dosage = ""
        var unit = "mg"

        if let strength = result.active_ingredients?.first?.strength {
            let parsed = parseStrength(strength)
            dosage = parsed.dosage
            unit = parsed.unit
        }

        let dosageForm = result.dosage_form?.capitalized ?? ""

        return DrugInfo(name: name, dosage: dosage, unit: unit, dosageForm: dosageForm)
    }

    /// Parses "500 mg/1", "10 mg/mL", "5 %/1" → (dosage: "500", unit: "mg")
    private static func parseStrength(_ strength: String) -> (dosage: String, unit: String) {
        // Split on "/" first to discard the denominator ("500 mg/1" → "500 mg")
        let numerator = strength.split(separator: "/").first.map(String.init) ?? strength
        let parts = numerator.trimmingCharacters(in: .whitespaces).split(separator: " ")

        let dosage = parts.first.map(String.init) ?? ""
        let rawUnit = parts.dropFirst().joined(separator: " ").lowercased()

        let unit = mapUnit(rawUnit)
        return (dosage: dosage, unit: unit)
    }

    private static func mapUnit(_ raw: String) -> String {
        let u = raw.trimmingCharacters(in: .whitespaces).lowercased()
        switch u {
        case "mg":               return "mg"
        case "ml", "ml/ml":     return "ml"
        case "tablet", "tablets": return "tablet"
        case "capsule", "capsules": return "capsule"
        case "drop", "drops":   return "drop"
        case "patch":           return "patch"
        default:                return "mg"
        }
    }
}
