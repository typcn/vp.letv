//
//  vp-letv.m
//  vp-letv
//
//  Created by TYPCN on 2015/9/20.
//  Copyright © 2015 TYPCN. All rights reserved.
//

#import "letv.h"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface letv (){
    NSMutableArray *addrs;
    NSArray *sel_addr;
}

@property (strong) NSWindowController* settingsPanel;
@property (strong) NSWindowController* streamSelPanel;
@property (weak) IBOutlet NSButton *internalPlayBtn;
@property (weak) IBOutlet NSButton *QTPlayBtn;

@end

@implementation letv

@synthesize settingsPanel;
@synthesize streamSelPanel;

- (bool)load:(int)version{
    
    NSLog(@"VP-letv is loaded");
    
    return true;
}


- (bool)unload{
    
    return true;
}

int letv_convKey(int v , int key){
    int rv = v;
    for(int i = 0;i < key;i++){
        rv = ( 2147483647 & rv >> 1 )| (rv & 1) << 31;
    }
    return rv;
}

int letv_getTKey(int time){
    int key = 773625421;
    int v = letv_convKey(time, key % 13);
    v = v ^ key;
    v = letv_convKey(v, key % 17);
    return (int)v;
}

- (BOOL)preloadLetvPlayAddr:(NSString *)videoId{
    int tkey = letv_getTKey((int)time(0));
    
    NSString *str = [NSString stringWithFormat:@"http://api.letv.com/mms/out/video/playJson?id=%@&platid=1&splatid=101&format=1&tkey=%d&domain=www.letv.com",videoId,tkey];
    NSLog(@"STR %@",str);
    NSURL* URL = [NSURL URLWithString:str];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"GET";

    NSUserDefaults *settingsController = [NSUserDefaults standardUserDefaults];
    NSString *xff = [settingsController objectForKey:@"xff"];
    if([xff length] > 4){
        [request setValue:xff forHTTPHeaderField:@"X-Forwarded-For"];
        [request setValue:xff forHTTPHeaderField:@"Client-IP"];
    }
    
    [request addValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.99 Safari/537.36" forHTTPHeaderField:@"User-Agent"];

    NSURLResponse * response = nil;
    NSError * error = nil;
    NSData * videoAddressJSONData = [NSURLConnection sendSynchronousRequest:request
                                                          returningResponse:&response
                                                                      error:&error];
    if(error || !videoAddressJSONData){
        return false;
    }

    NSError *jsonError;
    NSDictionary *videoResult = [NSJSONSerialization JSONObjectWithData:videoAddressJSONData options:NSJSONReadingMutableContainers error:&jsonError];
    
    if(jsonError){
        NSLog(@"JSON ERROR:%@",jsonError);
        return false;
    }
    
    addrs = [[NSMutableArray alloc] init];
    id status = videoResult[@"playstatus"][@"status"];
    if([status integerValue] == 1){
        NSDictionary *streams = videoResult[@"playurl"][@"dispatch"];
        for(id key in streams){
            NSString *v = streams[key];
            if([key isEqualToString:@"1080p"]){
                [addrs addObject:@[@"高清-1080P",v]];
            }else if([key isEqualToString:@"720p"]){
                [addrs addObject:@[@"高清-720P",v]];
            }else{
                NSString *kname = [NSString stringWithFormat:@"%@Kbps",key];
                [addrs addObject:@[kname,v]];
            }
        }
    }else{
        NSLog(@"LETV Failed: %@",videoResult);
        return false;
    }
    
    return true;
}

- (void)showStreamSelect:(NSString *)videoId{
    bool suc = [self preloadLetvPlayAddr:videoId];
    if(!suc){
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"视频解析失败，请稍后再试。如果持续无法使用，请点击帮助 -> 反馈"];
        [alert runModal];
    }else{

        dispatch_async(dispatch_get_main_queue(), ^(void){
            NSString *path = [[NSBundle bundleForClass:[self class]]
                              pathForResource:@"selectStream" ofType:@"nib"];
            streamSelPanel =[[NSWindowController alloc] initWithWindowNibPath:path owner:self];
            [streamSelPanel showWindow:self];
            NSLog(@"showWindow");
        });
    }
}

- (bool)canHandleEvent:(NSString *)eventName{
    // Eventname format is pluginName-str
    if([eventName isEqualToString:@"letv-playvideo"]){
        return true;
    }
    return false;
}

- (NSString *)processEvent:(NSString *)eventName :(NSString *)eventData{
    
    if([eventName isEqualToString:@"letv-playvideo"]){
        [self showStreamSelect:eventData];
    }else if([eventName isEqualToString:@"letv-playInApp"]){
        return eventData; // return video url to play
    }else if([eventName isEqualToString:@"letv-playQuickTime"]){
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/open";
        task.arguments = @[@"-a",@"QuickTime Player",eventData];
        [task launch];
    }
    
    return NULL;
}

- (void)openSettings{
    NSLog(@"Show letv settings");
    dispatch_async(dispatch_get_main_queue(), ^(void){
        
        NSString *path = [[NSBundle bundleForClass:[self class]]
                          pathForResource:@"Settings" ofType:@"nib"];
        settingsPanel =[[NSWindowController alloc] initWithWindowNibPath:path owner:self];
        [settingsPanel showWindow:self];
    });
    return;
}


- (IBAction)internalPlay:(id)sender {
    
}

- (IBAction)qtPlay:(id)sender {
    
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex {
    if([addrs count] <= rowIndex){
        return NO;
    }
    NSArray *object = [addrs objectAtIndex:rowIndex];
    if(!object){
        return NO;
    }
    sel_addr = [object objectAtIndex:1];
    [self.internalPlayBtn setEnabled:YES];
    [self.QTPlayBtn setEnabled:YES];
    return YES;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView{
    return addrs.count;
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex{
    if([addrs count] <= rowIndex){
        return @"读取中";
    }
    NSArray *object = [addrs objectAtIndex:rowIndex];
    if(!object){
        return @"ERROR";
    }
    if([[aTableColumn identifier] isEqualToString:@"c_addr"]){
        return [[object objectAtIndex:1] objectAtIndex:0];
    }else{
        return [object objectAtIndex:0];
    }
}

@end

