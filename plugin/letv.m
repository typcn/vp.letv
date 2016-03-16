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
    bool    asyncOpStatus;
}

@property (strong) NSWindowController* settingsPanel;
@property (strong) NSWindowController* streamSelPanel;
@property (strong) IBOutlet NSWindow *selWindow;
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
        char *fkres = malloc(datalen*2);
        for(int i = 0; i < datalen ; i++){
            fkres[2*i] = (unsigned char)m3u8data[i] >> 0x4;
            fkres[2*i+1]= (unsigned char)m3u8data[i] & 0xf;
        }
        int alllen = datalen*2;
        int sublen = (alllen - 11);
        char *swappedData = malloc(alllen);
        memcpy(swappedData, fkres + sublen, alllen - sublen);
        memcpy(swappedData + (alllen - sublen), fkres, sublen);
        
        free(fkres);
        
        char *realM3u8Data = malloc(datalen+1);
        for(int i = 0; i < datalen ; i++){
            realM3u8Data[i] = (swappedData[2 * i] << 4) + swappedData[2*i+1];
        }
        realM3u8Data[datalen + 1] = '\0';
        
        free(swappedData);
        
        return (const char *)realM3u8Data;
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
    dispatch_async(dispatch_get_global_queue(0, 0), ^(void){
        bool suc = [self preloadLetvPlayAddr:videoId];
        if(!suc){
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"视频解析失败，请稍后再试。如果持续无法使用，请点击帮助 -> 反馈"];
            [alert runModal];
        }else{
            [self w_showStreamSelect];
        }
    });
}

- (void)w_showStreamSelect{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        NSString *path = [[NSBundle bundleForClass:[self class]]
                          pathForResource:@"selectStream" ofType:@"nib"];
        streamSelPanel =[[NSWindowController alloc] initWithWindowNibPath:path owner:self];
        [streamSelPanel showWindow:self];
    });
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
        [_selWindow close]; // small hack , get window by controller is always nil , connect delegate + create a new class delegate to nswindowcontroller not working..
        [streamSelPanel close];
        
        NSLog(@"m3u8 path: %@",event);
        
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

- (NSString *)getM3U8URL{
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
        return NULL;
    }
    
    NSError *jsonError;
    NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:playJSONData options:NSJSONReadingMutableContainers error:&jsonError];
    
    if(jsonError){
        NSLog(@"JSON ERROR:%@",jsonError);
        return NULL;
    }

    return jsonResult[@"location"];
}

- (NSData *)getM3U8Data{
    NSLog(@"VideoMetaData URL %@",m3u8_addr);
    NSURL* URL = [NSURL URLWithString:m3u8_addr];
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
    NSData * m3u8Data = [NSURLConnection sendSynchronousRequest:request
                                                  returningResponse:&response
                                                              error:&error];
    if(error || !m3u8Data){
        return NULL;
    }
    return m3u8Data;
}

- (void)setText:(NSString *)text{
    dispatch_async(dispatch_get_main_queue(), ^(void){
         [self.loadText setStringValue:text];
    });
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex {
    if([addrs count] <= rowIndex){
        return NO;
    }
    NSArray *object = [addrs objectAtIndex:rowIndex];
    if(!object){
        return NO;
    }
    if(asyncOpStatus){
        return NO;
    }
    asyncOpStatus = true;
    [self.internalPlayBtn setEnabled:NO];
    sel_streamid = [[[[object objectAtIndex:0]
                    stringByReplacingOccurrencesOfString:@"高清-" withString:@""]
                    stringByReplacingOccurrencesOfString:@"Kbps" withString:@""]
                                                                lowercaseString];
    sel_addr = [object objectAtIndex:1];
    
    [self setText:@"解析中"];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^(void){
        m3u8_addr = [self getM3U8URL];
        
        if(!m3u8_addr){
            [self setText:@"解析失败"];
            asyncOpStatus = false;
            return;
        }
        
        [self setText:@"载入流信息"];
        
        NSData * m3u8_data = [self getM3U8Data];
        if(!m3u8_data){
            [self setText:@"网络错误"];
            asyncOpStatus = false;
            return;
        }
        
        [self setText:@"解密流信息"];
        
        const char *result = letv_decryptM3U8([m3u8_data bytes],[m3u8_data length]);
        NSData *data = [NSData dataWithBytes:result length:[m3u8_data length]];
        NSString *path = [NSString stringWithFormat:@"%@bilimac_http_serv/letv_%@_%@.m3u8",NSTemporaryDirectory(),evt_videoid,sel_streamid];
        NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSString *strTo = @"#EXT-X-ENDLIST";
        if ([string containsString:strTo]) {
            NSRange range = [string rangeOfString:strTo];
            string = [string substringToIndex:range.location + strTo.length];
        }
        [string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        sel_addr = [NSString stringWithFormat:@"http://localhost:23330/temp_content/letv_%@_%@.m3u8",evt_videoid,sel_streamid];
        [self setText:@"解析成功"];
        [self.internalPlayBtn setEnabled:YES];
        
        asyncOpStatus = false;
    });
    
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

