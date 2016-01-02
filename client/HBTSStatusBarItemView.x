#import "HBTSStatusBarItemView.h"
#import <UIKit/_UILegibilityImageSet.h>

%subclass HBTSStatusBarItemView : UIStatusBarItemView

- (CGSize)intrinsicContentSize {
	%log;
	return self.contentsImage.image.size;
}

- (void)updateContentsAndWidth {
	%orig;
	[self invalidateIntrinsicContentSize];
}

%end
