//
//  OpenCVBuffMatcher.mm
//  MacpleStory
//
//  OpenCV(cv::matchTemplate) 기반 템플릿 매칭 구현.
//  - 프레임은 호출당 한 번만 cv::Mat으로 변환(ROI도 한 번).
//  - 템플릿의 스케일된 Mat은 identifier로 캐시해 재사용.
//

#import "OpenCVBuffMatcher.h"

#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>

#import <cmath>
#import <mutex>
#import <string>
#import <unordered_map>
#import <vector>

@implementation OpenCVBuffMatchResult

- (instancetype)initWithFound:(BOOL)found
                        score:(double)score
                regionInPixels:(CGRect)regionInPixels
             matchedTemplateId:(NSString *)matchedTemplateId {
    self = [super init];
    if (self) {
        _found = found;
        _score = score;
        _regionInPixels = regionInPixels;
        _matchedTemplateId = matchedTemplateId;
    }
    return self;
}

@end

@implementation OpenCVBuffTemplate

- (instancetype)initWithIdentifier:(NSString *)identifier image:(CGImageRef)image {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _image = (CGImageRef)CGImageRetain(image);
    }
    return self;
}

- (void)dealloc {
    if (_image) {
        CGImageRelease(_image);
    }
}

@end

static const std::vector<double> kScaleCandidates = {1.0, 0.85, 1.2, 0.7, 1.5, 0.5, 2.0};
static const double kOpaqueTemplateInsetRatio = 0.12;

// identifier → 스케일된 템플릿 Mat 묶음. 한 번만 만들고 재사용.
struct MacpleScaledTemplate {
    cv::Mat image;
    cv::Mat mask;
};

struct MacpleTemplateBase {
    cv::Mat image;
    cv::Mat mask;
};

static std::unordered_map<std::string, std::vector<MacpleScaledTemplate>> gScaledTemplateCache;
static std::mutex gCacheMutex;

static cv::Mat MacpleRGBAMatFromCGImage(CGImageRef image) {
    const size_t width = CGImageGetWidth(image);
    const size_t height = CGImageGetHeight(image);

    if (width == 0 || height == 0) {
        return cv::Mat();
    }

    cv::Mat rgba((int)height, (int)width, CV_8UC4, cv::Scalar(0, 0, 0, 0));
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

    return rgba;
}

static cv::Mat MacpleBGRMatFromCGImage(CGImageRef image) {
    cv::Mat rgba = MacpleRGBAMatFromCGImage(image);
    if (rgba.empty()) {
        return cv::Mat();
    }

    cv::Mat bgr;
    cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);
    return bgr;
}

static cv::Rect MacpleInsetRect(const cv::Rect &rect, double ratio) {
    const int insetX = (int)std::floor(rect.width * ratio);
    const int insetY = (int)std::floor(rect.height * ratio);
    if (rect.width - (insetX * 2) < 8 || rect.height - (insetY * 2) < 8) {
        return rect;
    }

    return cv::Rect(rect.x + insetX, rect.y + insetY, rect.width - (insetX * 2), rect.height - (insetY * 2));
}

static MacpleTemplateBase MacpleTemplateBaseFromCGImage(CGImageRef image) {
    cv::Mat rgba = MacpleRGBAMatFromCGImage(image);
    if (rgba.empty()) {
        return MacpleTemplateBase();
    }

    std::vector<cv::Mat> channels;
    cv::split(rgba, channels);

    cv::Mat bgr;
    cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);

    cv::Mat mask;
    cv::threshold(channels[3], mask, 8, 255, cv::THRESH_BINARY);

    cv::Rect contentRect(0, 0, bgr.cols, bgr.rows);
    std::vector<cv::Point> nonZeroPoints;
    cv::findNonZero(mask, nonZeroPoints);
    if (!nonZeroPoints.empty()) {
        contentRect = cv::boundingRect(nonZeroPoints);
    } else {
        mask = cv::Mat(bgr.rows, bgr.cols, CV_8UC1, cv::Scalar(255));
    }

    const double opaqueCoverage = (double)cv::countNonZero(mask) / (double)std::max(1, mask.rows * mask.cols);
    if (opaqueCoverage > 0.9) {
        contentRect = MacpleInsetRect(contentRect, kOpaqueTemplateInsetRatio);
    }

    MacpleTemplateBase base;
    base.image = bgr(contentRect).clone();
    base.mask = mask(contentRect).clone();
    return base;
}

static std::vector<MacpleScaledTemplate> MacpleBuildScaledTemplates(const MacpleTemplateBase &base) {
    std::vector<MacpleScaledTemplate> scaledTemplates;
    if (base.image.empty() || base.mask.empty()) {
        return scaledTemplates;
    }

    if (cv::countNonZero(base.mask) == 0) {
        return scaledTemplates;
    }

    const bool hasPartialMask = cv::countNonZero(base.mask) < base.mask.rows * base.mask.cols;

    // 마스크가 전부 불투명한 템플릿은 OpenCV의 무마스크 경로가 더 빠르고 안정적이다.
    cv::Mat baseMask = hasPartialMask ? base.mask : cv::Mat();

    if (!baseMask.empty()) {
        cv::threshold(baseMask, baseMask, 8, 255, cv::THRESH_BINARY);
    }

    for (double scale : kScaleCandidates) {
        const int scaledWidth = (int)std::lround(base.image.cols * scale);
        const int scaledHeight = (int)std::lround(base.image.rows * scale);

        if (scaledWidth < 8 || scaledHeight < 8) {
            continue;
        }

        MacpleScaledTemplate scaledTemplate;
        if (scale == 1.0) {
            scaledTemplate.image = base.image;
            scaledTemplate.mask = baseMask;
        } else {
            cv::resize(base.image, scaledTemplate.image, cv::Size(scaledWidth, scaledHeight), 0, 0,
                       scale < 1.0 ? cv::INTER_AREA : cv::INTER_LINEAR);

            if (!baseMask.empty()) {
                cv::resize(baseMask, scaledTemplate.mask, cv::Size(scaledWidth, scaledHeight), 0, 0, cv::INTER_NEAREST);
                cv::threshold(scaledTemplate.mask, scaledTemplate.mask, 8, 255, cv::THRESH_BINARY);
            }
        }

        scaledTemplates.push_back(scaledTemplate);
    }

    return scaledTemplates;
}

// identifier로 캐시된 스케일 Mat을 가져온다(없으면 image로 만들어 캐시).
static std::vector<MacpleScaledTemplate> MacpleScaledTemplatesForTemplate(OpenCVBuffTemplate *templateItem) {
    const std::string key = templateItem.identifier.UTF8String ?: "";

    {
        std::lock_guard<std::mutex> lock(gCacheMutex);
        auto it = gScaledTemplateCache.find(key);
        if (it != gScaledTemplateCache.end()) {
            return it->second;
        }
    }

    MacpleTemplateBase base = MacpleTemplateBaseFromCGImage(templateItem.image);
    std::vector<MacpleScaledTemplate> scaledTemplates = MacpleBuildScaledTemplates(base);

    if (!key.empty()) {
        std::lock_guard<std::mutex> lock(gCacheMutex);
        gScaledTemplateCache[key] = scaledTemplates;
    }

    return scaledTemplates;
}

static cv::Rect MacpleROIFromNormalizedRegion(CGRect normalizedSearchRegion, int frameWidth, int frameHeight) {
    int roiX = (int)std::lround(normalizedSearchRegion.origin.x * frameWidth);
    int roiY = (int)std::lround(normalizedSearchRegion.origin.y * frameHeight);
    int roiW = (int)std::lround(normalizedSearchRegion.size.width * frameWidth);
    int roiH = (int)std::lround(normalizedSearchRegion.size.height * frameHeight);
    roiX = std::min(std::max(roiX, 0), frameWidth - 1);
    roiY = std::min(std::max(roiY, 0), frameHeight - 1);
    roiW = std::min(std::max(roiW, 1), frameWidth - roiX);
    roiH = std::min(std::max(roiH, 1), frameHeight - roiY);

    return cv::Rect(roiX, roiY, roiW, roiH);
}

static void MacpleMatchScaledTemplate(const cv::Mat &frame,
                                      const MacpleScaledTemplate &scaled,
                                      double *bestScore,
                                      cv::Rect *bestRect,
                                      NSString **bestId,
                                      NSString *templateId) {
    if (scaled.image.empty() || scaled.image.cols > frame.cols || scaled.image.rows > frame.rows) {
        return;
    }

    cv::Mat result;
    double candidateScore = 0;
    cv::Point candidateLocation;

    if (scaled.mask.empty()) {
        // 불투명 템플릿: 평균을 빼는 CCOEFF_NORMED(높을수록 좋음).
        cv::matchTemplate(frame, scaled.image, result, cv::TM_CCOEFF_NORMED);

        double minValue = 0;
        double maxValue = 0;
        cv::Point minLocation;
        cv::Point maxLocation;
        cv::minMaxLoc(result, &minValue, &maxValue, &minLocation, &maxLocation);

        if (!std::isfinite(maxValue)) {
            return;
        }
        candidateScore = maxValue;
        candidateLocation = maxLocation;
    } else {
        // 마스크 템플릿: SQDIFF_NORMED(차이 최소가 최적). CCORR_NORMED는 평평한 배경에
        // 높은 점수를 줘 가짜 매칭을 만들므로 차이 기반으로 바꾼다. 점수 = 1 - 차이.
        cv::matchTemplate(frame, scaled.image, result, cv::TM_SQDIFF_NORMED, scaled.mask);

        double minValue = 0;
        cv::Point minLocation;
        cv::minMaxLoc(result, &minValue, nullptr, &minLocation, nullptr);

        if (!std::isfinite(minValue)) {
            return;
        }
        candidateScore = 1.0 - minValue;
        candidateLocation = minLocation;
    }

    if (candidateScore > *bestScore) {
        *bestScore = candidateScore;
        *bestRect = cv::Rect(candidateLocation.x, candidateLocation.y, scaled.image.cols, scaled.image.rows);
        *bestId = templateId;
    }
}

@implementation OpenCVBuffMatcher

+ (OpenCVBuffMatchResult *)matchTemplates:(NSArray<OpenCVBuffTemplate *> *)templates
                                  inFrame:(CGImageRef)frameImage
                             searchRegion:(CGRect)normalizedSearchRegion
                                threshold:(double)threshold {
    OpenCVBuffMatchResult *empty = [[OpenCVBuffMatchResult alloc] initWithFound:NO
                                                                          score:0
                                                                 regionInPixels:CGRectZero
                                                              matchedTemplateId:nil];

    if (templates.count == 0) {
        return empty;
    }

    // 프레임은 호출당 한 번만 변환.
    cv::Mat fullFrame = MacpleBGRMatFromCGImage(frameImage);
    if (fullFrame.empty()) {
        return empty;
    }

    const cv::Rect roiRect = MacpleROIFromNormalizedRegion(normalizedSearchRegion, fullFrame.cols, fullFrame.rows);
    cv::Mat frame = fullFrame(roiRect);

    double bestScore = -1.0;
    cv::Rect bestRect;
    NSString *bestId = nil;

    for (OpenCVBuffTemplate *templateItem in templates) {
        const std::vector<MacpleScaledTemplate> scaledTemplates = MacpleScaledTemplatesForTemplate(templateItem);

        for (const MacpleScaledTemplate &scaled : scaledTemplates) {
            MacpleMatchScaledTemplate(frame, scaled, &bestScore, &bestRect, &bestId, templateItem.identifier);
        }
    }

    if (bestScore < 0) {
        return empty;
    }

    const double clampedScore = std::min(std::max(bestScore, 0.0), 1.0);
    const BOOL found = clampedScore >= threshold;
    const CGRect region = CGRectMake(
        bestRect.x + roiRect.x,
        bestRect.y + roiRect.y,
        bestRect.width,
        bestRect.height);

    return [[OpenCVBuffMatchResult alloc] initWithFound:found
                                                  score:clampedScore
                                         regionInPixels:region
                                      matchedTemplateId:bestId];
}

@end
