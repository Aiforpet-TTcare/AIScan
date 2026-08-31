#import <Foundation/Foundation.h>
#import <AIScanCore/AISCScanTypes.h>

NS_ASSUME_NONNULL_BEGIN

/// Display-approved explanatory copy. Diagnostic rules and model metadata are
/// deliberately absent from this value object.
@interface AISCDisplayDetail : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *key;
@property (nonatomic, copy, readonly, nullable) NSString *title;
@property (nonatomic, copy, readonly) NSArray<NSString *> *contents;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithKey:(nullable NSString *)key
                       title:(nullable NSString *)title
                    contents:(NSArray<NSString *> *)contents NS_DESIGNATED_INITIALIZER;

@end

@interface AISCDisplaySymptom : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *code;
@property (nonatomic, copy, readonly, nullable) NSString *name;
@property (nonatomic, strong, readonly, nullable) NSURL *heatmapURL;
@property (nonatomic, strong, readonly, nullable) NSURL *cropImageURL;
@property (nonatomic, assign, readonly) NSInteger abnormalLevel;
@property (nonatomic, copy, readonly, nullable) NSString *resultLabel;
@property (nonatomic, copy, readonly) NSArray<AISCDisplayDetail *> *details;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCode:(nullable NSString *)code
                        name:(nullable NSString *)name
                  heatmapURL:(nullable NSURL *)heatmapURL
                cropImageURL:(nullable NSURL *)cropImageURL
               abnormalLevel:(NSInteger)abnormalLevel
                 resultLabel:(nullable NSString *)resultLabel;
- (instancetype)initWithCode:(nullable NSString *)code
                        name:(nullable NSString *)name
                  heatmapURL:(nullable NSURL *)heatmapURL
                cropImageURL:(nullable NSURL *)cropImageURL
               abnormalLevel:(NSInteger)abnormalLevel
                 resultLabel:(nullable NSString *)resultLabel
                     details:(NSArray<AISCDisplayDetail *> *)details NS_DESIGNATED_INITIALIZER;

@end

/// Display-only skin condition meters. Core derives these privately; the
/// public UI receives only bounded values.
@interface AISCDisplaySkinFeatures : NSObject

@property (nonatomic, assign, readonly) NSInteger sensitivity;
@property (nonatomic, assign, readonly) NSInteger dryness;
@property (nonatomic, assign, readonly) NSInteger roughness;
@property (nonatomic, assign, readonly) NSInteger total;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSensitivity:(NSInteger)sensitivity
                             dryness:(NSInteger)dryness
                           roughness:(NSInteger)roughness
                               total:(NSInteger)total NS_DESIGNATED_INITIALIZER;

@end

/// Partner-defined response returned without SDK-side field remapping.
/// The payload is JSON-compatible and follows the manifest response contract.
@interface AISCContractResult : NSObject

@property (nonatomic, copy, readonly) NSString *schema;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *payload;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSchema:(NSString *)schema
                        payload:(NSDictionary<NSString *, id> *)payload NS_DESIGNATED_INITIALIZER;

@end

@interface AISCDisplayResult : NSObject

@property (nonatomic, copy, readonly) NSString *status;
@property (nonatomic, copy, readonly, nullable) NSString *diagnosisID;
/// Abnormal-only collection used by the existing result tabs.
@property (nonatomic, copy, readonly) NSArray<AISCDisplaySymptom *> *symptoms;
/// Complete analyzed catalog (normal and abnormal) used by reports.
@property (nonatomic, copy, readonly) NSArray<AISCDisplaySymptom *> *analyzedSymptoms;
/// Original common result rows (home care for a normal image, veterinary-care
/// guidance for an abnormal image). These are display-approved strings only.
@property (nonatomic, copy, readonly) NSArray<AISCDisplayDetail *> *resultDetails;
/// Server diagnosis creation time, or the local completion time for on-device
/// analysis. This is display metadata only.
@property (nonatomic, strong, readonly) NSDate *analyzedAt;
@property (nonatomic, strong, readonly, nullable) AISCDisplaySkinFeatures *skinFeatures;
@property (nonatomic, strong, readonly, nullable) AISCContractResult *contractResult;
/// True when the remote analysis rejected image quality and the camera should
/// stay open for a fresh capture instead of completing the host callback.
@property (nonatomic, assign, readonly) BOOL requiresRetake;
/// Display-safe provider reason code. Private diagnostic policy stays internal.
@property (nonatomic, copy, readonly, nullable) NSString *retakeReasonCode;
/// Display-safe answers collected by the source UI. Wire payload details stay
/// inside Core.
@property (nonatomic, copy, readonly) NSArray<AISCQuestionnaireAnswer *> *questionnaireAnswers;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms
                contractResult:(nullable AISCContractResult *)contractResult;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms
                contractResult:(nullable AISCContractResult *)contractResult
                requiresRetake:(BOOL)requiresRetake
              retakeReasonCode:(nullable NSString *)retakeReasonCode;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms
                contractResult:(nullable AISCContractResult *)contractResult
                requiresRetake:(BOOL)requiresRetake
              retakeReasonCode:(nullable NSString *)retakeReasonCode
          questionnaireAnswers:(NSArray<AISCQuestionnaireAnswer *> *)questionnaireAnswers;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms
                  skinFeatures:(nullable AISCDisplaySkinFeatures *)skinFeatures
                contractResult:(nullable AISCContractResult *)contractResult
                requiresRetake:(BOOL)requiresRetake
              retakeReasonCode:(nullable NSString *)retakeReasonCode
          questionnaireAnswers:(NSArray<AISCQuestionnaireAnswer *> *)questionnaireAnswers;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms
              analyzedSymptoms:(NSArray<AISCDisplaySymptom *> *)analyzedSymptoms
                  skinFeatures:(nullable AISCDisplaySkinFeatures *)skinFeatures
                contractResult:(nullable AISCContractResult *)contractResult
                requiresRetake:(BOOL)requiresRetake
              retakeReasonCode:(nullable NSString *)retakeReasonCode
          questionnaireAnswers:(NSArray<AISCQuestionnaireAnswer *> *)questionnaireAnswers;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms
              analyzedSymptoms:(NSArray<AISCDisplaySymptom *> *)analyzedSymptoms
                 resultDetails:(NSArray<AISCDisplayDetail *> *)resultDetails
                  skinFeatures:(nullable AISCDisplaySkinFeatures *)skinFeatures
                contractResult:(nullable AISCContractResult *)contractResult
                requiresRetake:(BOOL)requiresRetake
              retakeReasonCode:(nullable NSString *)retakeReasonCode
          questionnaireAnswers:(NSArray<AISCQuestionnaireAnswer *> *)questionnaireAnswers;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms
              analyzedSymptoms:(NSArray<AISCDisplaySymptom *> *)analyzedSymptoms
                 resultDetails:(NSArray<AISCDisplayDetail *> *)resultDetails
                    analyzedAt:(NSDate *)analyzedAt
                  skinFeatures:(nullable AISCDisplaySkinFeatures *)skinFeatures
                contractResult:(nullable AISCContractResult *)contractResult
                requiresRetake:(BOOL)requiresRetake
              retakeReasonCode:(nullable NSString *)retakeReasonCode
          questionnaireAnswers:(NSArray<AISCQuestionnaireAnswer *> *)questionnaireAnswers NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
