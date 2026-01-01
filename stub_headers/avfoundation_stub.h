// Standalone Stub header for FFI generation
// No system imports to avoid conflicts and ensure generation.

// Basic Types
typedef signed long long int64_t;
typedef int int32_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef long NSInteger;
typedef unsigned long NSUInteger;

// CoreGraphics Stubs
typedef double CGFloat;

typedef struct {
  CGFloat width;
  CGFloat height;
} CGSize;

typedef struct {
  CGFloat a, b, c, d;
  CGFloat tx, ty;
} CGAffineTransform;

// CoreMedia Stubs
typedef int32_t CMTimeScale;
typedef int64_t CMTimeValue;
typedef struct {
  CMTimeValue value;
  CMTimeScale timescale;
  uint32_t flags;
  int64_t epoch;
} CMTime;

typedef struct {
  CMTime start;
  CMTime duration;
} CMTimeRange;

// Function declarations (might require dynamic linking to resolve if used, but
// headers are for types mostly)

// Foundation Classes Stubs
@interface NSObject
+ (instancetype)alloc;
- (instancetype)init;
@end

@interface NSString : NSObject
@end

@interface NSArray<ObjectType> : NSObject
- (ObjectType)objectAtIndex:(NSUInteger)index;
@property(readonly) NSUInteger count;
+ (instancetype)array;
- (void)addObject:(ObjectType)anObject;
@end

@interface NSMutableArray<ObjectType> : NSArray <ObjectType>
@end

@interface NSDictionary<KeyType, ObjectType> : NSObject
+ (instancetype)dictionary;
@end

@interface NSURL : NSObject
+ (instancetype)fileURLWithPath:(NSString *)path;
@end

@interface NSError : NSObject
@end

// AVFoundation Enums
typedef enum {
  AVAssetExportSessionStatusUnknown = 0,
  AVAssetExportSessionStatusWaiting = 1,
  AVAssetExportSessionStatusExporting = 2,
  AVAssetExportSessionStatusCompleted = 3,
  AVAssetExportSessionStatusFailed = 4,
  AVAssetExportSessionStatusCancelled = 5
} AVAssetExportSessionStatus;

// AVFoundation String Constants
extern NSString *const AVAssetExportPresetLowQuality;
extern NSString *const AVAssetExportPresetMediumQuality;
extern NSString *const AVAssetExportPresetHighestQuality;

// AVFoundation Classes

@interface AVAssetTrack : NSObject
@property(readonly) CGSize naturalSize;
@property(readonly) CGAffineTransform preferredTransform;
@property(readonly) float nominalFrameRate;
@end

@interface AVAsset : NSObject
- (NSArray<AVAssetTrack *> *)tracksWithMediaType:(NSString *)mediaType;
@end

@interface AVURLAsset : AVAsset
+ (instancetype)URLAssetWithURL:(NSURL *)URL
                        options:(NSDictionary<NSString *, id> *)options;
@end

@interface AVVideoCompositionInstruction : NSObject
@end

@interface AVMutableVideoCompositionInstruction : AVVideoCompositionInstruction
@property CMTimeRange timeRange;
@property(copy) NSArray *layerInstructions;
+ (instancetype)videoCompositionInstruction;
@end

@interface AVVideoCompositionLayerInstruction : NSObject
@end

@interface AVMutableVideoCompositionLayerInstruction
    : AVVideoCompositionLayerInstruction
+ (instancetype)videoCompositionLayerInstructionWithAssetTrack:
    (AVAssetTrack *)track;
- (void)setTransform:(CGAffineTransform)transform atTime:(CMTime)time;
@end

@interface AVVideoComposition : NSObject
@end

@interface AVMutableVideoComposition : AVVideoComposition
@property(copy) NSArray<AVVideoCompositionInstruction *> *instructions;
@property(retain) Class customVideoCompositorClass;
@property CMTime frameDuration;
@property CGSize renderSize;
@property float renderScale;
+ (instancetype)videoComposition;
@end

@interface AVAudioMix : NSObject
@end

@interface AVMutableAudioMix : AVAudioMix
@property(copy) NSArray *inputParameters;
+ (instancetype)audioMix;
@end

@interface AVAudioMixInputParameters : NSObject
@end

@interface AVMutableAudioMixInputParameters : AVAudioMixInputParameters
@property(retain) AVAssetTrack *track;
+ (instancetype)audioMixInputParametersWithTrack:(AVAssetTrack *)track;
- (void)setVolume:(float)volume atTime:(CMTime)time;
@end

@interface AVAssetExportSession : NSObject
+ (instancetype)exportSessionWithAsset:(AVAsset *)asset
                            presetName:(NSString *)presetName;
@property(nonatomic, copy) NSURL *outputURL;
@property(nonatomic, copy) NSString *outputFileType;
@property(copy) AVVideoComposition *videoComposition;
@property(copy) AVAudioMix *audioMix;
- (void)exportAsynchronouslyWithCompletionHandler:(void *)handler;
@property(readonly) AVAssetExportSessionStatus status;
@property(readonly) NSError *error;
@property(nonatomic) CMTimeRange timeRange;
@end
