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

typedef NS_ENUM(NSInteger, AISCFrameOrientation) {
    AISCFrameOrientationUp = 0,
    AISCFrameOrientationRight = 1,
    AISCFrameOrientationDown = 2,
    AISCFrameOrientationLeft = 3,
};

@interface AISCScanContext : NSObject

@property (nonatomic, assign) AISCPetType petType;
@property (nonatomic, assign) AISCPartType partType;
@property (nonatomic, copy, nullable) NSString *displaySubpart;
@property (nonatomic, copy, nullable) NSString *userIdentifier;
@property (nonatomic, copy, nullable) NSString *petIdentifier;
@property (nonatomic, copy, nullable) NSString *recordIdentifier;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *displayMetadata;

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

@interface AISCImageInput : NSObject

@property (nonatomic, assign, readonly, nullable) CVPixelBufferRef pixelBuffer;
@property (nonatomic, strong, readonly, nullable) NSURL *imageURL;
@property (nonatomic, assign) AISCFrameOrientation orientation;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *displayMetadata;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (instancetype)initWithImageURL:(NSURL *)imageURL;

@end

NS_ASSUME_NONNULL_END
