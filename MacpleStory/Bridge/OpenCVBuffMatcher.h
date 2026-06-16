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
@end

@interface OpenCVBuffMatcher : NSObject

/// 다중 스케일 TM_CCOEFF_NORMED로 frameImage 안에서 templateImage 위치를 찾는다.
/// 밝기/대비 변화에 강하며, 최고 점수와 위치를 함께 반환한다.
///
/// normalizedSearchRegion: 0...1 정규화된 검색 영역(좌상단 원점). 이 영역 안에서만
/// 매칭하며, 반환 위치는 전체 프레임 픽셀 좌표로 변환된다. 전체 검색은 {0,0,1,1}.
+ (OpenCVBuffMatchResult *)matchTemplate:(CGImageRef)templateImage
                                 inFrame:(CGImageRef)frameImage
                            searchRegion:(CGRect)normalizedSearchRegion
                               threshold:(double)threshold;

@end

NS_ASSUME_NONNULL_END
