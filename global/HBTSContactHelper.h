@interface HBTSContactHelper : NSObject

+ (BOOL)shouldShowAlertOfType:(HBTSStatusBarType)type;
+ (BOOL)isHandleMuted:(NSString *)handle;

+ (NSString *)nameForHandle:(NSString *)handle;

@end
