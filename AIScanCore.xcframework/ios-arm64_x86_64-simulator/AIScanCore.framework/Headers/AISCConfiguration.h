#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AISCEnvironment) {
    AISCEnvironmentProduction = 0,
    AISCEnvironmentDevelopment = 1,
};

@interface AISCConfiguration : NSObject

@property (nonatomic, copy, readonly) NSString *publishableKey;
@property (nonatomic, assign) AISCEnvironment environment;
@property (nonatomic, copy, nullable) NSString *bundleIdentifierOverride;
@property (nonatomic, copy, nullable) NSString *appVersionOverride;
@property (nonatomic, copy, nullable) NSString *teamIdentifierOverride;
@property (nonatomic, strong, nullable) NSURL *resourceDirectoryURL;
@property (nonatomic, assign) NSTimeInterval requestTimeout;
@property (nonatomic, strong, nullable) dispatch_queue_t callbackQueue;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPublishableKey:(NSString *)publishableKey NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
