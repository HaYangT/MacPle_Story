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

// identifier → 스케일된 템플릿 Mat 묶음. 한 번만 만들고 재사용.
static std::unordered_map<std::string, std::vector<cv::Mat>> gScaledTemplateCache;
static std::mutex gCacheMutex;

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

static std::vector<cv::Mat> MacpleBuildScaledMats(const cv::Mat &base) {
    std::vector<cv::Mat> scaledMats;
    if (base.empty()) {
        return scaledMats;
    }

    for (double scale : kScaleCandidates) {
        const int scaledWidth = (int)std::lround(base.cols * scale);
        const int scaledHeight = (int)std::lround(base.rows * scale);

        if (scaledWidth < 8 || scaledHeight < 8) {
            continue;
        }

        if (scale == 1.0) {
            scaledMats.push_back(base);
        } else {
            cv::Mat scaled;
            cv::resize(base, scaled, cv::Size(scaledWidth, scaledHeight), 0, 0,
                       scale < 1.0 ? cv::INTER_AREA : cv::INTER_LINEAR);
            scaledMats.push_back(scaled);
        }
    }

    return scaledMats;
}

// identifier로 캐시된 스케일 Mat을 가져온다(없으면 image로 만들어 캐시).
static std::vector<cv::Mat> MacpleScaledMatsForTemplate(OpenCVBuffTemplate *templateItem) {
    const std::string key = templateItem.identifier.UTF8String ?: "";

    {
        std::lock_guard<std::mutex> lock(gCacheMutex);
        auto it = gScaledTemplateCache.find(key);
        if (it != gScaledTemplateCache.end()) {
            return it->second;
        }
    }

    cv::Mat base = MacpleBGRMatFromCGImage(templateItem.image);
    std::vector<cv::Mat> scaledMats = MacpleBuildScaledMats(base);

    if (!key.empty()) {
        std::lock_guard<std::mutex> lock(gCacheMutex);
        gScaledTemplateCache[key] = scaledMats;
    }

    return scaledMats;
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

    // 정규화 검색 영역 → 픽셀 ROI(좌상단 원점), 경계 클램프. ROI도 한 번만 자른다.
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

    double bestScore = -1.0;
    cv::Rect bestRect;
    NSString *bestId = nil;

    for (OpenCVBuffTemplate *templateItem in templates) {
        const std::vector<cv::Mat> scaledMats = MacpleScaledMatsForTemplate(templateItem);

        for (const cv::Mat &scaled : scaledMats) {
            if (scaled.cols > frame.cols || scaled.rows > frame.rows) {
                continue;
            }

            cv::Mat result;
            cv::matchTemplate(frame, scaled, result, cv::TM_CCOEFF_NORMED);

            double minValue = 0;
            double maxValue = 0;
            cv::Point minLocation;
            cv::Point maxLocation;
            cv::minMaxLoc(result, &minValue, &maxValue, &minLocation, &maxLocation);

            if (maxValue > bestScore) {
                bestScore = maxValue;
                bestRect = cv::Rect(maxLocation.x, maxLocation.y, scaled.cols, scaled.rows);
                bestId = templateItem.identifier;
            }
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
