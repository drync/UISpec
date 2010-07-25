//
//  UIQueryWebView.h
//  UISpec
//
//  Created by Cory Smith <cory.m.smith@gmail.com>
//  Copyright 2009 Assn. All rights reserved.
//

#import "UIQuery.h"

@interface UIQueryWebView : UIQuery {
	
}
-(UIQuery *)setValue:(NSString *)value forElementWithName:(NSString *)elementId;
-(UIQuery *)setValue:(NSString *)value forElementWithId:(NSString *)elementId;
-(UIQuery *)clickElementWithId:(NSString *)elementId;
-(UIQuery *)clickElementWithName:(NSString *)elementName;
// yes, indeed, a bit weird. I wanted to return a BOOL, but a dirty little secret is that you can't return BOOLS
-(NSString *) findElementWithName:(NSString *)elementName; 
-(NSString *) findElementWithId:(NSString *)elementId;
-(NSString *)html;
@end
