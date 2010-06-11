//
//  UIServer.m
//  UISpec
//
//  Created by Rob Mathews on 6/5/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "UIServer.h"
#import "UIQuery.h"
#import "UISpec.h"
#import "UIServerLog.h"

static UIServer* singleton;
static struct mg_connection * current_connection;

static const char *standard_reply =	"HTTP/1.1 200 OK\r\n"
"Content-Type: text/plain\r\n"
"Connection: close\r\n\r\n";
static const char *redirect_reply =	"HTTP/1.1 302 Found\r\n"
"Location: %s\r\n"
"Connection: close\r\n\r\n";
static const char *error_reply =	"HTTP/1.1 500 Found\r\n"
"Content-Type: text/plain\r\n"
"Connection: close\r\n\r\n"
"Reason: %s\r\n";
static const char *illegal_method_reply =	"HTTP/1.1 405 Illegal Method\r\n"
"Content-Type: text/plain\r\n"
"Connection: close\r\n\r\n"
"Not Allowed: %\r\n";

//private Apple method. Declare here to quiet the warnings
@interface UIApplication()
-(void) terminateWithSuccess;
@end

// private methods
@interface UIServer()
-(void) applicationDidFinishLaunchingNotification:(NSNotification*) notification;
-(void) start: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri;
-(void) started: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri;
-(void) status: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri;
-(void) stop: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri;
-(void) run: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri;
-(void) get_run: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri;
@end

static void start(struct mg_connection *conn, const struct mg_request_info *ri,
				  void *user_data)
{
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[(UIServer*)user_data start: conn withRequest: ri];
//	[pool release];
}

static void started(struct mg_connection *conn, const struct mg_request_info *ri,
				  void *user_data)
{
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[(UIServer*)user_data started: conn withRequest: ri];
//	[pool release];
}

static void get_status(struct mg_connection *conn, const struct mg_request_info *ri,
					void *user_data)
{
	[(UIServer*)user_data status: conn withRequest: ri];
}
static void stop(struct mg_connection *conn, const struct mg_request_info *ri,
				 void *user_data)
{
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[(UIServer*)user_data stop: conn withRequest: ri];
//	[pool release];
}

static void run(struct mg_connection *conn, const struct mg_request_info *ri,
				void *user_data)
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[(UIServer*)user_data run: conn withRequest: ri];
	[pool release];
}

static void get_run(struct mg_connection *conn, const struct mg_request_info *ri,
				void *user_data)
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[(UIServer*)user_data get_run: conn withRequest: ri];
	[pool release];
}

static void illegal_method(struct mg_connection *conn, const struct mg_request_info *ri)
{
	mg_printf(conn, illegal_method_reply, ri->request_method);
}

static void copy_file(FILE* source, struct mg_connection * conn)
{
	char buffer[1024];
	int iii;
	while ((iii = fread (buffer, 1, sizeof (buffer)-1, source)) > 0)
	{
		buffer[iii]=0;
		mg_printf(conn, "%*s",iii,buffer);
	}
}

static void run_result_xml(struct mg_connection * conn, FILE* out_, FILE* err_, NSString* failuresPath)
{
	mg_printf(conn,
			  "HTTP/1.1 200 OK\r\n"
			  "Content-Type: text/xml\r\n\r\n"
			  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
	mg_printf(conn, "<run>\n");
	if(out_)
	{
		mg_printf(conn, "<stdout><![CDATA[\n");
		copy_file(out_, conn);
		mg_printf(conn, "]]></stdout>\n");
		fclose(out_);
	}
	if(err_)
	{
		mg_printf(conn, "<stderr><![CDATA[\n");
		copy_file(err_, conn);
		mg_printf(conn, "]]></stderr>\n");
		fclose(err_);
	}
	FILE* failures = fopen ([failuresPath cStringUsingEncoding: [NSString defaultCStringEncoding]],"r");
	if(failures != NULL)
	{
		mg_printf(conn, "<failures>");
		copy_file(failures, conn);
		mg_printf(conn, "</failures>");
		fclose(failures);
	}
	mg_printf(conn, "</run>\n");
}

static void run_result_html(struct mg_connection * conn, FILE* out_, FILE* err_, NSString* failuresPath)
{
	mg_printf(conn,
			  "HTTP/1.1 200 OK\r\n"
			  "Content-Type: text/html\r\n\r\n"
			  "<html><body>");
	mg_printf(conn, "<run>\n");
	if(out_)
	{
		mg_printf(conn, "STDOUT<br/><pre>\n");
		copy_file(out_, conn);
		mg_printf(conn, "</pre>\n");
		fclose(out_);
	}
	if(err_)
	{
		mg_printf(conn, "STDERR<br/><pre>\n");
		copy_file(err_, conn);
		mg_printf(conn, "</pre>\n");
		fclose(err_);
	}
	FILE* failures = fopen ([failuresPath cStringUsingEncoding: [NSString defaultCStringEncoding]],"r");
	if(failures != NULL)
	{
		mg_printf(conn, "FAILURES<br/><pre>");
		copy_file(failures, conn);
		mg_printf(conn, "</pre>");
		fclose(failures);
	}
	mg_printf(conn, "</body></html>\n");
}


@implementation UIServer

-(UIServer*) initWithPort:(int)port;
{
	singleton = self;
	logdir =[NSString stringWithString: @"/tmp/UIServer"];
	exitFlag = false;
	pthread_mutex_init(&started_signal, NULL);
	pthread_mutex_init(&signal, NULL);
	pthread_mutex_lock(&signal);
	pthread_mutex_lock(&started_signal);
	ctx = mg_start();
	NSString* portS = [NSString stringWithFormat:@"%d", port];
	mg_set_option(ctx, "ports", [portS cStringUsingEncoding: [NSString defaultCStringEncoding]]);
	
	mg_set_uri_callback(ctx, "/start", &start, self);
	mg_set_uri_callback(ctx, "/started", &started, self);
	mg_set_uri_callback(ctx, "/status", &get_status, self);
	mg_set_uri_callback(ctx, "/stop", &stop, self);
	mg_set_uri_callback(ctx, "/run", &run, self);
	mg_set_uri_callback(ctx, "/run/*", &get_run, self);
	status = STOPPED;
	return self;
}

-(void) dealloc
{
	[super dealloc];
	pthread_mutex_destroy(&signal);
	[logdir dealloc];
	if(ctx)
		mg_stop(ctx);
}

-(NSString*) getVar:(NSString*) iName withConnection: (struct mg_connection *) conn
{
	char * value = mg_get_var(conn, [iName cStringUsingEncoding: [NSString defaultCStringEncoding]]);
	if(value)
		return [NSString stringWithCString:value encoding:[NSString defaultCStringEncoding]];
	else
		return NULL;
	
}

-(void) start: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri
{
	if(status == STOPPED)
	{
		NSString* tmp;
		if(tmp = [self getVar:@"logdir" withConnection: conn])
			logdir = tmp;
		
		// Actually start the application. This is async - the app will start starting and return 
		// immediately. Call 'wait_start' to wait until this is done? 
		status = STARTING;
		pthread_mutex_unlock( &signal );

		// Wow ... so it turns out to be super special which thread the iPhone app runs in. MUST BE THE MAIN thread. 
		// Hence, we have a loop in the main thread that we signal, and it starts/stops the app.
		//	[NSThread detachNewThreadSelector:@selector(startApp) toTarget: self withObject: nil];
		// Register ourselves to be told when the app finishes initializing, so that any testcase that wanted to wait for that can.
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunchingNotification:) name: UIApplicationDidBecomeActiveNotification object:nil];
	}
	mg_printf(conn, redirect_reply, "/status");
}

-(void) applicationDidFinishLaunchingNotification:(NSNotification*) notification;
{
	// Quick Hack to force load
	UIWebView* forceAlloc = [[UIWebView alloc] initWithFrame:CGRectMake(0,36,320,331)];
	[forceAlloc release];

	status = RUNNING;
	pthread_mutex_unlock( &started_signal );
}

-(void) started: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri
{
	// wait until the app has finished starting. 
	if(status != RUNNING)
		pthread_mutex_lock( &started_signal );	
	mg_printf(conn, redirect_reply, "/status");

}

static char* sStatusArray[] = {"STOPPED", "STARTING", "RUNNING" };

-(void) status: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	if(strcmp(ri->request_method, "GET") != 0)
	{
		illegal_method(conn, ri);
		return;
	}
	mg_printf(conn,
			  "HTTP/1.1 200 OK\r\n"
			  "Content-Type: text/html\r\n\r\n"
			  "<html><body>\n"
			  "STATUS: %s\n"
			  "</body></html>\n", sStatusArray[status]);
	[pool release];
}




-(void) stop: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri
{
	mg_printf(conn, standard_reply);
	// Lock the mutex so that we don't auto-restart.
	pthread_mutex_lock( &signal );
	// Tell the application to stop gracefully. UNKNOWN!!!
	// Wow .. friggin private API impossible to find. And this API will result in EXIT being called, so that 
	[[UIApplication sharedApplication] terminateWithSuccess];
}


-(void) get_run: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri
{
	if(strcmp(ri->request_method, "GET") != 0)
	{
		illegal_method(conn, ri);
		return;
	}

	char run_id_str[1024];
	sscanf(ri->uri, "/run/%s",run_id_str);
	int run_id = atoi(run_id_str);
	
	NSString* outPath = [NSString stringWithFormat: @"%@/%d/stdout.txt",logdir, run_id];
	NSString* errPath = [NSString stringWithFormat: @"%@/%d/stderr.txt",logdir, run_id];
	NSString* failuresPath = [NSString stringWithFormat: @"%@/%d/failures.txt",logdir, run_id];
	FILE* out_ = fopen ([outPath cStringUsingEncoding: [NSString defaultCStringEncoding]],"r");
	FILE* err_ = fopen ([errPath cStringUsingEncoding: [NSString defaultCStringEncoding]],"r");
	if([@"xml" isEqualToString: [self getVar:@"format" withConnection:conn]])
		run_result_xml(conn, out_, err_, failuresPath);
	else
		run_result_html(conn, out_, err_, failuresPath);
	
}
	

-(void) run: (struct mg_connection *) conn withRequest: (const struct mg_request_info *)ri
{
	current_connection = conn;
	// parameters: testclass, testcase, script
	NSString* script = [self getVar:@"script" withConnection: conn];
	NSFileManager* fileManager = [[NSFileManager alloc] init];
	time_t run_id = time(NULL);
	
	NSString* resultPath = [NSString stringWithFormat: @"%@/%d",logdir, run_id];
	NSString* resultURL = [NSString stringWithFormat: @"/run/%d",run_id];
	if([@"xml" isEqualToString: [self getVar:@"format" withConnection:conn]])
		resultURL = [NSString stringWithFormat: @"/run/%d?format=xml",run_id];
		
	if(![fileManager createDirectoryAtPath:resultPath withIntermediateDirectories:YES attributes:nil error:nil])
	{
		mg_printf(conn, error_reply,"Can't create result directory");	
		return;
	}
	NSString* outPath = [NSString stringWithFormat: @"%@/%d/stdout.txt",logdir, run_id];
	NSString* errPath = [NSString stringWithFormat: @"%@/%d/stdout.txt",logdir, run_id];
	NSString* failuresPath = [NSString stringWithFormat: @"%@/%d/failures.txt",logdir, run_id];
	
	freopen ([outPath cStringUsingEncoding: [NSString defaultCStringEncoding]],"w+",stdout);
	freopen ([errPath cStringUsingEncoding: [NSString defaultCStringEncoding]],"w+",stderr);
	if(script)
	{
		NSString* failureReason = nil;
		NSMutableString* xxx = [script copy];

		@try 
		{
			$(xxx); // trying to call $(script) in UIScript ,, hmmm 
		}
		@catch (NSException *exception)
		{
			NSLog(@"exception %@: %@", [exception name], [exception reason]);
			failureReason = [NSString stringWithFormat: @"exception %@: %@", [exception name], [exception reason]];
		}
		@finally {
			[xxx release];
			
			if(failureReason)
			{
				FILE* failures_ = fopen([failuresPath cStringUsingEncoding: [NSString defaultCStringEncoding]], "w+");
				fprintf(failures_, "%s", [failureReason cStringUsingEncoding: [NSString defaultCStringEncoding]]);
				fclose(failures_);
			}
		}
	}
	else
	{
		UIServerLog* log = [UIServerLog alloc];
		log.reportFile = failuresPath;
		[UISpec setLog:(UILog*)log];
		@try 
		{
			// hmm not setting the output here as needed!
			NSString* testclass = [self getVar:@"class" withConnection: conn];
			NSString* method = [self getVar:@"method" withConnection: conn];
			Class *class = NSClassFromString(testclass);
			[UISpec runExamples:[NSArray arrayWithObject:method] onSpec:class];
		}
		@catch (NSException *exception)
		{
			// Workaround for MapKit, which is essentially a corrupt release. panoramaID dynamic property is defined, but never implemented, 
			// causing an selector not understood exception. Here, we catch that and ignore it, rather than crashing.
			NSLog(@"main: Caught %@: %@", [exception name], [exception reason]);
		}
		[log release];
	}
	fclose (stdout);
	fclose (stderr);
	mg_printf(conn, redirect_reply, [resultURL cStringUsingEncoding: [NSString defaultCStringEncoding]] );
	[fileManager release];
}


// Start the app the first time, then restart the app when requested unless it requested exit.
-(void) runServerWithArgC: (int) argc withArgV: ( char **)argv
{
	while(1)
	{
		pthread_mutex_lock( &signal );
		pthread_mutex_unlock( &signal );
		if(exitFlag)
			break;
		UIApplicationMain(argc, argv, nil, nil);
	}
}

+(NSString*) getValueForParam:(NSString*) param
{
	return [singleton getVar: param withConnection: current_connection];
}

@end
