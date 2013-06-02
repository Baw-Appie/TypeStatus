#include <substrate.h> // ?!!?
#import "HBTSStatusBarView.h"
#import <UIKit/UIApplication+Private.h>
#import <UIKit/UIImage+Private.h>
#import <UIKit/UIStatusBar.h>

#define kHBTSStatusBarHeight 20.f

@implementation HBTSStatusBarView
@synthesize shouldSlide = _shouldSlide, shouldFade = _shouldFade;

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];

	if (self) {
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.clipsToBounds = NO;
		self.hidden = YES;

		_containerView = [[UIView alloc] initWithFrame:self.frame];
		_containerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[self addSubview:_containerView];

		UIImageView *iconImageView = [[[UIImageView alloc] initWithImage:[UIImage kitImageNamed:@"WhiteOnBlackEtch_TypeStatus"]] autorelease];
		iconImageView.center = CGPointMake(iconImageView.center.x, self.frame.size.height / 2.f);
		iconImageView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
		[_containerView addSubview:iconImageView];

		_iconWidth = iconImageView.frame.size.width;

		_typeLabel = [[UILabel alloc] initWithFrame:CGRectMake(_iconWidth + 4.f, 0, 0, self.frame.size.height)];
		_typeLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		_typeLabel.font = [UIFont boldSystemFontOfSize:14.f];
		_typeLabel.backgroundColor = [UIColor clearColor];
		_typeLabel.textColor = [UIColor whiteColor];
		[_containerView addSubview:_typeLabel];

		_contactLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, self.frame.size.height)];
		_contactLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		_contactLabel.font = [UIFont systemFontOfSize:14.f];
		_contactLabel.backgroundColor = [UIColor clearColor];
		_contactLabel.textColor = [UIColor whiteColor];
		[_containerView addSubview:_contactLabel];
	}

	return self;
}

- (NSString *)string {
	return _contactLabel.text;
}

- (void)setString:(NSString *)string {
	if (string) {
		_contactLabel.text = string ?: @"";

		CGRect labelFrame = _contactLabel.frame;
		labelFrame.size.width = [_contactLabel.text sizeWithFont:_contactLabel.font constrainedToSize:self.frame.size lineBreakMode:UILineBreakModeTailTruncation].width;
		_contactLabel.frame = labelFrame;

		CGRect containerFrame = _containerView.frame;
		containerFrame.size.width = _contactLabel.frame.origin.x + _contactLabel.frame.size.width;
		_containerView.frame = containerFrame;

		_containerView.center = CGPointMake(self.frame.size.width / 2.f, _containerView.center.y);
	} else {
		[self hide];
	}
}

- (HBTSStatusBarType)type {
	return _type;
}

- (void)setType:(HBTSStatusBarType)type {
	_type = type;

	switch (type) {
		case HBTSStatusBarTypeTyping:
			_typeLabel.text = I18N(@"Typing:");
			break;

		case HBTSStatusBarTypeRead:
			_typeLabel.text = I18N(@"Read:");
			break;
	}

	CGRect typeFrame = _typeLabel.frame;
	typeFrame.size.width = [_typeLabel.text sizeWithFont:_typeLabel.font constrainedToSize:self.frame.size lineBreakMode:UILineBreakModeTailTruncation].width;
	_typeLabel.frame = typeFrame;

	CGRect labelFrame = _contactLabel.frame;
	labelFrame.origin.x = typeFrame.origin.x + typeFrame.size.width + 4.f;
	_contactLabel.frame = labelFrame;
}

- (void)showWithTimeout:(double)timeout {
	if (_timer || _isAnimating) {
		return;
	}

	UIStatusBarForegroundView *foregroundView = MSHookIvar<UIStatusBarForegroundView *>([UIApplication sharedApplication].statusBar, "_foregroundView");

	self.hidden = NO;
	_isAnimating = YES;

	if (_shouldSlide) {
		CGRect frame = self.frame;
		frame.origin.y = -kHBTSStatusBarHeight;
		self.frame = frame;
	}

	self.alpha = _shouldFade ? 0 : 1;
	self.hidden = NO;

	[UIView animateWithDuration:0.3f animations:^{
		if (_shouldSlide) {
			CGRect frame = self.frame;
			frame.origin.y = 0;
			self.frame = frame;

			foregroundView.clipsToBounds = YES;

			CGRect foregroundFrame = foregroundView.frame;
			foregroundFrame.origin.y = kHBTSStatusBarHeight;
			foregroundFrame.size.height = 0;
			foregroundView.frame = foregroundFrame;
		}

		self.alpha = 1;

		if (_shouldFade) {
			foregroundView.alpha = 0;
		}
	} completion:^(BOOL finished) {
		_isAnimating = NO;
		_timer = [[NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(hide) userInfo:nil repeats:NO] retain];
	}];
}

- (void)hide {
	if (!_timer || _isAnimating) {
		return;
	}

	_isAnimating = YES;

	[_timer invalidate];
	[_timer release];
	_timer = nil;

	UIStatusBarForegroundView *foregroundView = MSHookIvar<UIStatusBarForegroundView *>([UIApplication sharedApplication].statusBar, "_foregroundView");

	[UIView animateWithDuration:0.3f animations:^{
		CGRect frame = self.frame;
		frame.origin.y = -kHBTSStatusBarHeight;
		self.frame = frame;

		CGRect foregroundFrame = foregroundView.frame;
		foregroundFrame.origin.y = 0;
		foregroundFrame.size.height = kHBTSStatusBarHeight;
		foregroundView.frame = foregroundFrame;

		foregroundView.alpha = 1;

		if (_shouldFade) {
			self.alpha = 0;
		}
	} completion:^(BOOL finished) {
		self.hidden = YES;

		CGRect frame = self.frame;
		frame.origin.y = 0;
		self.frame = frame;

		self.alpha = 1;

		_typeLabel.text = @"";
		_contactLabel.text = @"";

		self.hidden = YES;
		_isAnimating = NO;
	}];
}
@end
