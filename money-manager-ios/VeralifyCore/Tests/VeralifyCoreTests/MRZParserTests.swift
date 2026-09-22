import Testing
import Foundation
@testable import VeralifyCore

/// Pinned to the specimen zones published in ICAO Doc 9303, which exist so
/// implementations can be checked against them. No real document appears here.
@Suite("MRZ parsing")
struct MRZParserTests {

    // The Doc 9303 TD3 specimen: Anna Maria Eriksson, Utopia.
    private let passportLine1 = "P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<"
    private let passportLine2 = "L898902C36UTO7408122F1204159ZE184226B<<<<<10"

    // The Doc 9303 TD1 specimen, the format Italian ID cards use.
    private let idLine1 = "I<UTOD231458907<<<<<<<<<<<<<<<"
    private let idLine2 = "7408122F1204159UTO<<<<<<<<<<<6"
    private let idLine3 = "ERIKSSON<<ANNA<MARIA<<<<<<<<<<"

    // MARK: - Check digits

    @Test("Computes the ICAO check digit")
    func checkDigits() {
        // The weighted 7-3-1 sum is what makes an MRZ verifiable rather than
        // merely readable.
        #expect(MRZParser.checkDigit("L898902C3") == 6)
        #expect(MRZParser.checkDigit("740812") == 2)
        #expect(MRZParser.checkDigit("120415") == 9)
        #expect(MRZParser.checkDigit("D23145890") == 7)
    }

    @Test("Filler counts as zero and letters start at ten")
    func checkDigitAlphabet() {
        #expect(MRZParser.checkDigit("<<<<<<") == 0)
        #expect(MRZParser.checkDigit("A") == 10 * 7 % 10)
    }

    // MARK: - Passports

    @Test("Reads a passport")
    func passport() throws {
        let document = try #require(MRZParser.parse(lines: [passportLine1, passportLine2]))

        #expect(document.format == .td3)
        #expect(document.documentCode == "P")
        #expect(document.issuingCountry == "UTO")
        #expect(document.surname == "ERIKSSON")
        #expect(document.givenNames == "ANNA MARIA")
        #expect(document.fullName == "ANNA MARIA ERIKSSON")
        #expect(document.documentNumber == "L898902C3")
        #expect(document.nationality == "UTO")
        #expect(document.sex == "F")
    }

    @Test("Every check digit on a clean passport validates")
    func passportVerifies() throws {
        let document = try #require(MRZParser.parse(lines: [passportLine1, passportLine2]))
        #expect(document.isFullyVerified)
    }

    @Test("Dates decode, with the century inferred")
    func passportDates() throws {
        let document = try #require(MRZParser.parse(lines: [passportLine1, passportLine2]))

        // 740812 is a birth date, so it cannot be 2074.
        #expect(document.dateOfBirth.year == 1974)
        #expect(document.dateOfBirth.month == 8)
        #expect(document.dateOfBirth.day == 12)

        // 120415 is an expiry, so it is 2012 rather than 1912.
        #expect(document.expiryDate.year == 2012)
        #expect(document.expiryDate.month == 4)
        #expect(document.expiryDate.day == 15)
    }

    @Test("A misread character is caught by its check digit")
    func detectsMisread() throws {
        // OCR reads 8 as B on thermal-quality print constantly. The value still
        // comes back — the flag is what tells the UI to ask.
        let corrupted = "LB98902C36UTO7408122F1204159ZE184226B<<<<<10"
        let document = try #require(MRZParser.parse(lines: [passportLine1, corrupted]))

        #expect(document.documentNumber == "LB98902C3")
        #expect(!document.numberIsValid)
        #expect(!document.isFullyVerified)
        // The other fields are untouched, so they still validate.
        #expect(document.birthIsValid)
        #expect(document.expiryIsValid)
    }

    // MARK: - ID cards

    @Test("Reads a three-line ID card")
    func identityCard() throws {
        let document = try #require(MRZParser.parse(lines: [idLine1, idLine2, idLine3]))

        #expect(document.format == .td1)
        #expect(document.documentNumber == "D23145890")
        #expect(document.surname == "ERIKSSON")
        #expect(document.givenNames == "ANNA MARIA")
        #expect(document.nationality == "UTO")
        #expect(document.numberIsValid)
        #expect(document.birthIsValid)
        #expect(document.expiryIsValid)
    }

    // MARK: - Finding the zone in a page of OCR

    @Test("Finds the zone among the rest of the page")
    func findsZoneInNoise() throws {
        // What Vision actually returns: the whole document, the zone last.
        let page = [
            "REPUBBLICA ITALIANA",
            "PASSAPORTO / PASSPORT",
            "Cognome / Surname",
            "ERIKSSON",
            "Nome / Given names",
            "ANNA MARIA",
            passportLine1,
            passportLine2
        ]
        let document = try #require(MRZParser.parse(lines: page))
        #expect(document.documentNumber == "L898902C3")
    }

    @Test("Survives the spacing and glyphs Vision introduces")
    func toleratesOcrArtefacts() throws {
        // Vision spaces out the zone and reads the filler as a guillemet.
        let spaced = "P«UTOERIKSSON««ANNA«MARIA«««««««««««««««««««"
        let document = try #require(MRZParser.parse(lines: [spaced, passportLine2]))
        #expect(document.surname == "ERIKSSON")
    }

    @Test("Ordinary text is not mistaken for a zone")
    func rejectsProse() {
        #expect(MRZParser.parse(lines: []) == nil)
        #expect(MRZParser.parse(lines: ["REPUBBLICA ITALIANA", "Carta d'identità"]) == nil)
        // Right alphabet, wrong width.
        #expect(MRZParser.parse(lines: ["P<UTOERIKSSON", "L898902C36UTO"]) == nil)
    }

    @Test("A single line is not enough")
    func needsBothLines() {
        #expect(MRZParser.parse(lines: [passportLine1]) == nil)
        #expect(MRZParser.parse(lines: [idLine1, idLine2]) == nil)
    }

    @Test("An impossible date is rejected rather than stored")
    func rejectsImpossibleDates() {
        // Month 19 — OCR misread, not a date.
        let bad = "L898902C36UTO7419122F1204159ZE184226B<<<<<10"
        #expect(MRZParser.parse(lines: [passportLine1, bad]) == nil)
    }
}
