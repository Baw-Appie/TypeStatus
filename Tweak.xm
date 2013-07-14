#import "Global.h"
#import <libstatusbar/LSStatusBarItem.h>
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <ChatKit/CKIMEntity.h>
#import <ChatKit/CKMadridEntity.h>
#import <ChatKit/CKMadridService.h>
#import <IMFoundation/FZMessage.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBUserAgent.h>
#import <UIKit/UIApplication+Private.h>
#import "HBTSStatusBarView.h"
#import "HBTSMessageServer.h"
#include <notify.h>

#pragma mark - Global stuff

BOOL firstLoad = YES;
BOOL overlaySlide = YES;
BOOL overlayFade = YES;
float overlayDuration = 5.f;
BOOL typingStatus = YES;
BOOL typingTimeout = NO;
BOOL readStatus = YES;

void HBTSLoadPrefs();
BOOL HBTSShouldHide(BOOL typing);

#define GET_BOOL(key, default) ([prefs objectForKey:key] ? [[prefs objectForKey:key] boolValue] : default)
#define GET_FLOAT(key, default) ([prefs objectForKey:key] ? [[prefs objectForKey:key] floatValue] : default)
#define kHBTSTypingTimeout 60

void HBTSShowOverlay() {
	if (IN_SPRINGBOARD) {
		return;
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSDictionary *data = [[CPDistributedMessagingCenter centerNamed:@"ws.hbang.typestatus.server"] sendMessageAndReceiveReplyName:@"GetState" userInfo:[NSDictionary dictionary]];

		dispatch_async(dispatch_get_main_queue(), ^{
			if ([data objectForKey:@"Reset"] && ((NSNumber *)[data objectForKey:@"Reset"]).boolValue) {
				HBTSSetStatusBar(HBTSStatusBarTypeTyping, nil, YES);
			} else {
				HBTSSetStatusBar((HBTSStatusBarType)((NSNumber *)[data objectForKey:@"Type"]).intValue, [data objectForKey:@"Name"], ((NSNumber *)[data objectForKey:@"Typing"]).boolValue);
			}
		});
	});
}

void HBTSSetStatusBar(HBTSStatusBarType type, NSString *name, BOOL typing) {
	overlayView.type = type;
	overlayView.string = name;

	if (name) {
		[overlayView showWithTimeout:typing && !typingTimeout ? kHBTSTypingTimeout : overlayDuration];
	} else {
		[overlayView hide];
	}

	if (IN_SPRINGBOARD) {
		currentType = type;
		currentName = [name retain];
		currentTyping = typing;

		notify_post("ws.hbang.typestatus/ShowOverlay");
	}
}

#pragma mark - SpringBoard specific stuff

%group HBTSSpringBoard
HBTSMessageServer *messageServer;
int typingIndicators = 0;
LSStatusBarItem *statusBarItem;

BOOL updatingClock = NO;
NSTimer *typingTimer;
BOOL isTyping = NO;
NSMutableDictionary *nameCache = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
	@"John Appleseed", @"example@hbang.ws",
	@"The Devil", @"imast777@imast777.me",
	nil];

BOOL typingHideInMessages = YES;
BOOL typingIcon = NO;
BOOL readHideInMessages = YES;

NSArray *messagesApps = [[NSArray alloc] initWithObjects:@"com.apple.MobileSMS", @"com.bitesms", nil];

#pragma mark - Hide while Messages is open

BOOL HBTSShouldHide(BOOL typing) {
	if (typing ? typingHideInMessages : readHideInMessages) {
		return [messagesApps containsObject:IN_SPRINGBOARD ? [[%c(SBUserAgent) sharedUserAgent] foregroundApplicationDisplayID] : [NSBundle mainBundle].bundleIdentifier];
	}

	return NO;
}

#pragma mark - Get contact name

NSString *HBTSNameForHandle(NSString *handle) {
	if ([nameCache objectForKey:handle]) {
		return [nameCache objectForKey:handle];
	} else {
		NSString *name = handle;

		if (%c(CKIMEntity)) {
			CKIMEntity *entity = [[%c(CKIMEntity) copyEntityForAddressString:handle] autorelease];
			name = [entity.name retain];
		} else if (%c(CKMadridService)) {
			CKMadridService *service = [[%c(CKMadridService) alloc] init];
			CKMadridEntity *entity = [[service copyEntityForAddressString:handle] autorelease];
			[service release];
			name = [entity.name retain];
		}

		[nameCache setObject:name forKey:handle];
		return name;
	}
}

#pragma mark - Show/hide functions

void HBTSTypingStarted(FZMessage *message, BOOL testing) {
	typingIndicators++;
	isTyping = YES;

	if (HBTSShouldHide(YES)) {
		return;
	}

	if (typingIcon) {
		if (!statusBarItem) {
			statusBarItem = [[%c(LSStatusBarItem) alloc] initWithIdentifier:@"ws.hbang.typestatus.icon" alignment:StatusBarAlignmentRight];
			statusBarItem.imageName = @"TypeStatus";
		}

		statusBarItem.visible = YES;

		if (typingTimer) {
			[typingTimer invalidate];
			[typingTimer release];
			typingTimer = nil;
		}

		if (typingTimeout || testing) {
			typingTimer = [[NSTimer scheduledTimerWithTimeInterval:testing ? overlayDuration : kHBTSTypingTimeout target:message selector:@selector(typeStatus_typingEnded) userInfo:nil repeats:NO] retain];
		}
	}

	if (typingStatus) {
		HBTSSetStatusBar(HBTSStatusBarTypeTyping, HBTSNameForHandle(message.handle), !testing);
	}
}

void HBTSTypingEnded() {
	typingIndicators--;

	if (typingIndicators <= 0) {
		typingIndicators = 0;
		isTyping = NO;
	}

	if (!isTyping) {
		if (statusBarItem) {
			statusBarItem.visible = NO;
		}

		if (typingTimer) {
			[typingTimer invalidate];
			[typingTimer release];
			typingTimer = nil;
		}

		if (typingStatus) {
			HBTSSetStatusBar(HBTSStatusBarTypeTyping, nil, NO);
		}
	}
}

void HBTSMessageRead(FZMessage *message) {
	if (readStatus && !message.sender && [[NSDate date] timeIntervalSinceDate:message.timeRead] < 1 && !HBTSShouldHide(NO)) {
		HBTSSetStatusBar(HBTSStatusBarTypeRead, HBTSNameForHandle(message.handle), NO);
	}
}

#pragma mark - Test functions

void HBTSTestTyping() {
	typingIndicators = 0;

	/*
	 We could have linked against IMFoundation, if not for it
	 being set up insanely on iOS 5:
	 IMCore.framework/Frameworks/IMFoundation.framework
	*/

	FZMessage *message = [[[%c(FZMessage) alloc] init] autorelease];
	message.handle = @"example@hbang.ws";

	HBTSTypingStarted(message, YES);
}

void HBTSTestRead() {
	FZMessage *message = [[[%c(FZMessage) alloc] init] autorelease];
	message.handle = @"example@hbang.ws";
	message.timeRead = [NSDate date];
}

#pragma mark - iMessage typing status receiver

%hook IMChatRegistry
- (void)account:(id)account chat:(id)chat style:(unsigned char)style chatProperties:(id)properties messageReceived:(FZMessage *)message {
	%orig;

	if (message.flags == 4096) {
		HBTSTypingStarted(message, NO);
	} else {
		HBTSTypingEnded();
	}
}
%end

#pragma mark - iMessage read receipt receiver

%hook FZMessage
- (void)setTimeRead:(NSDate *)timeRead {
	%orig;

	HBTSMessageRead(self);
}

%new - (void)typeStatus_typingEnded {
	HBTSTypingEnded();
}
%end
%end

#pragma mark - Preferences management

void HBTSLoadPrefs() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/ws.hbang.typestatus.plist"];

	if (IN_SPRINGBOARD) {
		typingHideInMessages = GET_BOOL(@"HideInMessages", YES);
		readHideInMessages = GET_BOOL(@"HideReadInMessages", YES);
		typingIcon = GET_BOOL(@"TypingIcon", NO);
		typingStatus = GET_BOOL(@"TypingStatus", YES);
		readStatus = GET_BOOL(@"ReadStatus", YES);
	}

	overlaySlide = GET_BOOL(@"OverlaySlide", YES);
	overlayFade = GET_BOOL(@"OverlayFade", NO);
	overlayDuration = GET_FLOAT(@"OverlayDuration", 5.f);
	typingTimeout = GET_BOOL(@"TypingTimeout", NO);

	if (firstLoad) {
		firstLoad = NO;
	} else {
		if ((IN_SPRINGBOARD && !typingIcon) || !typingStatus) {
			HBTSTypingEnded();
		} else if (!readStatus) {
			HBTSSetStatusBar(HBTSStatusBarTypeRead, nil, NO);
		}
	}

	if (overlayView) {
		overlayView.shouldSlide = overlaySlide;
		overlayView.shouldFade = overlayFade;
	}
}

%ctor {
	%init;

	prefsBundle = [[NSBundle bundleWithPath:@"/Library/PreferenceBundles/TypeStatus.bundle"] retain];

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBTSLoadPrefs, CFSTR("ws.hbang.typestatus/ReloadPrefs"), NULL, 0);

	if (IN_SPRINGBOARD) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBTSTestTyping, CFSTR("ws.hbang.typestatus/TestTyping"), NULL, 0);
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBTSTestRead, CFSTR("ws.hbang.typestatus/TestRead"), NULL, 0);

		%init(HBTSSpringBoard);
	}

#pragma mark - Status bar overlay management

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBTSShowOverlay, CFSTR("ws.hbang.typestatus/ShowOverlay"), NULL, 0);

	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
		UIStatusBarForegroundView *foregroundView = MSHookIvar<UIStatusBarForegroundView *>([UIApplication sharedApplication].statusBar, "_foregroundView");

		overlayView = [[HBTSStatusBarView alloc] initWithFrame:foregroundView.frame];
		[[UIApplication sharedApplication].statusBar addSubview:overlayView];

		HBTSLoadPrefs();

		if (IN_SPRINGBOARD) {
			messageServer = [[HBTSMessageServer alloc] init];
		}
	}];
}
