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

    /// Looks up drug info from a raw barcode string (UPC-A / EAN-13 / GS1 DataMatrix / GS1-128).
    /// Tries pharmaceutical databases first (openFDA → RxNorm), then falls back to the
    /// general UPCitemdb product database to cover dietary supplements and OTC vitamins.
    static func lookup(barcode: String) async throws -> DrugInfo {
        let ndc = try extractNDC(from: barcode)
        do {
            return try await fetchFromOpenFDA(ndc: ndc)
        } catch DrugLookupError.notFound {
            // Pharmaceutical lookup found nothing — try general product database.
            // This covers dietary supplements, vitamins, and OTC products not in FDA databases.
            return try await fetchFromUPCItemDB(barcode: barcode)
        }
    }

    // MARK: - NDC Extraction

    /// Converts a barcode string to a 10-digit raw NDC string.
    /// Supports GS1 Application Identifier strings (DataMatrix, GS1-128) and
    /// plain UPC-A / EAN-13 barcodes.
    static func extractNDC(from barcode: String) throws -> String {
        // 1. Try GS1 Application Identifier parsing (DataMatrix, GS1-128 barcodes)
        if let ndc = GS1Parser.extractNDC(from: barcode) { return ndc }

        // 2. Fallback: plain UPC-A / EAN-13
        var digits = barcode.filter(\.isNumber)
        if digits.count == 13 && digits.hasPrefix("0") {
            digits = String(digits.dropFirst())
        }
        guard digits.count == 12 else { throw DrugLookupError.invalidBarcode }
        let ndcDigits = String(digits.dropFirst().dropLast())
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

        // After both openFDA loops fail, try RxNorm
        if let info = try? await fetchFromRxNorm(ndc: ndc) {
            return info
        }
        throw DrugLookupError.notFound
    }

    // MARK: - RxNorm Fallback

    private static func fetchFromRxNorm(ndc: String) async throws -> DrugInfo {
        let candidates = formatNDCCandidates(from: ndc) + formatProductNDCCandidates(from: ndc)
        for formatted in candidates {
            let encoded = formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? formatted
            let urlString = "https://rxnav.nlm.nih.gov/REST/ndcProperties.json?ndc=\(encoded)"
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let decoded = try JSONDecoder().decode(RxNormNDCResponse.self, from: data)
                if let prop = decoded.ndcPropertyList?.ndcProperty?.first {
                    return parseRxNormInfo(from: prop)
                }
            } catch { continue }
        }
        throw DrugLookupError.notFound
    }

    private static func parseRxNormInfo(from prop: RxNormNDCResponse.NDCProperty) -> DrugInfo {
        // labeledName example: "Metformin Hydrochloride 500 MG Oral Tablet"
        let labeledName = prop.ndcItem?.labeledName ?? ""

        // Try to split into name and strength parts
        // Pattern: everything up to the first digit = name, digits + unit = dosage
        var name = labeledName
        var dosage = ""
        var unit = "mg"

        if let strengthRange = labeledName.range(of: #"\d"#, options: .regularExpression) {
            let namePart = String(labeledName[..<strengthRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let strengthPart = String(labeledName[strengthRange.lowerBound...])

            if !namePart.isEmpty { name = namePart.capitalized }

            // Parse "500 MG Oral Tablet" → dosage "500", unit "mg"
            let words = strengthPart.components(separatedBy: " ")
            if let first = words.first { dosage = first }
            if words.count > 1 {
                let rawUnit = words[1].lowercased()
                unit = mapUnit(rawUnit)
            }
        } else {
            name = labeledName.capitalized
        }

        return DrugInfo(name: name, dosage: dosage, unit: unit, dosageForm: "")
    }

    // MARK: - UPCitemdb Fallback (supplements, vitamins, OTC)

    /// Queries UPCitemdb for general consumer products not covered by pharmaceutical databases.
    /// Uses the free trial endpoint (no API key, 100 req/day).
    private static func fetchFromUPCItemDB(barcode: String) async throws -> DrugInfo {
        // Normalise to 12-digit UPC-A for UPCitemdb
        var upc = barcode.filter(\.isNumber)
        if upc.count == 13 && upc.hasPrefix("0") {
            upc = String(upc.dropFirst())
        }
        // For GS1 barcodes: extract GTIN-14 UPC-A equivalent (positions 1–12)
        if upc.count == 14 {
            upc = String(upc.dropFirst().dropLast())
        }

        let urlString = "https://api.upcitemdb.com/prod/trial/lookup?upc=\(upc)"
        guard let url = URL(string: urlString) else { throw DrugLookupError.notFound }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DrugLookupError.notFound
        }

        let decoded = try JSONDecoder().decode(UPCItemDBResponse.self, from: data)
        guard let item = decoded.items?.first else { throw DrugLookupError.notFound }

        return parseProductItem(item)
    }

    private static func parseProductItem(_ item: UPCItem) -> DrugInfo {
        let rawTitle = item.title ?? item.brand ?? ""
        guard !rawTitle.isEmpty else {
            return DrugInfo(name: "Unknown Product", dosage: "", unit: "mg", dosageForm: "")
        }

        // Find a dosage pattern like "20 mg", "500mg", "1000 IU", "400 mcg"
        let pattern = #"(\d+(?:\.\d+)?)\s*(mg|mcg|iu|µg|ug|g\b|ml)"#
        var name = rawTitle
        var dosage = ""
        var unit = "mg"

        if let matchRange = rawTitle.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            // Name = everything before the dosage number
            let namePart = String(rawTitle[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !namePart.isEmpty { name = namePart }

            // Split matched string into number + unit (handles "20mg" and "20 mg")
            let matchStr = String(rawTitle[matchRange])
            let numStr = matchStr.prefix(while: { $0.isNumber || $0 == "." })
            let unitStr = matchStr.drop(while: { $0.isNumber || $0 == "." })
                .trimmingCharacters(in: .whitespaces)
            dosage = String(numStr)
            unit = mapUnit(unitStr.lowercased())
        }

        return DrugInfo(name: name.capitalized, dosage: dosage, unit: unit, dosageForm: "")
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

// MARK: - GS1 Application Identifier Parser

private enum GS1Parser {
    /// Extracts a 10-digit raw NDC string from a GS1-encoded barcode string.
    /// Handles GS1 DataMatrix and GS1-128 barcode formats.
    ///
    /// GS1 barcode data example: "010303850218282617271231102L2J"
    ///   AI (01) → GTIN-14: "03038502182826"
    ///   AI (17) → expiry date: "271231"
    ///   AI (10) → lot: "2L2J"
    ///
    /// GTIN-14 structure for US pharma: "00" + "3" + NDC(10) + checkDigit
    ///   NDC = gtin14[3..<13] (positions 3–12 inclusive)
    static func extractNDC(from barcodeString: String) -> String? {
        guard let gtin14 = extractGTIN14(from: barcodeString) else { return nil }
        return ndcFromGTIN14(gtin14)
    }

    /// Finds the AI (01) GTIN-14 value in a GS1 barcode string.
    static func extractGTIN14(from barcodeString: String) -> String? {
        // Strip optional GS1 symbol identifier prefix: ]d2 (DataMatrix), ]C1 (GS1-128), ]Q3 (QR)
        var data = barcodeString
        if data.hasPrefix("]"), data.count > 3 {
            data = String(data.dropFirst(3))
        }

        // Replace FNC1 separator (ASCII 29, \u001d) with a marker for scanning
        // FNC1 delimiters appear between variable-length AI values
        let fnc1: Character = "\u{001d}"

        // Split on FNC1 to handle variable-length AI fields before AI (01)
        let segments = data.split(separator: fnc1, omittingEmptySubsequences: false).map(String.init)

        for segment in segments {
            // AI (01) is fixed-length: "01" + 14 digits = 16 chars minimum in this segment
            if segment.hasPrefix("01"), segment.count >= 16 {
                let afterAI = String(segment.dropFirst(2)) // drop "01"
                let gtin = String(afterAI.prefix(14))
                if gtin.count == 14, gtin.allSatisfy(\.isNumber) {
                    return gtin
                }
            }
        }
        return nil
    }

    /// Converts a 14-digit GTIN to a 10-digit raw NDC string.
    /// US pharma GTIN-14 layout: [0][0][3][NDC×10][checkDigit]
    static func ndcFromGTIN14(_ gtin14: String) -> String? {
        guard gtin14.count == 14, gtin14.allSatisfy(\.isNumber) else { return nil }
        // Drop indicator digit + EAN prefix + pharma prefix (first 3) and check digit (last 1)
        let start = gtin14.index(gtin14.startIndex, offsetBy: 3)
        let end = gtin14.index(gtin14.endIndex, offsetBy: -1)
        guard start < end else { return nil }
        let ndc = String(gtin14[start..<end])
        guard ndc.count == 10 else { return nil }
        return ndc
    }
}
