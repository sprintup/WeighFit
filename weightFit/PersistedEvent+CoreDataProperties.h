//
//  PersistedEvent+CoreDataProperties.h
//  TriFitness
//
//  Created by Stephen Printup on 2/8/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "PersistedEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface PersistedEvent (CoreDataProperties)

@property (nonatomic) int32_t eventCalories;
@property (nullable, nonatomic, retain) NSString *eventDate;
@property (nullable, nonatomic, retain) NSString *eventDescription;
@property (nullable, nonatomic, retain) NSString *eventType;
@property (nullable, nonatomic, retain) NSString *eventTime;
@property (nullable, nonatomic, retain) PersistedDay *day;

@end

NS_ASSUME_NONNULL_END
