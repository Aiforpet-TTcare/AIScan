#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AISCEnvironment) {
    AISCEnvironmentProduction = 0,
    AISCEnvironmentDevelopment = 1,
};

@interface AISCConfiguration : NSObject

@property (nonatomic, copy, readonly) NSString *publishableKey;
@property (nonatomic, assign) AISCEnvironment environment;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPublishableKey:(NSString *)publishableKey NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
