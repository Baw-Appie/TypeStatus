#include <substrate.h>
#import "HBTSStatusBarView.h"
#import <Foundation/NSDistributedNotificationCenter.h>
#import <UIKit/UIApplication+Private.h>
#import <UIKit/UIImage+Private.h>
#import <UIKit/UIStatusBar.h>
#import <UIKit/UIStatusBarForegroundView.h>
#import <UIKit/UIStatusBarForegroundStyleAttributes.h>
#import <version.h>
#include <notify.h>

typedef NS_ENUM(NSUInteger, HBTSStatusBarAnimation) {
	HBTSStatusBarAnimationNone,
	HBTSStatusBarAnimationSlide,
	HBTSStatusBarAnimationFade
};

static CGFloat const kHBTSStatusBarFontSize = IS_IOS_OR_NEWER(iOS_7_0) ? 12.f : 14.f;
static NSTimeInterval const kHBTSStatusBarAnimationDuration = 0.25;

@implementation HBTSStatusBarView {
	UIView *_containerView;
	UILabel *_typeLabel;
	UILabel *_contactLabel;
	UIImageView *_iconImageView;

	BOOL _isAnimating;
	BOOL _isVisible;
	HBTSStatusBarType _type;
	HBTSStatusBarAnimation _animations;

	CGFloat _foregroundViewAlpha;
	CGFloat _statusBarHeight;

	NSTimer *_hideTimer;
}

#pragma mark - UIView

- (instancetype)initWithFrame:(CGRect)frame {
	frame.size.height = [UIStatusBar heightForStyle:UIStatusBarStyleDefault orientation:UIInterfaceOrientationPortrait];
	self = [super initWithFrame:frame];

	if (self) {
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.clipsToBounds = NO;
		self.hidden = YES;

		_foregroundViewAlpha = 0;
		_statusBarHeight = frame.size.height;

		_containerView = [[UIView alloc] initWithFrame:self.bounds];
		_containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[self addSubview:_containerView];

		_iconImageView = [[[UIImageView alloc] init] autorelease];
		_iconImageView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
		_iconImageView.center = CGPointMake(_iconImageView.center.x, self.frame.size.height / 2);
		[_containerView addSubview:_iconImageView];

		CGFloat top = 0;

		if (!IS_IOS_OR_NEWER(iOS_7_0)) {
			top = [UIScreen mainScreen].scale > 1 ? -0.5f : -1.f;
		}

		_typeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, top, 0, self.frame.size.height)];
		_typeLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		_typeLabel.font = [UIFont boldSystemFontOfSize:kHBTSStatusBarFontSize];
		_typeLabel.backgroundColor = [UIColor clearColor];
		_typeLabel.textColor = [UIColor whiteColor];
		[_containerView addSubview:_typeLabel];

		_contactLabel = [[UILabel alloc] initWithFrame:_typeLabel.frame];
		_contactLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		_contactLabel.font = [UIFont systemFontOfSize:kHBTSStatusBarFontSize];
		_contactLabel.backgroundColor = [UIColor clearColor];
		_contactLabel.textColor = [UIColor whiteColor];
		[_containerView addSubview:_contactLabel];

		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedStatusNotification:) name:HBTSClientSetStatusBarNotification object:nil];
	}

	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	[_iconImageView sizeToFit];

	CGRect typeFrame = _typeLabel.frame;
	typeFrame.origin.x = _iconImageView.frame.size.width + 4.f;
	typeFrame.size.width = [_typeLabel sizeThatFits:self.frame.size].width;
	_typeLabel.frame = typeFrame;

	CGRect labelFrame = _contactLabel.frame;
	labelFrame.origin.x = typeFrame.origin.x + typeFrame.size.width + 4.f;
	labelFrame.size.width = [_contactLabel sizeThatFits:self.frame.size].width;
	_contactLabel.frame = labelFrame;

	CGRect containerFrame = _containerView.frame;
	containerFrame.size.width = labelFrame.origin.x + labelFrame.size.width;
	_containerView.frame = containerFrame;

	_containerView.center = CGPointMake(self.frame.size.width / 2, _containerView.center.y);
}

#pragma mark - Adapting UI

- (void)_updateForCurrentStatusBarStyle {
	static UIImage *TypingImage;
	static UIImage *TypingImageWhite;
	static UIImage *ReadImage;
	static UIImage *ReadImageWhite;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSBundle *uikitBundle = [NSBundle bundleForClass:UIView.class];

		if (IS_IOS_OR_NEWER(iOS_7_0)) {
			TypingImage = [[[UIImage imageNamed:@"Black_TypeStatus" inBundle:uikitBundle] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] retain];
			ReadImage = [[[UIImage imageNamed:@"Black_TypeStatusRead" inBundle:uikitBundle] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] retain];
		} else {
			TypingImage = [[UIImage imageNamed:@"WhiteOnBlackEtch_TypeStatus" inBundle:uikitBundle] retain];
			ReadImage = [[UIImage imageNamed:@"WhiteOnBlackEtch_TypeStatusRead" inBundle:uikitBundle] retain];
		}

		if (IS_IOS_OR_OLDER(iOS_5_1) && !IS_IPAD) {
			TypingImageWhite = [[UIImage imageNamed:@"ColorOnGrayShadow_TypeStatus" inBundle:uikitBundle] retain];
			ReadImageWhite = [[UIImage imageNamed:@"ColorOnGrayShadow_TypeStatusRead" inBundle:uikitBundle] retain];
		}
	});

	UIColor *textColor;
	UIColor *shadowColor;
	CGSize shadowOffset;
	BOOL isWhite = NO;

	if (IS_IOS_OR_NEWER(iOS_7_0)) {
		UIStatusBarForegroundView *foregroundView = MSHookIvar<UIStatusBarForegroundView *>(self.superview, "_foregroundView");
		textColor = MSHookIvar<UIColor *>(foregroundView.foregroundStyle, "_tintColor");
	} else {
		if (!IS_IOS_OR_NEWER(iOS_6_0) && !IS_IPAD && [UIApplication sharedApplication].statusBarStyle == UIStatusBarStyleDefault) {
			textColor = [UIColor blackColor];
			shadowColor = [UIColor whiteColor];
			shadowOffset = CGSizeMake(0, 1.f);
			isWhite = YES;
		} else {
			textColor = [UIColor whiteColor];
			shadowColor = [UIColor colorWithWhite:0 alpha:0.5f];
			shadowOffset = CGSizeMake(0, -1.f);
		}
	}

	switch (_type) {
		case HBTSStatusBarTypeTyping:
			_iconImageView.image = isWhite && TypingImageWhite ? TypingImageWhite : TypingImage;
			break;

		case HBTSStatusBarTypeRead:
			_iconImageView.image = isWhite && ReadImageWhite ? ReadImageWhite : ReadImage;
			break;

		case HBTSStatusBarTypeTypingEnded:
			break;
	}

	_typeLabel.textColor = textColor;
	_contactLabel.textColor = textColor;

	if (IS_IOS_OR_NEWER(iOS_7_0)) {
		_iconImageView.tintColor = textColor;
	} else {
		_typeLabel.shadowColor = shadowColor;
		_contactLabel.shadowColor = shadowColor;

		_typeLabel.shadowOffset = shadowOffset;
		_contactLabel.shadowOffset = shadowOffset;
	}
}

#pragma mark - Show/hide

- (void)receivedStatusNotification:(NSNotification *)notification {
	if (!self.superview || ![self.superview isKindOfClass:UIStatusBar.class]) {
		return;
	}

	HBTSStatusBarType type = (HBTSStatusBarType)((NSNumber *)notification.userInfo[kHBTSMessageTypeKey]).intValue;
	BOOL typing = ((NSNumber *)notification.userInfo[kHBTSMessageIsTypingKey]).boolValue;
	BOOL typingTimeout = ((NSNumber *)notification.userInfo[kHBTSPreferencesTypingTimeoutKey]).boolValue;

	NSTimeInterval duration = kHBTSTypingTimeout;

	if (!typing || typingTimeout) {
		duration = ((NSNumber *)notification.userInfo[kHBTSPreferencesOverlayDurationKey]).doubleValue;
	}

	if ([[NSDate date] timeIntervalSinceDate:notification.userInfo[kHBTSMessageSendDateKey]] > duration) {
		return;
	}

	_animations = HBTSStatusBarAnimationNone;

	if (((NSNumber *)notification.userInfo[kHBTSPreferencesOverlayAnimationSlideKey]).boolValue) {
		_animations |= HBTSStatusBarAnimationSlide;
	}

	if (((NSNumber *)notification.userInfo[kHBTSPreferencesOverlayAnimationFadeKey]).boolValue) {
		_animations |= HBTSStatusBarAnimationFade;
	}

	if (type == HBTSStatusBarTypeTypingEnded) {
		[self hide];
	} else {
		_type = type;
		_contactLabel.text = notification.userInfo[kHBTSMessageSenderKey];

		[self showWithTimeout:duration];
	}
}

- (void)showWithTimeout:(NSTimeInterval)timeout {
	if ([UIApplication sharedApplication].statusBarHidden) {
		return;
	}

	static NSBundle *PrefsBundle;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		PrefsBundle = [[NSBundle bundleWithPath:@"/Library/PreferenceBundles/TypeStatus.bundle"] retain];
	});

	switch (_type) {
		case HBTSStatusBarTypeTyping:
			_typeLabel.text = [PrefsBundle localizedStringForKey:@"Typing:" value:@"Typing:" table:@"Root"];
			break;

		case HBTSStatusBarTypeRead:
			_typeLabel.text = [PrefsBundle localizedStringForKey:@"Read:" value:@"Read:" table:@"Root"];
			break;

		case HBTSStatusBarTypeTypingEnded:
			break;
	}

	[self _updateForCurrentStatusBarStyle];
	[self layoutSubviews];

	if (_isAnimating || _isVisible) {
		return;
	}

	if (_hideTimer) {
		[_hideTimer invalidate];
		[_hideTimer release];

		_hideTimer = [[NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(hide) userInfo:nil repeats:NO] retain];

		return;
	}

	if (IN_SPRINGBOARD) {
		notify_post("ws.hbang.typestatus/OverlayWillShow");

		if (UIAccessibilityIsVoiceOverRunning()) {
			UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, [NSString stringWithFormat:@"%@ %@", _typeLabel.text, _contactLabel.text]);
		}
	}

	UIStatusBarForegroundView *foregroundView = MSHookIvar<UIStatusBarForegroundView *>(self.superview, "_foregroundView");

	if (_foregroundViewAlpha == 0) {
		_foregroundViewAlpha = foregroundView.alpha;
	}

	_isAnimating = YES;
	_isVisible = YES;

	self.alpha = _foregroundViewAlpha;
	self.hidden = NO;
	self.frame = foregroundView.frame;

	void (^animationBlock)() = ^{
		if (_animations & HBTSStatusBarAnimationSlide) {
			CGRect frame = self.frame;
			frame.origin.y = 0;
			self.frame = frame;

			foregroundView.clipsToBounds = YES;

			CGRect foregroundFrame = foregroundView.frame;
			foregroundFrame.origin.y = _statusBarHeight;
			foregroundFrame.size.height = 0;
			foregroundView.frame = foregroundFrame;
		}

		self.alpha = _foregroundViewAlpha;

		if (_animations & HBTSStatusBarAnimationFade) {
			foregroundView.alpha = 0;
		}
	};

	void (^completionBlock)(BOOL finished) = ^(BOOL finished) {
		_isAnimating = NO;
		_hideTimer = [[NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(hide) userInfo:nil repeats:NO] retain];
	};

	if (_animations == HBTSStatusBarAnimationNone) {
		foregroundView.hidden = YES;
		self.hidden = NO;
		completionBlock(YES);
	} else {
		CGRect frame = foregroundView.frame;
		frame.origin.y = _animations & HBTSStatusBarAnimationSlide ? -_statusBarHeight : 0;
		self.frame = frame;

		if (_animations & HBTSStatusBarAnimationFade) {
			self.alpha = 0;
		}

		[UIView animateWithDuration:kHBTSStatusBarAnimationDuration animations:animationBlock completion:completionBlock];
	}
}

- (void)hide {
	if (!_hideTimer || _isAnimating || !_isVisible) {
		return;
	}

	_isAnimating = YES;

	[_hideTimer invalidate];
	[_hideTimer release];
	_hideTimer = nil;

	UIStatusBarForegroundView *foregroundView = MSHookIvar<UIStatusBarForegroundView *>(self.superview, "_foregroundView");

	void (^animationBlock)() = ^{
		if (_animations & HBTSStatusBarAnimationSlide) {
			CGRect frame = self.frame;
			frame.origin.y = -_statusBarHeight;
			self.frame = frame;
		}

		CGRect foregroundFrame = foregroundView.frame;
		foregroundFrame.origin.y = 0;
		foregroundFrame.size.height = _statusBarHeight;
		foregroundView.frame = foregroundFrame;

		self.alpha = 0;
		foregroundView.alpha = _foregroundViewAlpha;
	};

	void (^completionBlock)(BOOL finished) = ^(BOOL finished) {
		self.hidden = YES;
		self.frame = foregroundView.frame;
		self.alpha = _foregroundViewAlpha;

		foregroundView.clipsToBounds = NO;

		_typeLabel.text = @"";
		_contactLabel.text = @"";

		_isAnimating = NO;
		_isVisible = NO;

		if (IN_SPRINGBOARD) {
			notify_post("ws.hbang.typestatus/OverlayDidHide");
		}
	};

	if (_animations == HBTSStatusBarAnimationNone) {
		foregroundView.hidden = NO;
		completionBlock(YES);
	} else {
		[UIView animateWithDuration:kHBTSStatusBarAnimationDuration animations:animationBlock completion:completionBlock];
	}
}

#pragma mark - Memory management

- (void)dealloc {
	[_containerView release];
	[_typeLabel release];
	[_contactLabel release];
	[_iconImageView release];
	[_hideTimer release];

	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

@end
