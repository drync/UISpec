
#import "UILog.h"
#import "UIConsoleLog.h"
@interface UIServerLog : UIConsoleLog {
	NSString* reportFile ;
}
@property(retain) NSString* reportFile;

@end
