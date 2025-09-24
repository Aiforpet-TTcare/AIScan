//
//  HPHeatmap.h
//  AIScan
//
//  Created by Jay Lee on 8/4/25.
//  Refactored for clarity and efficiency.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: - HPSmoothedData
/**
 * @class HPSmoothedData
 * @brief C 레벨에서 생성된 순수한 히트맵 바이트 데이터(Grayscale)와 크기 정보를 담는 컨테이너 클래스.
 * @discussion 이 객체는 UI에 직접 표시할 수 없으며, asImage 메서드를 통해 UIImage로 변환해야 합니다.
 */
@interface HPSmoothedData : NSObject
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, readonly) int height;
@property (nonatomic, readonly) int width;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * @brief 내부의 바이트 데이터를 UIImage로 변환합니다.
 * @return 변환된 UIImage 객체, 실패 시 nil.
 */
- (nullable UIImage *)asImage;
@end

// MARK: - Polygon Extraction (2D Int Arrays)
/**
 * C 레벨 가변 2차 정수 배열([[x,y,...],[...]] = 각 폴리곤별 [x,y]쌍 나열)를
 * 안전하게 보관/해제하는 컨테이너.
 *
 * 메모리 소유권:
 *  - polys[i] 및 sizes, polys 배열 자체는 C에서 malloc 된 버퍼이며,
 *    본 객체의 dealloc에서 모두 free(hp_free_bytes와 동일) 됩니다.
 */
@interface HPPolygons2D : NSObject
@property (nonatomic, readonly) int polyCount;          // 폴리곤 개수
@property (nonatomic, readonly) int * _Nonnull * _Nonnull polys; // [polyCount][2 * sizes[i]]
@property (nonatomic, readonly) int * _Nonnull sizes;   // 각 폴리곤 점 개수
@property (nonatomic, readonly) int thresholdUsed;      // 내부 선택 임계값(0..255)
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end



// MARK: - HPHeatmap
@interface HPHeatmap : NSObject

// MARK: Primary Use Case (일반적인 사용 사례)
/**
 * @brief [일반용] ML 모델 출력값으로부터 최종 오버레이 이미지를 한 번에 생성합니다.
 * @discussion 가장 간단하고 효율적인 방법입니다. 대부분의 경우 이 메서드 사용을 권장합니다.
 * @param image 원본 UIImage
 * @param grad ML 모델의 그래디언트 맵 (float 배열)
 * @param det ML 모델의 탐지 결과 (float 배열)
 * @param mask ML 모델의 마스크 프로토타입 (float 배열)
 * @param pet "dog" 또는 "cat"
 * @param part "eye", "skin" 등 부위
 * @param model "hyperemia" 등 질병/모델명
 * @return 생성된 오버레이 UIImage, 실패 시 nil
 */
+ (nullable UIImage *)generateOverlayImageFrom:(UIImage *)image
                                          grad:(const float *)grad gradLen:(int)gradLen
                                           det:(const float *)det detLen:(int)detLen
                                          mask:(const float *)mask maskLen:(int)maskLen
                                    abnormalyn:(int)abnormalyn
                                           pet:(NSString *)pet part:(NSString *)part model:(NSString *)model;


// MARK: - Advanced Use Cases (고급 활용 사례)

/**
 * @brief [고급용/1단계] ML 모델 출력값으로부터 순수한 히트맵 데이터(HPSmoothedData)를 생성합니다.
 * @discussion 생성된 HPSmoothedData는 다른 메서드에 전달하여 재사용할 수 있습니다.
 * @return HPSmoothedData 객체, 실패 시 nil
 */
+ (nullable HPSmoothedData *)generateSmoothedDataFrom:(UIImage *)image
                                                 grad:(const float *)grad gradLen:(int)gradLen
                                                  det:(const float *)det detLen:(int)detLen
                                                 mask:(const float *)mask maskLen:(int)maskLen
                                           abnormalyn:(int)abnormalyn
                                                  pet:(NSString *)pet part:(NSString *)part model:(NSString *)model;
/**
 * @brief [고급용/2단계] 원본 이미지와 HPSmoothedData를 사용해 오버레이 이미지를 생성합니다.
 * @discussion generateSmoothedDataFrom:으로 얻은 데이터를 재사용하여 효율적으로 오버레이를 만듭니다.
 * @param image 원본 UIImage
 * @param smoothedData 이전에 생성된 HPSmoothedData 객체
 * @return 생성된 오버레이 UIImage, 실패 시 nil
 */
+ (nullable UIImage *)generateOverlayImageFromImage:(UIImage *)image
                                 withSmoothedData:(HPSmoothedData *)smoothedData
                                              pet:(NSString *)pet part:(NSString *)part model:(NSString *)model;


/**
 * @brief [편의용] 히트맵 데이터를 생성하고 즉시 UIImage로 변환하여 반환합니다.
 * @discussion 중간 결과인 히트맵을 이미지로 직접 확인하고 싶을 때 사용합니다.
 * @return 생성된 그레이스케일 히트맵 UIImage, 실패 시 nil
 */
+ (nullable UIImage *)generateSmoothedImageFrom:(UIImage *)image
                                           grad:(const float *)grad gradLen:(int)gradLen
                                            det:(const float *)det detLen:(int)detLen
                                           mask:(const float *)mask maskLen:(int)maskLen
                                     abnormalyn:(int)abnormalyn
                                            pet:(NSString *)pet part:(NSString *)part model:(NSString *)model;
@end


// MARK: - Polygon Extraction (JSON)
@interface HPHeatmap (Polygons)

/**
 * @brief [고급] 스무딩 히트맵(HPSmoothedData)에서 폴리곤을 추출해 JSON 문자열로 반환합니다.
 *        JSON 포맷: "[[x1,y1,...],[...]]"
 * @param smoothedData generateSmoothedDataFrom: 으로 생성한 히트맵 데이터
 * @param pet  "dog" | "cat"
 * @param part 예: "eye", "skin", "tooth"
 * @param model 예: "redness", "hyperemia", ...
 * @param simplifyTolerance RDP 단순화 톨러런스(픽셀 단위). 0이면 단순화 최소화.
 * @param onlyLargest 최대 면적 폴리곤 하나만 남길지 여부
 * @param outThresholdUsed 내부적으로 선택된 임계값(0..255). 필요 없으면 NULL.
 * @return JSON 문자열(autorelease). 실패 시 nil.
 */
+ (nullable NSString *)extractPolygonsJSONFromSmoothedData:(HPSmoothedData *)smoothedData
                                                       pet:(NSString *)pet
                                                      part:(NSString *)part
                                                     model:(NSString *)model
                                        simplifyTolerance:(float)simplifyTolerance
                                              onlyLargest:(BOOL)onlyLargest
                                         thresholdUsedOut:(nullable int *)outThresholdUsed;
/** 축약 **/
+ (nullable NSString *)extractPolygonsJSONFromSmoothedData:(HPSmoothedData *)smoothedData
                                                       pet:(NSString *)pet
                                                      part:(NSString *)part
                                                     model:(NSString *)model
                                        simplifyTolerance:(float)simplifyTolerance
                                              onlyLargest:(BOOL)onlyLargest;

/**
 * @brief [편의] 이미지+모델출력으로 스무딩→폴리곤 JSON까지 한 번에 수행.
 *        내부에서 generateSmoothedDataFrom:을 호출해 중간 버퍼를 관리합니다.
 */
+ (nullable NSString *)extractPolygonsJSONFrom:(UIImage *)image
                                          grad:(const float *)grad gradLen:(int)gradLen
                                           det:(const float *)det detLen:(int)detLen
                                          mask:(const float *)mask maskLen:(int)maskLen
                                    abnormalyn:(int)abnormalyn
                                           pet:(NSString *)pet
                                          part:(NSString *)part
                                         model:(NSString *)model
                            simplifyTolerance:(float)simplifyTolerance
                                  onlyLargest:(BOOL)onlyLargest
                             thresholdUsedOut:(nullable int *)outThresholdUsed;

@end


@interface HPHeatmap (Polygons2D)

+ (nullable HPPolygons2D *)extractPolygons2DFromSmoothedData:(nonnull HPSmoothedData *)smoothedData
                                                         pet:(nonnull NSString *)pet
                                                        part:(nonnull NSString *)part
                                                       model:(nonnull NSString *)model
                                          simplifyTolerance:(float)simplifyTolerance
                                                onlyLargest:(BOOL)onlyLargest;

+ (nullable HPPolygons2D *)extractPolygons2DFrom:(nonnull UIImage *)image
                                            grad:(nonnull const float *)grad gradLen:(int)gradLen
                                             det:(nonnull const float *)det detLen:(int)detLen
                                            mask:(nonnull const float *)mask maskLen:(int)maskLen
                                      abnormalyn:(int)abnormalyn
                                             pet:(nonnull NSString *)pet
                                            part:(nonnull NSString *)part
                                           model:(nonnull NSString *)model
                              simplifyTolerance:(float)simplifyTolerance
                                    onlyLargest:(BOOL)onlyLargest;

@end


@interface HPPolygons2D ()
- (instancetype)initWithPolys:(int * _Nonnull * _Nonnull)polys
                        sizes:(int * _Nonnull)sizes
                    polyCount:(int)polyCount
               thresholdUsed:(int)thr NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
