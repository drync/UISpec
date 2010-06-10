//
//  UIServer.h
//  UISpec
//
//  Created by Rob Mathews on 6/5/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mongoose.h"
#include <pthread.h>

typedef enum 
{
	STOPPED,
	STARTING,
	RUNNING
} UIServer_Status;

@interface UIServer : NSObject {
	bool exitFlag;
	struct mg_context* ctx;
	pthread_mutex_t signal, started_signal;
	NSString* logdir;
	UIServer_Status status;
}
-(UIServer*) initWithPort:(int) port;
-(void) runServerWithArgC: (int) argc withArgV: ( char **)argv;
// Return the value of the parameter for the current request
+(NSString*) getValueForParam:(NSString*) param;
@end
