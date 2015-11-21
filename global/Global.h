typedef NS_ENUM(NSUInteger, HBTSStatusBarType) {
	HBTSStatusBarTypeTyping,
	HBTSStatusBarTypeTypingEnded,
	HBTSStatusBarTypeRead
};

typedef NS_ENUM(NSUInteger, HBTSNotificationType) {
	HBTSNotificationTypeNone,
	HBTSNotificationTypeOverlay,
	HBTSNotificationTypeIcon
};

typedef NS_ENUM(NSUInteger, HBTSStatusBarAnimation) {
	HBTSStatusBarAnimationSlide,
	HBTSStatusBarAnimationFade
};

static NSTimeInterval const kHBTSTypingTimeout = 60.0;


// old values may be used here for compatibility with other tweaks that listen
// for typestatus notifications

static NSString *const HBTSClientSetStatusBarNotification = @"HBTSClientSetStatusBar";
static NSString *const HBTSSpringBoardReceivedMessageNotification = @"HBTSSpringBoardReceivedMessageNotification";

static NSString *const kHBTSMessageTypeKey = @"Type";
static NSString *const kHBTSMessageSenderKey = @"Name";
static NSString *const kHBTSMessageIsTypingKey = @"IsTyping";

static NSString *const kHBTSMessageIconNameKey = @"IconName";
static NSString *const kHBTSMessageTitleKey = @"Title";
static NSString *const kHBTSMessageContentKey = @"Content";
static NSString *const kHBTSMessageDirectionKey = @"Direction";

static NSString *const kHBTSMessageTimeoutKey = @"Duration";
static NSString *const kHBTSMessageSendDateKey = @"Date";

// keys for xpc

static NSString *const kHBTSStatusBarMachServiceName = @"ws.hbang.typestatus.statusbar-communication";
static NSString *const kHBTSIMAgentMachServiceName = @"ws.hbang.typestatus.imagent-communication";