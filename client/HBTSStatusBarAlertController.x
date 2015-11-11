#import "HBTSStatusBarAlertController.h"
#import "HBTSStatusBarForegroundView.h"
#import "HBTSPreferences.h"
#import <Foundation/NSDistributedNotificationCenter.h>
#import <SpringBoard/SBChevronView.h>
#import <SpringBoard/SBLockScreenManager.h>
#import <SpringBoard/SBLockScreenViewController.h>
#import <SpringBoard/SBLockScreenView.h>
#import <UIKit/UIStatusBar.h>

@interface UIStatusBar ()

@property (nonatomic, retain) HBTSStatusBarForegroundView *_typeStatus_foregroundView;

- (void)_typeStatus_animateInDirection:(BOOL)direction;

@end

@implementation HBTSStatusBarAlertController {
	NSMutableArray *_statusBars;

	BOOL _topGrabberWasHidden;
	NSTimer *_timeoutTimer;
}

+ (instancetype)sharedInstance {
	static HBTSStatusBarAlertController *sharedInstance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});

	return sharedInstance;
}

#pragma mark - Instance

- (instancetype)init {
	self = [super init];

	if (self) {
		_statusBars = [[NSMutableArray alloc] init];

		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_receivedStatusNotification:) name:HBTSClientSetStatusBarNotification object:nil];
	}

	return self;
}

#pragma mark - Status Bar Management

- (void)addStatusBar:(UIStatusBar *)statusBar {
	if ([_statusBars containsObject:statusBar]) {
		HBLogWarn(@"attempting to add a status bar that’s already known");
	}

	[_statusBars addObject:statusBar];
}

- (void)removeStatusBar:(UIStatusBar *)statusBar {
	[_statusBars removeObject:statusBar];
}

#pragma mark - Show/Hide

- (void)showWithIconName:(NSString *)iconName title:(NSString *)title content:(NSString *)content {
	NSTimeInterval timeout = [HBTSPreferences sharedInstance].overlayDisplayDuration;
	[self _showWithIconName:iconName title:title content:content animatingInDirection:YES timeout:timeout];
}

- (void)hide {
	[self _showWithIconName:nil title:nil content:nil animatingInDirection:NO timeout:5];
}

- (void)_showWithIconName:(NSString *)iconName title:(NSString *)title content:(NSString *)content animatingInDirection:(BOOL)direction timeout:(NSTimeInterval)timeout {
	[self _setLockScreenGrabberVisible:!direction];
	[self _announceAlertWithTitle:title content:content];

	for (UIStatusBar *statusBar in _statusBars) {
		if (!statusBar._typeStatus_foregroundView) {
			HBLogWarn(@"found a status bar without a foreground view! %@", statusBar);
			continue;
		}

		[statusBar _typeStatus_animateInDirection:direction];
		[statusBar._typeStatus_foregroundView setIconName:iconName title:title content:content];
	}

	if (direction) {
		if (_timeoutTimer) {
			[_timeoutTimer invalidate];
			[_timeoutTimer release];
			_timeoutTimer = nil;
		}

		_timeoutTimer = [[NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(hide) userInfo:nil repeats:NO] retain];
	} else {
		[_timeoutTimer invalidate];
		[_timeoutTimer release];
		_timeoutTimer = nil;
	}
}

#pragma mark - Notification

- (void)_receivedStatusNotification:(NSNotification *)notification {
	NSTimeInterval timeout = ((NSNumber *)notification.userInfo[kHBTSMessageTimeoutKey]).doubleValue;

	// when apps are paused in the background, notifications get queued up and
	// delivered when they resume. to work around this, we determine if it’s
	// been longer than the specified duration; if so, disregard the alert
	if ([[NSDate date] timeIntervalSinceDate:notification.userInfo[kHBTSMessageSendDateKey]] > timeout) {
		return;
	}

	// grab all the data
	NSString *iconName = notification.userInfo[kHBTSMessageIconNameKey];
	NSString *title = notification.userInfo[kHBTSMessageTitleKey];
	NSString *content = notification.userInfo[kHBTSMessageContentKey];
	BOOL direction = ((NSNumber *)notification.userInfo[kHBTSMessageDirectionKey]).boolValue;

	// show it! (or hide it)
	[self _showWithIconName:iconName title:title content:content animatingInDirection:direction timeout:timeout];
}

#pragma mark - Lock Screen Grabber

- (void)_setLockScreenGrabberVisible:(BOOL)state {
	if (!IN_SPRINGBOARD) {
		return;
	}

	SBLockScreenManager *lockScreenManager = [%c(SBLockScreenManager) sharedInstance];

	if (!lockScreenManager.isUILocked) {
		return;
	}

	SBLockScreenView *lockScreenView = (SBLockScreenView *)lockScreenManager.lockScreenViewController.view;
	SBChevronView *topGrabberView = lockScreenView.topGrabberView;

	if (state && !_topGrabberWasHidden) {
		topGrabberView.alpha = 1;
	} else if (!state) {
		_topGrabberWasHidden = topGrabberView.alpha == 0;
		topGrabberView.alpha = 0;
	}
}

#pragma mark - Accessibility

- (void)_announceAlertWithTitle:(NSString *)title content:(NSString *)content {
	// we must be in springboard, we must have voiceover enabled, and we must at
	// least have a title
	if (IN_SPRINGBOARD && UIAccessibilityIsVoiceOverRunning() && title) {
		// post an announcement notification that voiceover will say
		UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, [NSString stringWithFormat:@"%@ %@", title, content ?: @""]);
	}
}

#pragma mark - Memory management

- (void)dealloc {
	[_statusBars release];
	[_timeoutTimer release];

	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:HBTSClientSetStatusBarNotification object:nil];

	[super dealloc];
}

@end
