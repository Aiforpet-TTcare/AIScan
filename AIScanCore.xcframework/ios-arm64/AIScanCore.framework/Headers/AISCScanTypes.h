#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AISCPetType) {
    AISCPetTypeDog = 0,
    AISCPetTypeCat = 1,
    AISCPetTypeUnknown = 99,
};

typedef NS_ENUM(NSInteger, AISCPartType) {
    AISCPartTypeEye = 0,
    AISCPartTypeTeeth = 1,
    AISCPartTypeSkin = 2,
    AISCPartTypeJoint = 3,
    AISCPartTypeUnknown = 99,
};

/// Execution route selected by the organization/project manifest.
/// Missing or unknown manifest values always fall back to on-device analysis.
typedef NS_ENUM(NSInteger, AISCAnalysisMode) {
    AISCAnalysisModeOnDevice = 0,
    AISCAnalysisModeTTAPI = 1,
    AISCAnalysisModeHybrid = 2,
};

typedef NS_ENUM(NSInteger, AISCFrameOrientation) {
    AISCFrameOrientationUp = 0,
    AISCFrameOrientationRight = 1,
    AISCFrameOrientationDown = 2,
    AISCFrameOrientationLeft = 3,
};

/// One display-safe questionnaire prompt. Network URLs, catalog structure,
/// and response rules remain private to Core.
@interface AISCQuestionnairePrompt : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *text;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIdentifier:(NSString *)identifier
                              text:(NSString *)text NS_DESIGNATED_INITIALIZER;

@end

@interface AISCQuestionnaire : NSObject

@property (nonatomic, copy, readonly) NSArray<AISCQuestionnairePrompt *> *prompts;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPrompts:(NSArray<AISCQuestionnairePrompt *> *)prompts NS_DESIGNATED_INITIALIZER;

@end

@interface AISCQuestionnaireAnswer : NSObject

@property (nonatomic, strong, readonly) AISCQuestionnairePrompt *prompt;
@property (nonatomic, assign, readonly) BOOL positive;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPrompt:(AISCQuestionnairePrompt *)prompt
                       positive:(BOOL)positive NS_DESIGNATED_INITIALIZER;

@end

@interface AISCScanContext : NSObject

@property (nonatomic, assign) AISCPetType petType;
@property (nonatomic, assign) AISCPartType partType;
@property (nonatomic, copy, nullable) NSString *displaySubpart;
/// Exact provider sub-part sent as analysis context. When omitted, the Core
/// may fall back to `displaySubpart` for compatibility with existing hosts.
@property (nonatomic, copy, nullable) NSString *analysisSubpart;
/// Exact provider position sent as analysis context.
@property (nonatomic, copy, nullable) NSString *analysisPosition;
@property (nonatomic, copy, nullable) NSString *userIdentifier;
@property (nonatomic, copy, nullable) NSString *petIdentifier;
@property (nonatomic, copy, nullable) NSString *recordIdentifier;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *displayMetadata;
/// High-level UI opts in by default; direct Core clients stay unchanged.
@property (nonatomic, assign) BOOL questionnaireEnabled;

@end

@interface AISCFrameInput : NSObject

@property (nonatomic, assign, readonly) CVPixelBufferRef pixelBuffer;
@property (nonatomic, assign) AISCFrameOrientation orientation;
@property (nonatomic, assign) CMTime timestamp;
@property (nonatomic, assign) CGRect regionOfInterest;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSNumber *> *cameraMetadata;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer NS_DESIGNATED_INITIALIZER;

@end

typedef NS_ENUM(NSInteger, AISCImageUploadEncoding) {
    AISCImageUploadEncodingJPEG = 0,
    AISCImageUploadEncodingLosslessPNG = 1,
};

@interface AISCImageInput : NSObject

@property (nonatomic, assign, readonly, nullable) CVPixelBufferRef pixelBuffer;
@property (nonatomic, strong, readonly, nullable) NSURL *imageURL;
@property (nonatomic, assign) AISCFrameOrientation orientation;
@property (nonatomic, assign) AISCImageUploadEncoding uploadEncoding;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *displayMetadata;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (instancetype)initWithImageURL:(NSURL *)imageURL;

@end

NS_ASSUME_NONNULL_END
