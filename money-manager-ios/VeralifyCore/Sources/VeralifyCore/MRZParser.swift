import Foundation

/// The machine-readable zone of a passport or ID card, decoded.
///
/// Every field carries its own check digit in the MRZ, so unlike ordinary OCR
/// this can be *verified* rather than trusted: if the digit computed from the
/// characters matches the one printed beside them, the read was correct.
public struct MRZDocument: Hashable, Sendable {
    public enum Format: Hashable, Sendable {
        /// Passport: two lines of 44.
        case td3
        /// ID card, including the Italian Carta d'Identità Elettronica: three
        /// lines of 30.
        case td1
    }

    public let format: Format
    /// `P` for passport, `I`/`ID`/`AC` for identity cards.
    public let documentCode: String
    /// ISO 3166-1 alpha-3, as printed. `D` for Germany is the known exception.
    public let issuingCountry: String
    public let surname: String
    public let givenNames: String
    public let documentNumber: String
    public let nationality: String
    public let dateOfBirth: DateComponents
    public let expiryDate: DateComponents
    public let sex: String

    /// Which fields' check digits matched. A false here means OCR misread that
    /// field — the value is still returned, but the UI should ask.
    public let numberIsValid: Bool
    public let birthIsValid: Bool
    public let expiryIsValid: Bool

    public var fullName: String {
        [givenNames, surname].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// True when every field the format checksums came back clean.
    public var isFullyVerified: Bool { numberIsValid && birthIsValid && expiryIsValid }
}

/// Decodes ICAO 9303 machine-readable zones.
///
/// Pure string handling with no Vision dependency, so it can be tested against
/// the published ICAO specimen zones without a camera.
public enum MRZParser {

    /// Finds and decodes an MRZ anywhere in a page of recognised text.
    ///
    /// OCR returns the whole document, so the zone has to be located first: it
    /// is the run of lines made only of A–Z, 0–9 and the filler `<`, at one of
    /// two fixed widths.
    public static func parse(lines: [String]) -> MRZDocument? {
        let candidates = lines
            .map { normalise($0) }
            .filter { !$0.isEmpty }

        // TD3 first: a passport's two 44-character lines are unambiguous.
        for index in candidates.indices.dropLast() where candidates[index].count == 44 {
            if candidates[index + 1].count == 44,
               let document = parseTD3(candidates[index], candidates[index + 1]) {
                return document
            }
        }

        for index in candidates.indices where index + 2 < candidates.count {
            let three = [candidates[index], candidates[index + 1], candidates[index + 2]]
            if three.allSatisfy({ $0.count == 30 }),
               let document = parseTD1(three[0], three[1], three[2]) {
                return document
            }
        }

        return nil
    }

    /// Strips everything an MRZ cannot contain.
    ///
    /// Vision separates the zone's characters with spaces and reads the filler
    /// `<` as `«`, `K` or `c` depending on the print. Cleaning first is what
    /// makes the fixed-width offsets line up at all.
    private static func normalise(_ line: String) -> String {
        let upper = line.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "«", with: "<")
            .replacingOccurrences(of: "‹", with: "<")

        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")
        let cleaned = upper.filter { allowed.contains($0) }
        // Only lines that are essentially all MRZ alphabet survive; a line of
        // ordinary text loses too much to reach a valid width.
        return cleaned.count == upper.count ? cleaned : ""
    }

    // MARK: - Formats

    private static func parseTD3(_ first: String, _ second: String) -> MRZDocument? {
        guard first.count == 44, second.count == 44, first.hasPrefix("P") else { return nil }

        let a = Array(first)
        let b = Array(second)

        let names = splitNames(String(a[5..<44]))
        let number = String(b[0..<9])
        let birth = String(b[13..<19])
        let expiry = String(b[21..<27])

        guard let dob = dateComponents(birth, isBirth: true),
              let exp = dateComponents(expiry, isBirth: false)
        else { return nil }

        return MRZDocument(
            format: .td3,
            documentCode: String(a[0..<2]).replacingOccurrences(of: "<", with: ""),
            issuingCountry: String(a[2..<5]).replacingOccurrences(of: "<", with: ""),
            surname: names.surname,
            givenNames: names.given,
            documentNumber: number.replacingOccurrences(of: "<", with: ""),
            nationality: String(b[10..<13]).replacingOccurrences(of: "<", with: ""),
            dateOfBirth: dob,
            expiryDate: exp,
            sex: String(b[20]),
            numberIsValid: checkDigit(number) == b[9].wholeNumberValue,
            birthIsValid: checkDigit(birth) == b[19].wholeNumberValue,
            expiryIsValid: checkDigit(expiry) == b[27].wholeNumberValue
        )
    }

    private static func parseTD1(_ first: String, _ second: String, _ third: String) -> MRZDocument? {
        guard first.count == 30, second.count == 30, third.count == 30 else { return nil }

        let a = Array(first)
        let b = Array(second)

        let number = String(a[5..<14])
        let birth = String(b[0..<6])
        let expiry = String(b[8..<14])

        guard let dob = dateComponents(birth, isBirth: true),
              let exp = dateComponents(expiry, isBirth: false)
        else { return nil }

        let names = splitNames(third)

        return MRZDocument(
            format: .td1,
            documentCode: String(a[0..<2]).replacingOccurrences(of: "<", with: ""),
            issuingCountry: String(a[2..<5]).replacingOccurrences(of: "<", with: ""),
            surname: names.surname,
            givenNames: names.given,
            documentNumber: number.replacingOccurrences(of: "<", with: ""),
            nationality: String(b[15..<18]).replacingOccurrences(of: "<", with: ""),
            dateOfBirth: dob,
            expiryDate: exp,
            sex: String(b[7]),
            numberIsValid: checkDigit(number) == a[14].wholeNumberValue,
            birthIsValid: checkDigit(birth) == b[6].wholeNumberValue,
            expiryIsValid: checkDigit(expiry) == b[14].wholeNumberValue
        )
    }

    // MARK: - Pieces

    /// `SURNAME<<GIVEN<NAMES<<<<<` → the two halves, with fillers turned back
    /// into spaces.
    private static func splitNames(_ field: String) -> (surname: String, given: String) {
        let parts = field.components(separatedBy: "<<")
        let surname = parts.first.map(tidy) ?? ""
        let given = parts.count > 1 ? tidy(parts[1]) : ""
        return (surname, given)
    }

    private static func tidy(_ value: String) -> String {
        value.replacingOccurrences(of: "<", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// `YYMMDD` with no century, so one has to be inferred.
    ///
    /// A date of birth is always in the past; an expiry within a document's
    /// lifetime is always near. The ICAO-recommended split at 50 years gets
    /// both right for every document in circulation.
    private static func dateComponents(_ yymmdd: String, isBirth: Bool) -> DateComponents? {
        guard yymmdd.count == 6,
              let yy = Int(yymmdd.prefix(2)),
              let mm = Int(yymmdd.dropFirst(2).prefix(2)),
              let dd = Int(yymmdd.suffix(2)),
              (1...12).contains(mm), (1...31).contains(dd)
        else { return nil }

        let year: Int
        if isBirth {
            let currentYY = Calendar(identifier: .gregorian)
                .component(.year, from: Date()) % 100
            year = yy > currentYY ? 1900 + yy : 2000 + yy
        } else {
            year = yy < 50 ? 2000 + yy : 1900 + yy
        }

        return DateComponents(year: year, month: mm, day: dd)
    }

    /// The ICAO 9303 check digit: values weighted 7, 3, 1 in rotation, summed,
    /// modulo 10.
    ///
    /// This is what makes an MRZ read verifiable. Letters count from A = 10, and
    /// the filler `<` counts as zero.
    public static func checkDigit(_ field: String) -> Int {
        let weights = [7, 3, 1]
        var sum = 0

        for (index, character) in field.uppercased().enumerated() {
            let value: Int
            if let digit = character.wholeNumberValue, character.isNumber {
                value = digit
            } else if character == "<" {
                value = 0
            } else if let ascii = character.asciiValue, character.isLetter {
                value = Int(ascii - 65) + 10
            } else {
                value = 0
            }
            sum += value * weights[index % 3]
        }

        return sum % 10
    }
}
