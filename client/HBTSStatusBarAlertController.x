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

- (void)_typeStatus_changeToDirection:(BOOL)direction animated:(BOOL)animated;

@end

@implementation HBTSStatusBarAlertController {
	NSMutableArray *_statusBars;

	BOOL _visible;
	NSString *_currentIconName;
	NSString *_currentText;
	NSRange _currentBoldRange;

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
	if (content) {
		[self showWithIconName:iconName text:[NSString stringWithFormat:@"%@ %@", title, content] boldRange:NSMakeRange(0, title.length)];
	} else {
		[self showWithIconName:iconName text:title boldRange:NSMakeRange(0, title.length)];
	}
}

- (void)showWithIconName:(NSString *)iconName text:(NSString *)text boldRange:(NSRange)boldRange {
	NSTimeInterval timeout = [HBTSPreferences sharedInstance].overlayDisplayDuration;
	[self _showWithIconName:iconName text:text boldRange:boldRange animatingInDirection:YES timeout:timeout];
}

- (void)hide {
	[self _showWithIconName:nil text:nil boldRange:NSMakeRange(0, 0) animatingInDirection:NO timeout:5];
}

- (void)_showWithIconName:(NSString *)iconName text:(NSString *)text boldRange:(NSRange)boldRange animatingInDirection:(BOOL)direction timeout:(NSTimeInterval)timeout {
	[self _setLockScreenGrabberVisible:!direction];
	[self _announceAlertWithText:text];

	[_currentIconName release];
	[_currentText release];

	_currentIconName = [iconName copy];
	_currentText = [text copy];
	_currentBoldRange = boldRange;

	_visible = direction;

	for (UIStatusBar *statusBar in _statusBars) {
		[self displayCurrentAlertInStatusBar:statusBar animated:YES];
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

- (void)displayCurrentAlertInStatusBar:(UIStatusBar *)statusBar animated:(BOOL)animated {
	// if for some crazy reason we don’t have a foreground view, log that (it
	// really shouldn’t happen…) and return
	if (!statusBar._typeStatus_foregroundView) {
		HBLogWarn(@"found a status bar without a foreground view! %@", statusBar);
		return;
	}

	// animate that status bar!
	[statusBar _typeStatus_changeToDirection:_visible animated:animated];

	// if we’re animating to visible, set the new values
	if (_visible) {
		[statusBar._typeStatus_foregroundView setIconName:_currentIconName text:_currentText boldRange:_currentBoldRange];
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
	NSString *content = notification.userInfo[kHBTSMessageContentKey];
	BOOL direction = ((NSNumber *)notification.userInfo[kHBTSMessageDirectionKey]).boolValue;

	// deserialize the bold range array to NSRange
	NSArray *boldRangeArray = notification.userInfo[kHBTSMessageBoldRangeKey];
	NSRange boldRange = NSMakeRange(((NSNumber *)boldRangeArray[0]).unsignedIntegerValue, ((NSNumber *)boldRangeArray[1]).unsignedIntegerValue);

	// show it! (or hide it)
	[self _showWithIconName:iconName text:content boldRange:boldRange animatingInDirection:direction timeout:timeout];
}

#pragma mark - Lock Screen Grabber

- (void)_setLockScreenGrabberVisible:(BOOL)state {
	// we must be in springboard
	if (!IN_SPRINGBOARD) {
		return;
	}

	SBLockScreenManager *lockScreenManager = [%c(SBLockScreenManager) sharedInstance];

	// if the device isn’t at the lock screen, do nothing
	if (!lockScreenManager.isUILocked) {
		return;
	}

	// grab the top grabber
	SBLockScreenView *lockScreenView = (SBLockScreenView *)lockScreenManager.lockScreenViewController.view;
	SBChevronView *topGrabberView = lockScreenView.topGrabberView;

	if (state && !_topGrabberWasHidden) {
		// if visible, and it wasn’t hidden before
		topGrabberView.alpha = 1;
	} else if (!state) {
		// if hidden, store the state it was in before
		_topGrabberWasHidden = topGrabberView.alpha == 0;
		topGrabberView.alpha = 0;
	}
}

#pragma mark - Accessibility

- (void)_announceAlertWithText:(NSString *)text {
	// we must be in springboard, and we must have voiceover enabled
	if (IN_SPRINGBOARD && UIAccessibilityIsVoiceOverRunning()) {
		// post an announcement notification that voiceover will say
		UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
	}
}

#pragma mark - Memory management

- (void)dealloc {
	[_statusBars release];
	[_currentIconName release];
	[_currentText release];
	[_timeoutTimer release];

	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:HBTSClientSetStatusBarNotification object:nil];

	[super dealloc];
}

@end
