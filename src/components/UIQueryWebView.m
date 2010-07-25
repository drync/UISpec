
#import "UIQueryWebView.h"

static NSString* kClickJS = @"\
var ele = %@; \
if(ele.attributes['onclick']) \
eval(ele.attributes['onclick'].value); \
else \
ele.click()";

static NSString* locateByIdJS(NSString* elementName)
{
	return[NSString stringWithFormat:@"document.getElementById('%@')", elementName];
}

static NSString* locateByNameJS(NSString* elementName)
{
	return[NSString stringWithFormat:@"document.getElementsByName('%@')[0]", elementName];
}

@implementation UIQueryWebView



-(UIQuery *)setValue:(NSString *)value forElementWithName:(NSString *)elementName {
	//NSString *javascript = [NSString stringWithFormat:@"$('#%@').val('%@');", elementName, value];
	NSString *javascript = [NSString stringWithFormat:@"%@.value = '%@';", locateByNameJS(elementName), value];
	
	//if(![self jQuerySupported])
//		[self injectjQuery];
	
	[self stringByEvaluatingJavaScriptFromString:javascript];
	return [UIQuery withViews:views className:className];
}


-(UIQuery *)clickElementWithName:(NSString *)elementName {	
	NSString *javascript = [NSString stringWithFormat:kClickJS, locateByNameJS(elementName)];
	[self stringByEvaluatingJavaScriptFromString:javascript];
	return [UIQuery withViews:views className:className];
}

-(UIQuery *)setValue:(NSString *)value forElementWithId:(NSString *)elementId {
	NSString *javascript = [NSString stringWithFormat:@"%@.value = '%@';", locateByIdJS(elementId), value];
	[self stringByEvaluatingJavaScriptFromString:javascript];
	return [UIQuery withViews:views className:className];
}

-(UIQuery *)clickElementWithId:(NSString *)elementId {	
	NSString *javascript = [NSString stringWithFormat:kClickJS, locateByIdJS(elementId)];
	[self stringByEvaluatingJavaScriptFromString:javascript];
	return [UIQuery withViews:views className:className];
}

-(void) injectjQuery {
	NSLog(@"Injecting jQuery");
	NSString *jQueryInjection = @"var headElement = document.getElementsByTagName('head')[0]; var script = document.createElement('script'); script.setAttribute('src','http://ajax.googleapis.com/ajax/libs/jquery/1.3.0/jquery.min.js'); script.setAttribute('type','text/javascript'); headElement.appendChild(script);";
	[self stringByEvaluatingJavaScriptFromString: jQueryInjection];	
}

-(BOOL) jQuerySupported {
	
	UIWebView *theWebView = self;
	NSString *html = [theWebView stringByEvaluatingJavaScriptFromString: @"document.documentElement.innerHTML"];
	
	BOOL isJQuerySupported = [html rangeOfString:@"jquery"].location != NSNotFound;
	
	NSLog([NSString stringWithFormat:@"jQuery Supported : %d", isJQuerySupported]);
	return isJQuerySupported;
}

-(NSString *) html {
	return [self stringByEvaluatingJavaScriptFromString: @"document.body.innerHTML"];
}

// Beware - dragons here! Returning an object is ok, but if you return a simple type, like say a BOOL, then you'll get an obscure error in the UIRedoer where UISpec is doing
// something funny. Probably essential, also, but definitely that code needs either nil or a real object returned. 
-(NSString*) findElementWithName:(NSString *)elementName
{
	NSString* tmp = [self stringByEvaluatingJavaScriptFromString:locateByNameJS(elementName)];
	return tmp != NULL;
}

-(NSString*) findElementWithId:(NSString *)elementId
{
	return [self stringByEvaluatingJavaScriptFromString: locateByIdJS(elementId)];
}

@end
