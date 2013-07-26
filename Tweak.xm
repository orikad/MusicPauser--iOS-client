#import <Foundation/Foundation.h>

@interface SBTelephonyManager : NSObject

+ (instancetype)sharedTelephonyManager;
- (BOOL)inCall;

@end

#define MSPLog(fmt, ...) NSLog((@"[MusicPauser %s:%d] " fmt), __FILE__, __LINE__, ##__VA_ARGS__)
// Just little-endian ascii "stop", "play" and "quer"
#define STOP_VAL (0x706f7473)
#define PLAY_VAL (0x79616c70)
#define QUERY_VAL (0x72657571)

@interface MSPMusicPauser : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (nonatomic, retain) NSNetService *selectedService;
@property (assign) BOOL hasStoppedMusic;

+ (instancetype)sharedMusicPauser;

@end

@implementation MSPMusicPauser

+ (instancetype)sharedMusicPauser
{
    static MSPMusicPauser *__sharedMusicPauser;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        __sharedMusicPauser = [[self alloc] init];
    });

    return __sharedMusicPauser;
}

//all of the networking code is done synchronously. Do not use those methods from the main thread. It will block.

//this method completely ignores reporting errors.
- (void)sendData:(uint8_t *)data length:(size_t)length
{
    NSOutputStream *outStream;
    BOOL result = [self.selectedService getInputStream:nil outputStream:&outStream];
    
    if (result)
    {
        [outStream open];
        [outStream write:data maxLength:length];
        [outStream close];
    }
}

- (BOOL)sendData:(uint8_t *)dataToSend length:(size_t)lengthToSend andReceiveData:(uint8_t *)dataToReceive length:(size_t)lengthToReceive
{
    NSInputStream *inStream;
    NSOutputStream *outStream;
    
    BOOL result = [self.selectedService getInputStream:&inStream outputStream:&outStream];
    
    if (!result) {
        return NO;
    }
    
    [inStream open];
    [outStream open];
    
    [outStream write:dataToSend maxLength:lengthToSend];
    
    NSInteger readLength = [inStream read:dataToReceive maxLength:lengthToReceive];
    
    if (readLength == -1) {
        [inStream close];
        [outStream close];
        return NO;
    }
    
    [inStream close];
    [outStream close];
    
    return YES;
}

// returns 1 if is playing, 0 otherwise. if an error occurred result is undefined (might be -1)
- (uint32_t)isPlaying
{
    uint32_t query = QUERY_VAL;
    uint32_t isPlaying;
    
    BOOL result = [self sendData:(uint8_t *)&query length:sizeof(query) andReceiveData:(uint8_t *)&isPlaying length:sizeof(isPlaying)];
    if (!result) {
        isPlaying = -1;
    }
    
    return isPlaying;
}

- (void)stopMusic
{
    uint32_t pause = STOP_VAL;
    [self sendData:(uint8_t *)&pause length:sizeof(pause)];
}

- (void)resumeMusic
{
    uint32_t play = PLAY_VAL;
    [self sendData:(uint8_t *)&play length:sizeof(play)];
}

- (void)changedCallStatus
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        uint32_t isPlaying = [self isPlaying];
        
        if ([[%c(SBTelephonyManager) sharedTelephonyManager] inCall] && isPlaying == 1) {
            
            [self stopMusic];
            self.hasStoppedMusic = YES;
            
        } else if (self.hasStoppedMusic) {
            
            [self resumeMusic];
            self.hasStoppedMusic = NO;
            
        }
    });
}

- (void)dealloc
{
    [_selectedService release];
    [super dealloc];
}

@end

static NSString *MSPDictionaryPath()
{
    return [@"~/Library/Preferences/com.orikad.musicpauser.plist" stringByExpandingTildeInPath];
}

static void MSPUpdateSetService()
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSDictionary *savedDictionary = [NSDictionary dictionaryWithContentsOfFile:MSPDictionaryPath()];
        
        if (savedDictionary) {
            
            NSNetService *savedNetService = [[NSNetService alloc] initWithDomain:savedDictionary[@"domain"] type:savedDictionary[@"type"] name:savedDictionary[@"name"]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [MSPMusicPauser sharedMusicPauser].selectedService = savedNetService;
                [savedNetService release];
            });
        }
    });
}


%ctor
{
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)MSPUpdateSetService, CFSTR("com.orikad.musicpauser"), NULL, 0);
    
    MSPUpdateSetService();

    [[NSNotificationCenter defaultCenter] addObserver:[MSPMusicPauser sharedMusicPauser] selector:@selector(changedCallStatus) name:@"kCTCallStatusChangeNotification" object:nil];

}
