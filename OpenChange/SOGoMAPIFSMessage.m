/* SOGoMAPIFSMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import "SOGoMAPIFSFolder.h"

#import "SOGoMAPIFSMessage.h"

@implementation SOGoMAPIFSMessage

- (id) init
{
  if ((self = [super init]))
    {
      propertiesLoaded = NO;
      completeFilename = nil;
    }

  return self;
}

- (void) dealloc
{
  [completeFilename release];
  [super dealloc];
}

- (Class) mapistoreMessageClass
{
  NSArray *dirMembers;
  NSString *className;

  /* FIXME: this method is a bit dirty */
  dirMembers = [[container directory] componentsSeparatedByString: @"/"];
  if ([dirMembers containsObject: @"fai"]) /* should not occur as FAI message
                                              are instantiated directly in
                                              MAPIStoreFolder */
    className = @"MAPIStoreFAIMessage";
  else if ([dirMembers containsObject: @"notes"])
    className = @"MAPIStoreNotesMessage";
  else
    className = @"MAPIStoreFSMessage";

  return NSClassFromString (className);
}

- (NSString *) completeFilename
{
  if (!completeFilename)
    {
      completeFilename = [[container directory]
                           stringByAppendingPathComponent: nameInContainer];
      [completeFilename retain];
    }

  return completeFilename;
}

- (NSMutableDictionary *) properties
{
  NSData *content;
  NSString *error;
  NSPropertyListFormat format;

  if (!propertiesLoaded)
    {
      content = [NSData dataWithContentsOfFile: [self completeFilename]];
      if (content)
        {
          properties = [NSPropertyListSerialization propertyListFromData: content
                                                        mutabilityOption: NSPropertyListMutableContainers
                                                                  format: &format
                                                        errorDescription: &error];
          [properties retain];
          if (!properties)
            [self logWithFormat: @"an error occurred during deserialization"
                  @" of message: '%@'", error];
        }

      propertiesLoaded = YES;
    }

  return [super properties];
}

- (void) save
{
  NSData *content;

  [container ensureDirectory];

  // [self logWithFormat: @"%d props in whole dict", [properties count]];

  content = [NSPropertyListSerialization
              dataFromPropertyList: [self properties]
                            format: NSPropertyListBinaryFormat_v1_0
                  errorDescription: NULL];
  if (![content writeToFile: [self completeFilename] atomically: NO])
    [NSException raise: @"MAPIStoreIOException"
		 format: @"could not save message"];
  // [self logWithFormat: @"fs message written to '%@'", [self completeFilename]];
}

- (NSString *) davEntityTag
{
  NSCalendarDate *lm;

  lm = [self lastModificationTime];

  return [NSString stringWithFormat: @"%d", (int) [lm timeIntervalSince1970]];
}

- (NSException *) delete
{
  NSFileManager *fm;
  NSException *error;
  
  fm = [NSFileManager defaultManager];

  if (![fm removeFileAtPath: [self completeFilename] handler: NULL])
    error = [NSException exceptionWithName: @"MAPIStoreIOException"
                                    reason: @"could not delete message"
                                  userInfo: nil];
  else
    error = nil;

  return error;
}

- (id) _fileAttributeForKey: (NSString *) key
{
  NSDictionary *attributes;

  attributes = [[NSFileManager defaultManager]
                   fileAttributesAtPath: [self completeFilename]
                           traverseLink: NO];

  return [attributes objectForKey: key];
}

- (NSCalendarDate *) creationTime
{
  return [self _fileAttributeForKey: NSFileCreationDate];
}

- (NSCalendarDate *) lastModificationTime
{
  return [self _fileAttributeForKey: NSFileModificationDate];
}

@end
