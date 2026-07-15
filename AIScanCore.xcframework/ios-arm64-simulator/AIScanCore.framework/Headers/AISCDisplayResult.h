#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AISCDisplaySymptom : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *code;
@property (nonatomic, copy, readonly, nullable) NSString *name;
@property (nonatomic, strong, readonly, nullable) NSURL *heatmapURL;
@property (nonatomic, strong, readonly, nullable) NSURL *cropImageURL;
@property (nonatomic, assign, readonly) NSInteger abnormalLevel;
@property (nonatomic, copy, readonly, nullable) NSString *resultLabel;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCode:(nullable NSString *)code
                        name:(nullable NSString *)name
                  heatmapURL:(nullable NSURL *)heatmapURL
                cropImageURL:(nullable NSURL *)cropImageURL
               abnormalLevel:(NSInteger)abnormalLevel
                 resultLabel:(nullable NSString *)resultLabel NS_DESIGNATED_INITIALIZER;

@end

@interface AISCDisplayResult : NSObject

@property (nonatomic, copy, readonly) NSString *status;
@property (nonatomic, copy, readonly, nullable) NSString *diagnosisID;
@property (nonatomic, copy, readonly) NSArray<AISCDisplaySymptom *> *symptoms;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStatus:(NSString *)status
                   diagnosisID:(nullable NSString *)diagnosisID
                      symptoms:(NSArray<AISCDisplaySymptom *> *)symptoms NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
