#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AISCDisplayAssetCompletion)(NSData *_Nullable data, NSError *_Nullable error);

/// Loads display-only result assets while keeping transport, size limits, and
/// error classification inside the private Core binary.
@interface AISCDisplayAssetLoader : NSObject

+ (void)loadDataFromURL:(NSURL *)url
             completion:(AISCDisplayAssetCompletion)completion
    NS_SWIFT_NAME(loadData(from:completion:));

@end

NS_ASSUME_NONNULL_END
