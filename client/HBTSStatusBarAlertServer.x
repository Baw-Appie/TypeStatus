#import "HBTSStatusBarAlertServer.h"
#import "HBTSPreferences.h"
#import "HBTSStatusBarAlertController.h"
#import <Foundation/NSDistributedNotificationCenter.h>

@implementation HBTSStatusBarAlertServer

+ (NSString *)iconNameForType:(HBTSMessageType)type {
	// return the appropriate icon name
	NSString *name = nil;

	switch (type) {
		case HBTSMessageTypeTyping:
			name = @"TypeStatus";
			break;

		case HBTSMessageTypeReadReceipt:
			name = @"TypeStatusRead";
			break;

		case HBTSMessageTypeTypingEnded:
			break;
			
		case HBTSMessageTypeSendingFile:
			name = @"TypeStatus";
			break;
	}

	return name;
}

+ (NSString *)textForType:(HBTSMessageType)type sender:(NSString *)sender boldRange:(out NSRange *)boldRange {
	static NSBundle *PrefsBundle;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		PrefsBundle = [NSBundle bundleWithPath:@"/Library/PreferenceBundles/TypeStatus.bundle"];
	});

	HBTSPreferences *preferences = [%c(HBTSPreferences) sharedInstance];

	switch (preferences.overlayFormat) {
		case HBTSStatusBarFormatNatural:
		{
			// natural string with name in bold
			NSString *format = @"";

			switch (type) {
				case HBTSMessageTypeTyping:
					format = [PrefsBundle localizedStringForKey:@"TYPING_NATURAL" value:nil table:@"Localizable"];
					break;

				case HBTSMessageTypeReadReceipt:
					format = [PrefsBundle localizedStringForKey:@"READ_NATURAL" value:nil table:@"Localizable"];
					break;

				case HBTSMessageTypeTypingEnded:
					break;

				case HBTSMessageTypeSendingFile:
					format = [PrefsBundle localizedStringForKey:@"SENDING_FILE_NATURAL" value:nil table:@"Localizable"];
					break;
			}

			NSUInteger location = [format rangeOfString:@"%@"].location;

			// if the %@ wasn’t found, the string probably isn’t translated… this is pretty bad so we
			// should probably just return what we have so the error is obvious
			if (location == NSNotFound) {
				*boldRange = NSMakeRange(0, 0);
				return format;
			}

			*boldRange = NSMakeRange(location, sender.length);

			return [NSString stringWithFormat:format, sender];
			break;
		}

		case HBTSStatusBarFormatTraditional:
		{
			// prefix Typing: or Read: in bold
			NSString *prefix = @"";

			switch (type) {
				case HBTSMessageTypeTyping:
					prefix = [PrefsBundle localizedStringForKey:@"TYPING" value:nil table:@"Localizable"];
					break;

				case HBTSMessageTypeReadReceipt:
					prefix = [PrefsBundle localizedStringForKey:@"READ" value:nil table:@"Localizable"];
					break;

				case HBTSMessageTypeTypingEnded:
					break;

				case HBTSMessageTypeSendingFile:
					prefix = [PrefsBundle localizedStringForKey:@"SENDING_FILE" value:nil table:@"Localizable"];
					break;
			}

			*boldRange = NSMakeRange(0, prefix.length);

			return [NSString stringWithFormat:@"%@ %@", prefix, sender];
			break;
		}

		case HBTSStatusBarFormatNameOnly:
		{
			// just the sender name on its own
			*boldRange = NSMakeRange(0, sender.length);
			return sender;
			break;
		}
	}
}

#pragma mark - Send

+ (void)sendAlertWithIconName:(NSString *)iconName text:(NSString *)text boldRange:(NSRange)boldRange source:(NSString *)source timeout:(NSTimeInterval)timeout {
	// ensure no required arguments are missing
	NSParameterAssert(text);
	NSParameterAssert(source);

	// if the timeout is -1, replace it with the user's specified duration
	if (timeout == -1) {
		timeout = ((HBTSPreferences *)[%c(HBTSPreferences) sharedInstance]).overlayDisplayDuration;
	}

	// send the notification
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSDistributedNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:HBTSClientSetStatusBarNotification object:nil userInfo:@{
			kHBTSMessageIconNameKey: iconName ?: @"",
			kHBTSMessageContentKey: text ?: @"",
			kHBTSMessageBoldRangeKey: @[ @(boldRange.location), @(boldRange.length) ],
			kHBTSMessageSourceKey: source ?: @"",

			kHBTSMessageDirectionKey: @YES,
			kHBTSMessageTimeoutKey: @(timeout),
			kHBTSMessageSendDateKey: [NSDate date]
		}]];
	});
}

+ (void)sendMessagesAlertType:(HBTSMessageType)type sender:(NSString *)sender timeout:(NSTimeInterval)timeout {
	// if this is a typing ended message
	if (type == HBTSMessageTypeTypingEnded) {
		// we just need to call hide
		[self hide];
	} else {
		// grab all data needed to turn a typestatus specific alert into a generic alert, and then pass
		// it through
		NSString *iconName = [self iconNameForType:type];

		NSRange boldRange;
		NSString *text = [self textForType:type sender:sender boldRange:&boldRange];

		[self sendAlertWithIconName:iconName text:text boldRange:boldRange source:@"com.apple.MobileSMS" timeout:timeout];
	}
}

+ (void)hide {
	// a hide message is just sending nil values with the direction set to NO (hide)
	// send the notification
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSDistributedNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:HBTSClientSetStatusBarNotification object:nil userInfo:@{
			kHBTSMessageDirectionKey: @NO
		}]];
	});
}

@end
