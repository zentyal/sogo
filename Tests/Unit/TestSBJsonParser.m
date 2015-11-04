/* TestSBJsonParser.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <SBJson/SBJsonParser.h>

#import "SOGo/NSString+Utilities.h"

#import <SBJson/SBJsonParser.h>
#import "../../SoObjects/SOGo/BSONCodec.h"

#import "SOGoTest.h"

@interface TestSBJsonParser : SOGoTest
@end

@implementation TestSBJsonParser

- (NSData *) get_plist: (NSString *) file
{
    NSString *file_path = [NSString stringWithFormat: @"%@.bson", file];
    if(![[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
        NSString *error = [NSString stringWithFormat: @"File %@ doesn't exist", file_path];
        testWithMessage(false, error);
    }
    return [NSData dataWithContentsOfFile: file_path];
}

- (void) print: (NSString *) m
{
    fprintf(stderr, "%s\n", [m UTF8String]);
}

- (void) to_plist: (NSData *) data
               as: (NSString *) file
{
    NSString *file_path = [NSString stringWithFormat: @"%@.filtered", file];
    [[NSFileManager defaultManager] createFileAtPath: file_path
                                            contents: data
                                          attributes: nil];
}


- (void) test_foobar
{
    NSString *error;
    NSData *data;
    NSDictionary *newValues;
    NSMutableDictionary *dict;
    NSString *file;
    NSNumberFormatter *f;
    id item;

    file = [NSString stringWithFormat: @"/tmp/foo"];

    data = [self get_plist: file];

    newValues = [NSDictionary BSONFragment: data at: NULL ofType: 0x03];
    dict = [newValues mutableCopy];

    /*f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    for(id key in dict) {
        NSNumber *number = [f numberFromString:key];
        [self print: [NSString stringWithFormat: @"0x%llX", [number unsignedLongLongValue]]];
    }*/

    [self print: [NSString stringWithFormat: @"Size is %d", [dict count]]];
    [self print: [NSString stringWithFormat: @"%@", dict]];

    // Modify properties
    /*[dict removeObjectForKey: [NSString stringWithFormat: @"%lld", 0x68330048]];
    [dict removeObjectForKey: [NSString stringWithFormat: @"%lld", 0x683F0102]];
    [dict removeObjectForKey: [NSString stringWithFormat: @"%lld", 0x70030003]];*/

    //[dict removeObjectForKey: [NSString stringWithFormat: @"%lld", 0x68340003]];
    //[dict removeObjectForKey: [NSString stringWithFormat: @"%lld", 0x683A0003]];

    //[dict removeObjectForKey: [NSString stringWithFormat: @"%lld", 0x68350102]];
    /*item = [dict objectForKey: [NSString stringWithFormat: @"%lld", 0x68350102]];
    NSMutableData *data = [[NSMutableData alloc] initWithData:item];
    NSRange *range = NSMakeRange(0, );
    [data ]*/

/*
    +PR_VD_FLAGS	PT_LONG	0
+PR_VD_NAME_W	PT_UNICODE	Messages
+PR_VD_VERSION	PT_LONG	65544
+PR_VIEW_CLSID	PT_CLSID	{00062000-0000-0000-C000-000000000046}
*/
/*
    const unsigned char bytes[] = {0x00, 0x20, 0x06, 0x00, 0x00, 0x00, 0x00,
                                   0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00,
                                   0x00, 0x46};
    NSData *clsid = [NSData dataWithBytes:bytes length:sizeof(bytes)];

    [dict setObject: @"Messages"
             forKey: [NSString stringWithFormat: @"%lld", 0x7006001F]];
    [dict setObject: [NSNumber numberWithUnsignedLongLong: 0]
             forKey: [NSString stringWithFormat: @"%lld", 0x70030003]];
    [dict setObject: [NSNumber numberWithUnsignedLongLong: 65544]
             forKey: [NSString stringWithFormat: @"%lld", 0x70070003]];
    [dict setObject: clsid
             forKey: [NSString stringWithFormat: @"%lld", 0x683330048]];

    [self print: [NSString stringWithFormat: @"Size is %d", [dict count]]];

    [self to_plist: [dict BSONEncode] as: file];
*/
}




@end
