//
//  WeighFitModel.h
//  weightFit
//
//  Created by ios on 11/8/15.
//  Copyright © 2015 Stephen Printup. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WeighFitModel : NSObject

//TODO: what do you think of refactoring this into a class or struct called UserInfo or something? Sure, sounds good -s
@property (nonatomic) int requiredCalories;
@property (nonatomic) int age;
@property (nonatomic) int weight;
@property (nonatomic) int height;
@property (nonatomic) int activityLevel;
@property (strong, nonatomic) NSString *gender;
@property (nonatomic) int basalMetabolicRate;
@property (strong,nonatomic) NSString *notificationLimit;


//TODO: refactor gender into an enumeration
+ (WeighFitModel *)getInstance;
-(void)updateAge:(int)age andHeight:(int)height andWeight:(int)weight andActivityLevel:(int)level andGender:(NSString *)gender;
-(NSNumber *) calculateBasalMetabolicRateWithGender:(NSString *)gender
                                           weight:(NSNumber*)weight
                                           height:(NSNumber*)height
                                              age:(NSNumber*)age;
-(void)updateNotificationLimit:(NSString *)notificationLimit;
-(double)getActivityFactorWithLevel:(int)level;

@end
