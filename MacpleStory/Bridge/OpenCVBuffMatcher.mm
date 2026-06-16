//
//  OpenCVBuffMatcher.mm
//  MacpleStory
//
//  OpenCV(cv::matchTemplate) 기반 템플릿 매칭 구현.
//

#import "OpenCVBuffMatcher.h"

#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>

#import <vector>

@implementation OpenCVBuffMatchResult

- (instancetype)initWithFound:(BOOL)found
                        score:(double)score
                regionInPixels:(CGRect)regionInPixels {
    self = [super init];
    if (self) {
        _found = found;
        _score = score;
        _regionInPixels = regionInPixels;
    }
    return self;
}

@end

static cv::Mat MacpleBGRMatFromCGImage(CGImageRef image) {
    const size_t width = CGImageGetWidth(image);
    const size_t height = CGImageGetHeight(image);

    if (width == 0 || height == 0) {
        return cv::Mat();
    }

    cv::Mat rgba((int)height, (int)width, CV_8UC4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
        rgba.data,
        width,
        height,
        8,
        rgba.step[0],
        colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);

    if (context == nullptr) {
        CGColorSpaceRelease(colorSpace);
        return cv::Mat();
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    cv::Mat bgr;
    cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);
    return bgr;
}

@implementation OpenCVBuffMatcher

+ (OpenCVBuffMatchResult *)matchTemplate:(CGImageRef)templateImage
                                 inFrame:(CGImageRef)frameImage
                            searchRegion:(CGRect)normalizedSearchRegion
                               threshold:(double)threshold {
    cv::Mat fullFrame = MacpleBGRMatFromCGImage(frameImage);
    cv::Mat templateBase = MacpleBGRMatFromCGImage(templateImage);

    if (fullFrame.empty() || templateBase.empty()) {
        return [[OpenCVBuffMatchResult alloc] initWithFound:NO score:0 regionInPixels:CGRectZero];
    }

    // 정규화 검색 영역을 프레임 픽셀 ROI로 변환(좌상단 원점)하고 경계로 클램프한다.
    int roiX = (int)std::lround(normalizedSearchRegion.origin.x * fullFrame.cols);
    int roiY = (int)std::lround(normalizedSearchRegion.origin.y * fullFrame.rows);
    int roiW = (int)std::lround(normalizedSearchRegion.size.width * fullFrame.cols);
    int roiH = (int)std::lround(normalizedSearchRegion.size.height * fullFrame.rows);
    roiX = std::min(std::max(roiX, 0), fullFrame.cols - 1);
    roiY = std::min(std::max(roiY, 0), fullFrame.rows - 1);
    roiW = std::min(std::max(roiW, 1), fullFrame.cols - roiX);
    roiH = std::min(std::max(roiH, 1), fullFrame.rows - roiY);

    const cv::Rect roiRect(roiX, roiY, roiW, roiH);
    cv::Mat frame = fullFrame(roiRect);

    // 캡처 해상도에 따라 아이콘 크기가 달라지므로 여러 배율을 시도한다.
    const std::vector<double> scales = {1.0, 0.85, 1.2, 0.7, 1.5, 0.5, 2.0};
    double bestScore = -1.0;
    cv::Rect bestRect;

    for (double scale : scales) {
        const int scaledWidth = (int)std::lround(templateBase.cols * scale);
        const int scaledHeight = (int)std::lround(templateBase.rows * scale);

        if (scaledWidth < 8 || scaledHeight < 8) {
            continue;
        }
        if (scaledWidth > frame.cols || scaledHeight > frame.rows) {
            continue;
        }

        cv::Mat templateScaled;
        if (scale == 1.0) {
            templateScaled = templateBase;
        } else {
            cv::resize(templateBase, templateScaled, cv::Size(scaledWidth, scaledHeight), 0, 0,
                       scale < 1.0 ? cv::INTER_AREA : cv::INTER_LINEAR);
        }

        cv::Mat result;
        cv::matchTemplate(frame, templateScaled, result, cv::TM_CCOEFF_NORMED);

        double minValue = 0;
        double maxValue = 0;
        cv::Point minLocation;
        cv::Point maxLocation;
        cv::minMaxLoc(result, &minValue, &maxValue, &minLocation, &maxLocation);

        if (maxValue > bestScore) {
            bestScore = maxValue;
            bestRect = cv::Rect(maxLocation.x, maxLocation.y, scaledWidth, scaledHeight);
        }
    }

    if (bestScore < 0) {
        return [[OpenCVBuffMatchResult alloc] initWithFound:NO score:0 regionInPixels:CGRectZero];
    }

    const double clampedScore = std::min(std::max(bestScore, 0.0), 1.0);
    const BOOL found = clampedScore >= threshold;
    // ROI 기준 위치를 전체 프레임 좌표로 변환한다.
    const CGRect region = CGRectMake(
        bestRect.x + roiRect.x,
        bestRect.y + roiRect.y,
        bestRect.width,
        bestRect.height);

    return [[OpenCVBuffMatchResult alloc] initWithFound:found
                                                  score:clampedScore
                                         regionInPixels:region];
}

@end
