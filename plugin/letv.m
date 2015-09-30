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
    NSString *sel_addr;
    NSString *sel_streamid;
    NSString *evt_videoid;
    NSString *m3u8_addr;
}

@property (strong) NSWindowController* settingsPanel;
@property (strong) NSWindowController* streamSelPanel;
@property (weak) IBOutlet NSButton *internalPlayBtn;
@property (weak) IBOutlet NSButton *QTPlayBtn;
@property (weak) IBOutlet NSTextField *loadText;

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

const char * letv_decryptM3U8(const char *resdata,size_t alen){
    char *l1;
    char *l2;
    l1 = strstr(resdata,"VC_01");
    l2 = strstr(resdata,"vc_01");
    if(!l1 && !l2){
        return resdata; // Not encrypted
    }else{
        int datalen = (int)alen - 5;
        char m3u8data[datalen];
        memcpy(m3u8data, resdata + 5, sizeof(m3u8data));
        
        char fkres[datalen*2];
        for(int i = 0; i < datalen ; i++){
            fkres[2*i] = (unsigned char)m3u8data[i] >> 0x4;
            fkres[2*i+1]= (unsigned char)m3u8data[i] & 0xf;
        }
        int alllen = (int)sizeof(fkres);
        int sublen = (int)(alllen - 11);
        char *fkres_ptr = &fkres[0];
        char swappedData[datalen*3];
        memcpy(swappedData, fkres_ptr + sublen, alllen - sublen);
        memcpy(swappedData + (alllen - sublen), fkres_ptr, sublen);
        
        char realM3u8Data[datalen];
        for(int i = 0; i < datalen ; i++){
            realM3u8Data[i] = (swappedData[2 * i] << 4) + swappedData[2*i+1];
        }
        char* p = &realM3u8Data[0];
        return (const char *)p;
    }
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
    evt_videoid = videoId;
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
            NSString *v = [streams[key] objectAtIndex:0];
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
    if([eventName containsString:@"letv-"]){
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


- (void)callSelf:(NSString *)name event:(NSString *)event{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [settingsPanel close];
        NSURL* URL = [NSURL URLWithString:@"http://localhost:23330/pluginCall"];
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSDictionary* bodyObject = @{
                                     @"action": name,
                                     @"data": event
                                     };
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyObject options:kNilOptions error:NULL];
        NSURLConnection* connection = [NSURLConnection connectionWithRequest:request delegate:nil];
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop]
                              forMode:NSDefaultRunLoopMode];
        [connection start];
    });
}

- (IBAction)internalPlay:(id)sender {
    [self callSelf:@"letv-playInApp" event:sel_addr];
}

- (IBAction)qtPlay:(id)sender {
    [self callSelf:@"letv-playQuickTime" event:sel_addr];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex {
    if([addrs count] <= rowIndex){
        return NO;
    }
    NSArray *object = [addrs objectAtIndex:rowIndex];
    if(!object){
        return NO;
    }
    [self.internalPlayBtn setEnabled:NO];
    [self.QTPlayBtn setEnabled:NO];
    sel_streamid = [[[[object objectAtIndex:0]
                    stringByReplacingOccurrencesOfString:@"高清-" withString:@""]
                    stringByReplacingOccurrencesOfString:@"Kbps" withString:@""]
                                                                lowercaseString];
    sel_addr = [object objectAtIndex:1];
    
    [self.loadText setStringValue:@"解析中"];
    
    NSString *str = [NSString stringWithFormat:@"http://g3.letv.cn%@&ctv=pc&m3v=1&termid=1&format=1&hwtype=un&ostype=MacOS10.11.0&tag=letv&sign=letv&expect=3&tn=%u&pay=0&iscpn=f9051&rateid=%@",
                     sel_addr,arc4random(),sel_streamid];
    NSLog(@"VideoMetaData URL %@",str);
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
    NSData * playJSONData = [NSURLConnection sendSynchronousRequest:request
                                                          returningResponse:&response
                                                                      error:&error];
    if(error || !playJSONData){
        [self.loadText setStringValue:@"网络错误"];
        return NO;
    }

    NSError *jsonError;
    NSDictionary *videoResult = [NSJSONSerialization JSONObjectWithData:playJSONData options:NSJSONReadingMutableContainers error:&jsonError];
    
    if(jsonError){
        [self.loadText setStringValue:@"JSON 错误"];
        NSLog(@"JSON ERROR:%@",jsonError);
        return NO;
    }
    
    m3u8_addr = videoResult[@"location"];
    
    if(!m3u8_addr){
        [self.loadText setStringValue:@"解析失败"];
        return NO;
    }
    
    [self.loadText setStringValue:@"载入流信息"];
    
    URL = [NSURL URLWithString:m3u8_addr];
    request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"GET";

    if([xff length] > 4){
        [request setValue:xff forHTTPHeaderField:@"X-Forwarded-For"];
        [request setValue:xff forHTTPHeaderField:@"Client-IP"];
    }
    
    [request addValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.99 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
    
    NSData * playM3U8Data = [NSURLConnection sendSynchronousRequest:request
                                                  returningResponse:&response
                                                              error:&error];
    if(error || !playM3U8Data){
        [self.loadText setStringValue:@"网络错误"];
        return NO;
    }
    
    [self.loadText setStringValue:@"解密流信息"];
    
    const char *result = letv_decryptM3U8([playM3U8Data bytes],[playM3U8Data length]);
    NSData *data = [NSData dataWithBytes:result length:[playM3U8Data length]];
    
    
    NSString *path = [NSString stringWithFormat:@"%@letv_%@_%@.m3u8",NSTemporaryDirectory(),evt_videoid,sel_streamid];
    
    [data writeToFile:path atomically:YES];
    
    sel_addr = [[NSURL URLWithString:path] absoluteString];
    
    [self.loadText setStringValue:@""];
    
    [self.internalPlayBtn setEnabled:YES];
    //[self.QTPlayBtn setEnabled:YES];
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
        return [object objectAtIndex:1];
    }else{
        return [object objectAtIndex:0];
    }
}

@end

