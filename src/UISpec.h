//
//  UISpec.h
//  UISpec
//
//  Created by Brian Knorr <btknorr@gmail.com>
//  Copyright(c) 2009 StarterStep, Inc., Some rights reserved.
//

@class UILog;

@interface UISpec : NSObject {

}

+(void)runSpecsAfterDelay:(int)seconds;
+(void)runSpec:(NSString *)specName afterDelay:(int)seconds;
+(void)runSpec:(NSString *)specName example:(NSString *)exampleName afterDelay:(int)seconds;
+(void)runExamples:(NSArray *)examples onSpec:(Class *)class;
+(void)setLog:(UILog *)log;
+(void)runServer:(int) port withArgC: (int) argc withArgV: ( char **)argv;
@end

@protocol UISpec
@end

