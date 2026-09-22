import XCTest
import AIScan

final class AIScanContractResultTests: XCTestCase {
    private var payload: [String: Any] {
        [
            "diagId": "diagnosis-example",
            "status": "OK",
            "isAbnormal": false,
            "result": ["score": 0.25, "count": 3, "missing": NSNull()],
            "items": ["first", "second"],
            "extensionField": ["preserved": true]
        ]
    }

    func testLegacyDictionaryInitializerAndSubscriptRemainAvailable() {
        let result = AIScanResult(status: "completed", contractResult: payload)
        XCTAssertEqual(result.contractResult?["diagId"] as? String, "diagnosis-example")
        XCTAssertNil(AIScanResult(status: "completed", contractResult: nil).contractResult)
    }

    func testEveryLegacyJSONSurfaceReturnsTheExactDirectPayload() throws {
        let result = AIScanResult(status: "completed", diagnosisID: "display-only", contractResult: payload)
        assertPayload(try XCTUnwrap(result.jsonObject))
        for string in [result.string, result.jsonString] {
            let data = Data(try XCTUnwrap(string).utf8)
            assertPayload(try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]))
        }
        let encoded = try JSONEncoder().encode(result)
        assertPayload(try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any]))
    }

    func testFlatPartnerPayloadDecodesAndRoundTripsWithoutLosingUnknownFields() throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = try JSONDecoder().decode(AIScanResult.self, from: data)
        assertPayload(try XCTUnwrap(result.contractResult))
        assertPayload(try XCTUnwrap(result.jsonObject))
    }

    func testLegacyNestedDictionaryDecodesToDirectPayload() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "status": "completed", "contract_result": payload
        ])
        let result = try JSONDecoder().decode(AIScanResult.self, from: data)
        assertPayload(try XCTUnwrap(result.contractResult))
        assertPayload(try XCTUnwrap(result.jsonObject))
    }

    func testTypedContractIsAdditiveAndDoesNotChangeCallbackJSON() throws {
        let contract = AIScanContractResult(schema: "example.v1", payload: payload)
        let result = AIScanResult(status: "completed", typedContractResult: contract)
        XCTAssertEqual(result.typedContractResult, contract)
        assertPayload(try XCTUnwrap(result.contractResult))
        assertPayload(try XCTUnwrap(result.jsonObject))
        XCTAssertEqual(try JSONDecoder().decode(AIScanContractResult.self,
                                               from: JSONEncoder().encode(contract)), contract)
    }

    func testStructuredConstructorRetainsItsOriginalLabelWithoutNilAmbiguity() throws {
        let contract = AIScanContractResult(schema: "example.v1", payload: payload)
        let result = AIScanResult(status: "completed", contractResult: contract)
        XCTAssertEqual(result.typedContractResult, contract)
        assertPayload(try XCTUnwrap(result.jsonObject))
        XCTAssertNil(AIScanResult(status: "completed", contractResult: nil).contractResult)
    }

    func testStoredStructuredEnvelopeDecodesAndNormalizesToDirectPayload() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "status": "completed",
            "diagnosisId": "display-id",
            "symptoms": [],
            "contract_result": ["schema": "example.v1", "payload": payload]
        ])
        let result = try JSONDecoder().decode(AIScanResult.self, from: data)
        XCTAssertEqual(result.typedContractResult?.schema, "example.v1")
        assertPayload(try XCTUnwrap(result.contractResult))
        assertPayload(try XCTUnwrap(result.jsonObject))
        let normalized = try JSONEncoder().encode(result)
        assertPayload(try XCTUnwrap(JSONSerialization.jsonObject(with: normalized) as? [String: Any]))
        let roundTrip = try JSONDecoder().decode(AIScanResult.self, from: normalized)
        assertPayload(try XCTUnwrap(roundTrip.contractResult))
        // Schema is transport metadata and is intentionally absent from callbacks.
        XCTAssertNil(roundTrip.typedContractResult)
    }

    func testNestedPartnerDictionaryWithAdditionalFieldsIsNotUnwrapped() throws {
        let dictionary: [String: Any] = [
            "schema": "partner-field", "payload": ["value": 1], "extensionField": true
        ]
        let data = try JSONSerialization.data(withJSONObject: [
            "status": "completed", "contract_result": dictionary
        ])
        let result = try JSONDecoder().decode(AIScanResult.self, from: data)
        XCTAssertTrue(NSDictionary(dictionary: try XCTUnwrap(result.contractResult)).isEqual(to: dictionary))
        XCTAssertNil(result.typedContractResult)
    }

    func testCompactResultDoesNotBecomeAContractPayload() throws {
        let result = AIScanResult(status: "completed", diagnosisID: "display-id")
        let decoded = try JSONDecoder().decode(AIScanResult.self, from: JSONEncoder().encode(result))
        XCTAssertNil(decoded.contractResult)
        XCTAssertEqual(decoded, result)
    }

    func testOnDeviceResultRetainsItsExistingJSONShape() throws {
        let result = AIScanResult(status: "SUCCESS", petType: "DOG", part: "EYE",
                                  response: OnDeviceResponse(status: "NORMAL"))
        let decoded = try JSONDecoder().decode(AIScanResult.self, from: JSONEncoder().encode(result))
        XCTAssertNil(decoded.contractResult)
        XCTAssertEqual(decoded, result)
        XCTAssertNil(result.jsonObject?["symptoms"])
        XCTAssertNotNil(result.jsonObject?["response"])
    }

    private func assertPayload(_ actual: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(NSDictionary(dictionary: actual).isEqual(to: payload), file: file, line: line)
        XCTAssertNil(actual["contract_result"], file: file, line: line)
        XCTAssertNil(actual["schema"], file: file, line: line)
        XCTAssertNil(actual["payload"], file: file, line: line)
    }
}
