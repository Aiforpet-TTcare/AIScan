//
//  LoadMetadata.h
//  AIScan
//
//  Created by Jay Lee on 7/25/25.
//

#import <Foundation/Foundation.h>

@interface LoadMetadata : NSObject
+ (NSDictionary *)load:(NSString *)modelPath;
@end
