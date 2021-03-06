// This software was developed at the National Institute of Standards and
// Technology (NIST) by employees of the Federal Government in the course
// of their official duties. Pursuant to title 17 Section 105 of the
// United States Code, this software is not subject to copyright protection
// and is in the public domain. NIST assumes no responsibility whatsoever for
// its use by other parties, and makes no guarantees, expressed or implied,
// about its quality, reliability, or any other characteristic.

#import "BWSDDLog.h"
#import "UIImage+NBCLExtras.h"

#import "BWSDeviceChooserController.h"

#import "BWSAppDelegate.h"

@implementation BWSDeviceChooserController
@synthesize submodality;
@synthesize modality;
@synthesize item;
@synthesize autodiscoveryEnabled;
@synthesize currentButton;


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = [BWSModalityMap stringForCaptureType:self.submodality];
    [self.view setAccessibilityLabel:@"Device Walkthrough -- Choose Sensor"];

    //Fetch a list of recent sensors from Core Data
    
    //Since we might be working on a temporary object, don't ask it for a managed object context.
    //Instead, get the primary context from the app delegate.
    NSManagedObjectContext *moc = [(BWSAppDelegate*)[[UIApplication sharedApplication] delegate] managedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:kBWSEntityDeviceDefinition inManagedObjectContext:moc];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    //FIXME: This is currently disabled, because we'll need to get data from the sensors before
    //being able to filter
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
                              @"(modalities like %@)",
                              [BWSModalityMap stringForModality:self.modality], 
                              [BWSModalityMap stringForCaptureType:self.submodality]];
    [request setPredicate:predicate];
    
    //get a sorted list of the recent sensors
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStampLastEdit" ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:sortDescriptor, nil];
    [request setSortDescriptors:sortDescriptors];
    
    NSError *error = nil;
    NSArray *rawRecentSensors = [moc executeFetchRequest:request error:&error];
    if (rawRecentSensors == nil)
    {
        DDLogBWSDevice(@"Couldn't get a list of recent sensors, error was: %@",[error description]);
    }
    
    //NOTE: Not speedy. O(n^2)ish.
    recentSensors = [[NSMutableArray alloc] init];
    for (BWSCDDeviceDefinition *dev in rawRecentSensors) {
        BOOL unique = YES;
        //if this isn't in the pruned recent sensors list already, add it.
        for (BWSCDDeviceDefinition *existingDev in recentSensors) {
            if ([existingDev.uri isEqualToString:dev.uri] && [existingDev.name isEqualToString:dev.name]) {
                //this isn't unique, so don't add it.
                unique = NO;
            }
        }
        if (unique) {
            [recentSensors addObject:dev];
        }
    }
    
    DDLogBWSDevice(@"Found %d unique recent sensors matching these criteria",[recentSensors count]);
    
    //Set up the current sensor button
    if (self.item.managedObjectContext && self.item.deviceConfig
        && (self.modality == [BWSModalityMap modalityForString:self.item.modality])
        && (self.submodality == [BWSModalityMap captureTypeForString:self.item.submodality])) {
        self.currentButton = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"Use current settings"]
                                                              style:UIBarButtonItemStyleDone
                                                             target:self action:@selector(currentButtonPressed:)];
        self.navigationItem.rightBarButtonItem = self.currentButton;
    }
    

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.view logViewPresented];
    [[self tableView] startLoggingBWSInterfaceEventType:kBWSInterfaceEventTypeTap];
    [[self tableView] startLoggingBWSInterfaceEventType:kBWSInterfaceEventTypeScroll];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self.view logViewDismissed];
    [[self tableView] stopLoggingBWSInterfaceEvents];

    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

#pragma mark - Button action methods
-(IBAction) currentButtonPressed:(id)sender
{
    //Push a new controller to configure the device.
    BWSDeviceSetupController *subChooser = [[BWSDeviceSetupController alloc] initWithNibName:@"BWSDeviceSetupController" bundle:nil];
    
    subChooser.item = self.item; //pass the data object
    subChooser.modality = self.modality;
    subChooser.submodality = self.submodality;
    subChooser.deviceDefinition = self.item.deviceConfig;
    subChooser.deviceDefinition.timeStampLastEdit = [NSDate date];

      
    [self.navigationController pushViewController:subChooser animated:YES];
    
}

- (void)cancelButtonPressed:(id)sender
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    if (self.autodiscoveryEnabled) {
        if (recentSensors && [recentSensors count] > 0) {
            return 3;
        }
        else return 2;
    }
    else {
        if (recentSensors && [recentSensors count] > 0) {
            return 2;
        }
        else return 1;

    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.autodiscoveryEnabled) {
        //Everything
        if (recentSensors && [recentSensors count] > 0) {
            switch (section) {
                case 0:
                    //return the number of recent sensors stored for this modality, capped at our maximum
                    return MIN([recentSensors count], NUM_RECENT_SENSORS);
                    break;
                case 1:
                    //return the number of autodiscovered sensors found for this modality.
                    break;
                case 2:
                    return 1; //only one row for the add button
                    break;
                default:
                    break;
            }
        }
        //No recents
        else {
            switch (section) {
                case 0:
                    //return the number of autodiscovered sensors found for this modality.
                    break;
                case 1:
                    return 1; //only one row for the add button
                    break;
                default:
                    break;
            }

        }
    }
    else {
        //No autodiscovered
        if (recentSensors && [recentSensors count] > 0) {
            switch (section) {
                case 0:
                    //return the number of recent sensors stored for this modality, capped at our maximum
                    return MIN([recentSensors count], NUM_RECENT_SENSORS);
                    break;
                case 1:
                    return 1; //only one row for the add button
                    break;
                default:
                    break;
            }
        }
        //Just the "add new" section
        else {
            switch (section) {
                case 0:
                    return 1; //only one row for the add button
                    break;
                default:
                    break;
            }

        }
        
    }
 
    // Return the number of rows in the section.
    return 0;
}

-(NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.autodiscoveryEnabled) {
        //Everything
        if (recentSensors && [recentSensors count] > 0) {
            switch (section) {
                case 0:
                    return @"Recent sensors";
                    break;
                case 1:
                    return @"Autodiscovered sensors";
                    break;
                 default:
                    break;
            }
        }
        //No recents
        else {
            switch (section) {
                case 0:
                    return @"Autodiscovered sensors";
                    break;
                 default:
                    break;
            }
            
        }
    }
    else {
        //No autodiscovered
        if (recentSensors && [recentSensors count] > 0) {
            switch (section) {
                case 0:
                    return @"Recent sensors";
                    break;
                default:
                    break;
            }
        }
    }
    
    // Return the number of rows in the section.
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    
    NSString *titleString = nil;
    NSString *subtitleString = nil;
    UIImage *greenCheckmark = [UIImage imageWithString:@"✅" font:[UIFont systemFontOfSize:30]];
    [cell setIndentationWidth:greenCheckmark.size.width];
    [cell setIndentationLevel:0];
    [cell startLoggingBWSInterfaceEventType:kBWSInterfaceEventTypeTap];
    
    // Configure the cell...
    if (self.autodiscoveryEnabled) {
        //Everything
        if (recentSensors && [recentSensors count] > 0) {
            switch (indexPath.section) {
                case 0:
                    titleString = [(BWSCDDeviceDefinition*)[recentSensors objectAtIndex:indexPath.row] name];
                    if (titleString == nil || [titleString isEqualToString:@""])
                        titleString = @"<Unnamed>";
                    subtitleString = [(BWSCDDeviceDefinition*)[recentSensors objectAtIndex:indexPath.row] uri];
                    if (subtitleString == nil || [subtitleString isEqualToString:@""])
                        subtitleString = @"<No URI>";
                    if ([[self item] deviceConfig] != nil) {
                        // Cannot use isEquals because of the way the recentSensors array is built
                        if ([[[[self item] deviceConfig] name] isEqualToString:[[recentSensors objectAtIndex:indexPath.row] name]] &&
                            [[[[self item] deviceConfig] uri] isEqualToString:[((BWSCDDeviceDefinition *)[recentSensors objectAtIndex:indexPath.row]) uri]]) {
                            [[cell imageView] setImage:greenCheckmark];
                            [cell setIndentationLevel:0];
                        } else
                            [cell setIndentationLevel:1];
                    }
                    break;
                case 1:
                    //return the number of autodiscovered sensors found for this modality.
                    break;
                case 2:
                    titleString = @"Add a new sensor";
                    break;
                default:
                    break;
            }
        }
        //No recents
        else {
            switch (indexPath.section) {
                case 0:
                    //return the number of autodiscovered sensors found for this modality.
                    break;
                case 1:
                    titleString = @"Add a new sensor";
                    break;
                default:
                    break;
            }
            
        }
    }
    else {
        //No autodiscovered
        if (recentSensors && [recentSensors count] > 0) {
            switch (indexPath.section) {
                case 0:
                    titleString = [(BWSCDDeviceDefinition*)[recentSensors objectAtIndex:indexPath.row] name];
                    if (titleString == nil || [titleString isEqualToString:@""])
                        titleString = @"<Unnamed>";
                    subtitleString = [(BWSCDDeviceDefinition*)[recentSensors objectAtIndex:indexPath.row] uri];
                    if (subtitleString == nil || [subtitleString isEqualToString:@""])
                        subtitleString = @"<No URI>";
                    if ([[self item] deviceConfig] != nil) {
                        // Cannot use isEquals because of the way the recentSensors array is built
                        if ([[[[self item] deviceConfig] name] isEqualToString:[[recentSensors objectAtIndex:indexPath.row] name]] &&
                            [[[[self item] deviceConfig] uri] isEqualToString:[((BWSCDDeviceDefinition *)[recentSensors objectAtIndex:indexPath.row]) uri]]) {
                            [[cell imageView] setImage:greenCheckmark];
                            [cell setIndentationLevel:0];
                        } else
                            [cell setIndentationLevel:1];
                    }
                    break;
                case 1:
                    titleString = @"Add a new sensor";
                    break;
                default:
                    break;
            }
        }
        //Just the "add new" section
        else {
            switch (indexPath.section) {
                case 0:
                    titleString = @"Add a new sensor";
                    break;
                default:
                    break;
            }
            
        }
        
    }
    
    cell.textLabel.text = titleString;
    cell.detailTextLabel.text = subtitleString;
    cell.accessibilityLabel = cell.textLabel.text;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle ==  UITableViewCellEditingStyleDelete)
        [[tableView cellForRowAtIndexPath:indexPath] stopLoggingBWSInterfaceEvents];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //Push a new controller to configure the device.
    BWSDeviceSetupController *subChooser = [[BWSDeviceSetupController alloc] initWithNibName:@"BWSDeviceSetupController" bundle:nil];
    
    subChooser.item = self.item; //pass the data object
    subChooser.modality = self.modality;
    subChooser.submodality = self.submodality;
        
    //Configure the device definition
    //FIXME: Either choose an existing def and copy it, or start with a new def here.

    BWSCDDeviceDefinition *def = nil;
    BOOL createNewDef = NO;
    if (self.autodiscoveryEnabled) {
        //Everything
        if (recentSensors && [recentSensors count] > 0) {
            switch (indexPath.section) {
                case 0:
                    //duplicate this sensor
                    def = [recentSensors objectAtIndex:indexPath.row];
                    break;
                case 1:
                    //return the number of autodiscovered sensors found for this modality.
                    break;
                case 2:
                    createNewDef = YES;
                    break;
                default:
                    break;
            }
        }
        //No recents
        else {
            switch (indexPath.section) {
                case 0:
                    //return the number of autodiscovered sensors found for this modality.
                    break;
                case 1:
                    createNewDef = YES;
                    break;
                default:
                    break;
            }
            
        }
    }
    else {
        //No autodiscovered
        if (recentSensors && [recentSensors count] > 0) {
            switch (indexPath.section) {
                case 0:
                    //duplicate this sensor
                    def = [recentSensors objectAtIndex:indexPath.row];
                    break;
                case 1:
                    createNewDef = YES;
                    break;
                default:
                    break;
            }
        }
        //Just the "add new" section
        else {
            switch (indexPath.section) {
                case 0:
                    createNewDef = YES;
                    break;
                default:
                    break;
            }
            
        }
        
    }
    
    //NOTE: We're not actually connecting the device definition with the item yet;
    //that happens when the user clicks the DONE button in the device setup controller.
    
    //If we need to create a new device def, do so.
    NSManagedObjectContext *moc = [(BWSAppDelegate*)[[UIApplication sharedApplication] delegate] managedObjectContext];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kBWSEntityDeviceDefinition inManagedObjectContext:moc];
    if (!def && createNewDef) {
        //Create a temporary item
        BWSCDDeviceDefinition *newDef = (BWSCDDeviceDefinition*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:nil];
        newDef.timeStampLastEdit = [NSDate date];
        subChooser.deviceDefinition = newDef; 
    }
    else if (def) {
        // If we select the currently selected and possibly non-unique instance
        // of this sensor, we need to pass the unique instance of the sensor
        // so that it is not duplicated but merely updated.  Otherwise,
        // duplicate the sensor information and have that sensor be associated
        // with this item.
        if ([[[tableView cellForRowAtIndexPath:indexPath] imageView] image] != nil) {
            subChooser.deviceDefinition = self.item.deviceConfig;
            subChooser.deviceDefinition.timeStampLastEdit = [NSDate date];
        } else {
            // Create a new item or update exists
            BWSCDDeviceDefinition *newDef;
            if (self.item.deviceConfig == nil)
                newDef = (BWSCDDeviceDefinition*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:nil];
            else
                newDef = self.item.deviceConfig;
            newDef.inactivityTimeout = def.inactivityTimeout;
            newDef.modalities = def.modalities;
            newDef.mostRecentSessionId = def.mostRecentSessionId;
            newDef.name = def.name;
            newDef.parameterDictionary = def.parameterDictionary;
            newDef.submodalities = def.submodalities;
            newDef.uri = def.uri;
            newDef.timeStampLastEdit = [NSDate date];
            subChooser.deviceDefinition = newDef;
        }
    }

    
    [self.navigationController pushViewController:subChooser animated:YES];
}

@end
