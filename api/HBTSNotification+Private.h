#import "HBTSNotification.h"

static NSString *const kHBTSMessageSourceKey = @"Source";
static NSString *const kHBTSMessageContentKey = @"Content";
static NSString *const kHBTSMessageBoldRangeKey = @"BoldRange";
static NSString *const kHBTSMessageIconNameKey = @"IconName";
static NSString *const kHBTSMessageActionURLKey = @"ActionURL";

static NSString *const kHBTSMessageDirectionKey = @"Direction";
static NSString *const kHBTSMessageTimeoutKey = @"Duration";
static NSString *const kHBTSMessageSendDateKey = @"Date";

@interface HBTSNotification (Private)

+ (instancetype)hideNotification;

@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic) HBTSNotificationType notificationType;
@property (nonatomic) BOOL direction;

@end
