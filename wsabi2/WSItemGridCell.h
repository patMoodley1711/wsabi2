//
//  WSItemGridCell.h
//  wsabi2
//
//  Created by Matt Aronoff on 1/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WSCDItem.h"
#import "constants.h"

@protocol WSItemGridCellDelegate <NSObject>

-(void) didRequestItemDeletion:(WSCDItem*)item;

@end

@interface WSItemGridCell : KKGridViewCell <UIActionSheetDelegate>
{
    BOOL initialLayoutComplete;
}

-(void) deleteButtonPressed:(id)sender;

@property (nonatomic, unsafe_unretained) id<WSItemGridCellDelegate> delegate;

@property (nonatomic, strong) WSCDItem *item;
@property (nonatomic, strong) IBOutlet UIButton *deleteButton;

@end
