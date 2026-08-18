import Testing

@testable import CodeCrackerKit

@Suite("SecretCode")
struct SecretCodeTests {
    @Test("accepts four distinct digits", arguments: ["1234", "9876", "1023", " 4567 "])
    func acceptsValidCodes(_ text: String) {
        #expect(SecretCode(text) != nil)
    }

    @Test(
        "rejects repeats, wrong length, non-numbers and leading zeros",
        arguments: ["1123", "1111", "123", "12345", "", "abcd", "12.4", "-1234", "0123"]
    )
    func rejectsInvalidCodes(_ text: String) {
        #expect(SecretCode(text) == nil)
    }

    @Test("throwing initialiser reports invalidCode")
    func throwingInitialiser() {
        #expect(throws: GameError.invalidCode) {
            try SecretCode(validating: "1123")
        }
    }

    @Test("round-trips through its description")
    func description() throws {
        #expect(try code("1023").description == "1023")
    }

    @Test("an exact guess scores four positions")
    func exactGuess() throws {
        let feedback = try code("5678").feedback(against: code("5678"))
        #expect(feedback.correctPositions == 4)
        #expect(feedback.correctDigits == 0)
        #expect(feedback.isExact)
    }

    @Test("counts misplaced digits separately from placed ones")
    func partialGuess() throws {
        // 1 and 2 are in place; 4 and 3 are present but swapped.
        let feedback = try code("1243").feedback(against: code("1234"))
        #expect(feedback.correctPositions == 2)
        #expect(feedback.correctDigits == 2)
        #expect(!feedback.isExact)
    }

    @Test("a guess sharing no digits scores zero")
    func missedGuess() throws {
        let feedback = try code("5678").feedback(against: code("1234"))
        #expect(feedback.correctPositions == 0)
        #expect(feedback.correctDigits == 0)
    }
}
