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
    func testLegacyExceptionalPayloadsPreserveNullEmptyAndUnknownFields() throws {
        let fixtures = [
            #"{"status":"PENDING","recordId":"dx_fixture","vendorId":"fixture-vendor","userId":"","petId":null,"petType":"DOG","part":"EYE","createdAt":1700000000000,"result":null}"#,
            #"{"status":"RETRY","recordId":"dx_fixture","vendorId":"fixture-vendor","userId":null,"petId":"","petType":"DOG","part":"EYE","createdAt":1700000000000,"result":{"retryReasons":[{"retryReason":"UNKNOWN","message":"","cropImageUrl":null}]}}"#,
            #"{"status":"ERROR","code":500,"statusCode":500,"errorCode":"E00001","message":"diagnosis internal server error","error":"diagnosis process failed."}"#,
            #"{"status":"OK","diagId":9007199254740993,"details":[{"code":"hyperemia","vetTip":null,"positions":[{"abnormalLevel":-1,"abnormalRatio":0.0,"imagePath":"https://fixtures.invalid/unknown.png"},{"abnormalLevel":-2,"abnormalRatio":0.0,"imagePath":null}]}],"future":{"nullable":null,"array":[]}}"#
        ]
        for fixture in fixtures {
            let data = Data(fixture.utf8)
            let expected = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let result = try JSONDecoder().decode(AIScanResult.self, from: data)
            XCTAssertNotNil(result.contractResult)
            let encoded = try JSONEncoder().encode(result)
            let actual = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            XCTAssertTrue(NSDictionary(dictionary: actual).isEqual(to: expected), fixture)
            XCTAssertTrue(NSDictionary(dictionary: try XCTUnwrap(result.jsonObject)).isEqual(to: expected), fixture)
        }
    }
}
