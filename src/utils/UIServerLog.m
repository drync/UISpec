#import "UIServerLog.h"
#import "UISpec.h"

@implementation UIServerLog
@synthesize reportFile;

- (void)dealloc {
	[super dealloc];
    self.reportFile = nil;
}

-(void) logException: (NSException *)exception
{
	NSString *error = [NSString stringWithFormat:@"%@ %@ FAILED:%@", currentSpec, currentExample, exception.reason];
	FILE* file = fopen([reportFile UTF8String], "a+");
	fprintf(file, "%s\n", [error cStringUsingEncoding: [NSString defaultCStringEncoding]]);
	fclose(file);
}

-(void)onBeforeException:(NSException *)exception {
	[super onBeforeException:exception];
	[self logException: exception];
}

-(void)onAfterException:(NSException *)exception {
	[super onAfterException:exception];
	[self logException: exception];
}

-(void)onExampleException:(NSException *)exception {
	[super onExampleException:exception];
	[self logException: exception];
}

@end
