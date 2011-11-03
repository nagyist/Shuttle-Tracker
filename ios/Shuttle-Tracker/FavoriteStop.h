//
//  FavoriteStop.h
//  Shuttle-Tracker
//
//  Created by Brendon Justin on 11/3/11.
//  Copyright (c) 2011 Naga Softworks, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Route, Stop;

@interface FavoriteStop : NSManagedObject

@property (nonatomic, retain) Stop *stop;
@property (nonatomic, retain) Route *route;

@end
