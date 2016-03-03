
//
//  WeighFitModel.m
//  weightFit
//
//  Created by ios on 11/8/15.
//  Copyright © 2015 Stephen Printup. All rights reserved.
//

#import "WeighFitModel.h"

#pragma mark - Singletons

@implementation WeighFitModel

static WeighFitModel *sharedSingleton;

+ (WeighFitModel *)getInstance
    {
    if (sharedSingleton == nil) {
        sharedSingleton = [[super alloc]init];
    }
    return sharedSingleton;
}

#pragma mark - SettingsVC: input for calorie target

-(instancetype)init {
    self = [super init];
    
    if (self) {
        [WeighFitModel registerUserDefaults];
        
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        
        self.age = (int)[[def objectForKey:@"age"] integerValue];
        self.weight = (int)[[def objectForKey:@"weight"] integerValue];
        self.height = (int)[[def objectForKey:@"height"] integerValue];
        self.activityLevel = (int)[[def objectForKey:@"activityLevel"] integerValue];
        self.gender = [def objectForKey:@"gender"];
        self.notificationLimit = [def objectForKey:@"notificationLimit"];
    }
    
    return self;
}
                   
+ (void)registerUserDefaults {
    NSMutableDictionary *def = [[NSMutableDictionary alloc] init];
    
    [def setObject:[NSNumber numberWithInt:0] forKey:@"age"];
    [def setObject:[NSNumber numberWithInt:0] forKey:@"weight"];
    [def setObject:[NSNumber numberWithInt:0] forKey:@"height"];
    [def setObject:[NSNumber numberWithInt:0] forKey:@"activityLevel"];
    [def setObject:@"don't remind me" forKey:@"notificationLimit"];

    [[NSUserDefaults standardUserDefaults] registerDefaults:def];
}

- (void)saveUserDefaults {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    
    [def setInteger:self.age forKey:@"age"];
    [def setInteger:self.weight forKey:@"weight"];
    [def setInteger:self.height forKey:@"height"];
    [def setObject:self.gender forKey:@"gender"];
    [def setObject:self.notificationLimit forKey:@"notificationLimit"];

    [def synchronize];
}

-(void)updateAge:(int)age andHeight:(int)height andWeight:(int)weight andActivityLevel:(int)level andGender:(NSString *)gender {
    self.age = age;
    self.height = height;
    self.weight = weight;
    self.gender = gender;
    self.activityLevel = level;
    
    [self saveUserDefaults];
}

-(void)updateNotificationLimit:(NSString *)notificationLimit

{
    self.notificationLimit = notificationLimit;
    
    [self saveUserDefaults];
}

#pragma mark - helper methods


-(NSNumber *) calculateBasalMetabolicRateWithGender:(NSString *)gender
                                      weight:(NSNumber*)weight
                                      height:(NSNumber*)height
                                         age:(NSNumber*)age {
    int basalRate;
    
    if ([gender  isEqual: @"female"]) {
        basalRate = 655 + (4.35 * [weight floatValue]) + (4.7 * [height floatValue]) - (4.7 * [age floatValue]);
    }
    else
    {
        basalRate = 66 + ( 6.23 * [weight floatValue]) + ( 12.7 * [height floatValue]) - ( 6.8 * [age floatValue]);
    }
    
    NSNumber *basalRateNumberFromFloat = [NSNumber numberWithFloat:basalRate];
    return basalRateNumberFromFloat;
}

-(int)basalMetabolicRate {
    int basalRate;
    
    if ([self.gender  isEqual: @"female"]) {
        basalRate = 655 + (4.35 * self.weight) + (4.7 * self.height) - (4.7 * self.age);
    }
    else
    {
        basalRate = 66 + ( 6.23 * self.weight ) + ( 12.7 * self.height ) - ( 6.8 * self.age );
    }
    
    return basalRate;
}

-(double)getActivityFactorWithLevel:(int)level
{
    double activityFactorToReturn;
    if (level == 1)
    {
        activityFactorToReturn = 1.2;
    }
    else if (level == 2)
    {
        activityFactorToReturn = 1.375;
    }
    else if (level == 3)
    {
        activityFactorToReturn = 1.55;
    }
    else if (level == 4)
    {
        activityFactorToReturn = 1.725;
    }
    else if (level == 5)
    {
        activityFactorToReturn = 1.9;
    }
    return activityFactorToReturn;
}

@end
