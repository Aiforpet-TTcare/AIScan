import XCTest
import AIScan

final class AIScanContractResultTests: XCTestCase {
    func testPartnerCallbackExposesAndEncodesDirectPayload() throws {
        let result = AIScanResult(
            status: "OK",
            contractResult: [
                "diagId": 42,
                "status": "OK",
                "details": [["code": "opacity"]]
            ]
        )

        XCTAssertEqual(result.contractResult?["diagId"] as? Int, 42)
        XCTAssertNil(result.contractResult?["schema"])
        XCTAssertNil(result.contractResult?["payload"])

        let object = try XCTUnwrap(result.jsonObject)
        XCTAssertEqual(object["diagId"] as? Int, 42)
        XCTAssertEqual(object["status"] as? String, "OK")
        XCTAssertNil(object["contract_result"])
        XCTAssertNil(object["payload"])
    }

    func testDirectPartnerPayloadRoundTripsWithoutEnvelope() throws {
        let data = Data(#"{"diagId":42,"status":"OK","petType":"DOG","part":"EYE","details":[]}"#.utf8)
        let result = try JSONDecoder().decode(AIScanResult.self, from: data)

        XCTAssertEqual(result.contractResult?["diagId"] as? Double, 42)
        let encoded = try JSONEncoder().encode(result)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertEqual(object["diagId"] as? Double, 42)
        XCTAssertNil(object["contract_result"])
    }
}
