//
//  vp_letv_test.m
//  vp.letv.test
//
//  Created by TYPCN on 2015/9/26.
//  Copyright © 2015 TYPCN. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "letv.h"

@interface vp_letv_test : XCTestCase{
    letv *le;
}

@end

@implementation vp_letv_test

- (void)setUp {
    [super setUp];
    le = [[letv alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testVideo {

    
    [le processEvent:@"letv-playvideo" :@"23075561"];
}

- (void)testDecrypt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"testdata" ofType:@"m3u8"];
    NSData *encrypted_m3u8 = [NSData dataWithContentsOfFile:path];
    
    
    const char *result = letv_decryptM3U8([encrypted_m3u8 bytes],[encrypted_m3u8 length]);
    NSData *data = [NSData dataWithBytes:result length:[encrypted_m3u8 length]];
    free(result);
    NSString* newStr = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSLog(@"Result: %@",newStr);
}

@end
