#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>

@interface MSPMusicPauserListController : PSViewController <UITableViewDelegate, UITableViewDataSource, NSNetServiceBrowserDelegate>

@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, retain) NSMutableArray *availableServices;
@property (nonatomic, retain) NSNetServiceBrowser *serviceBrowser;
@property (nonatomic, retain) NSNetService *selectedService;
@property (nonatomic, assign) UITableViewCell *selectedCell;

@end

static NSString * const CellID = @"MSPMusicPauserCell";

static NSString *MSPDictionaryPath()
{
    return [@"~/Library/Preferences/com.orikad.musicpauser.plist" stringByExpandingTildeInPath];
}

@implementation MSPMusicPauserListController

- (id)init
{
    self = [super init];
    
    if (self) {
        self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.availableServices = [NSMutableArray array];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Music Pauser";
    
    self.tableView.frame = (CGRect){CGPointZero, self.view.frame.size};
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    [self.view addSubview:self.tableView];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:CellID];
    
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [activityIndicator startAnimating];
    
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:activityIndicator] autorelease];
    
    [activityIndicator release];
    
    self.serviceBrowser = [[[NSNetServiceBrowser alloc] init] autorelease];
    self.serviceBrowser.delegate = self;
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSDictionary *savedDictionary = [NSDictionary dictionaryWithContentsOfFile:MSPDictionaryPath()];
        
        if (savedDictionary) {
            
            NSNetService *savedNetService = [[NSNetService alloc] initWithDomain:savedDictionary[@"domain"] type:savedDictionary[@"type"] name:savedDictionary[@"name"]];	
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                self.selectedService = savedNetService;
                [savedNetService release];
                
                [self.tableView reloadData];
                
            });
        }
    });
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.serviceBrowser searchForServicesOfType:@"_musicpauser._tcp." inDomain:@""];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.serviceBrowser stop];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    [self.availableServices addObject:aNetService];
    
    if (!moreComing) {
        [self.tableView reloadData];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    [self.availableServices removeObject:aNetService];
    
    if (!moreComing) {
        [self.tableView reloadData];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.availableServices count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellID forIndexPath:indexPath];
    
    NSNetService *netService = self.availableServices[indexPath.row];
    
    cell.textLabel.text = [netService name];
    
    if ([netService isEqual:self.selectedService]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.selectedCell = cell;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSNetService *netService = self.availableServices[indexPath.row];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSDictionary *serviceDictionary = @{ @"name" : [netService name] ?: @"", @"domain" : [netService domain] ?: @"", @"type" : [netService type] ?: @"" };
        
        if (![serviceDictionary writeToFile:MSPDictionaryPath() atomically:YES]) {
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error!" message:@"Failed to set service" delegate:nil cancelButtonTitle:@"Dismiss"otherButtonTitles:nil];
            [alertView show];
            [alertView release];
            
            return;
        }
        
        notify_post("com.orikad.musicpauser");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.selectedService = netService;
            
            self.selectedCell.accessoryType = UITableViewCellAccessoryNone;
            
            self.selectedCell = [tableView cellForRowAtIndexPath:indexPath];
            
            self.selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
            
        });
    });
}


- (void)dealloc
{
    [_availableServices release];
    [_serviceBrowser release];
    [_tableView release];
    [_selectedService release];
    
    [super dealloc];
}

@end

// vim:ft=objc
