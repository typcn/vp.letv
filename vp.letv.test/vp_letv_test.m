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


@end
