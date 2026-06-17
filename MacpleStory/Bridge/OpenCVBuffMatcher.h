//
//  OpenCVBuffMatcher.h
//  MacpleStory
//
//  Objective-C 인터페이스만 노출한다(C++/OpenCV 타입은 .mm 내부에 숨김).
//  Swift는 브리징 헤더를 통해 이 인터페이스만 본다.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVBuffMatchResult : NSObject
@property (nonatomic, readonly) BOOL found;
/// TM_CCOEFF_NORMED 최고 점수(0...1로 클램프).
@property (nonatomic, readonly) double score;
/// 프레임 픽셀 좌표계의 매칭 위치(없으면 CGRectZero).
@property (nonatomic, readonly) CGRect regionInPixels;
/// 최고 점수로 매칭된 템플릿 식별자(없으면 nil).
@property (nonatomic, readonly, nullable) NSString *matchedTemplateId;
@end

/// 매칭에 사용할 템플릿. identifier로 스케일된 cv::Mat을 캐시한다.
@interface OpenCVBuffTemplate : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) CGImageRef image;
- (instancetype)initWithIdentifier:(NSString *)identifier image:(CGImageRef)image;
@end

@interface OpenCVBuffMatcher : NSObject

/// 프레임을 한 번만 cv::Mat으로 변환하고, 여러 템플릿을 그 위에서 다중 스케일 매칭한다.
/// 가장 높은 TM_CCOEFF_NORMED 점수의 템플릿/위치를 반환한다.
/// 템플릿의 스케일된 Mat은 identifier로 캐시되어 재사용된다.
///
/// normalizedSearchRegion: 0...1 정규화된 검색 영역(좌상단 원점). 전체 검색은 {0,0,1,1}.
+ (OpenCVBuffMatchResult *)matchTemplates:(NSArray<OpenCVBuffTemplate *> *)templates
                                  inFrame:(CGImageRef)frameImage
                             searchRegion:(CGRect)normalizedSearchRegion
                                threshold:(double)threshold;

@end

NS_ASSUME_NONNULL_END
