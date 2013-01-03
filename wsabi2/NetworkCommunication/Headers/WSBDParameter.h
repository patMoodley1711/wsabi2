//
//  WSBDParameter.h
//  wsabi2
//
//  Created by Matt Aronoff on 3/2/12.
 
//

#import <Foundation/Foundation.h>

@interface WSBDParameter : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) id defaultValue; //either an NSNumber or a string
@property (nonatomic) BOOL readOnly;
@property (nonatomic) BOOL supportsMultiple;
@property (nonatomic, strong) NSMutableArray *allowedValues;


@end