/* MAPIStoreVolatileMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSString+Utilities.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/NSString+Mail.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreMailFolder.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIVolatileMessage.h"

#import "MAPIStoreVolatileMessage.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

Class NSNumberK;

@implementation MAPIStoreVolatileMessage

+ (void) initialize
{
  NSNumberK = [NSNumber class];
}

- (id) init
{
  if ((self = [super init]))
    fetchedAttachments = NO;

  return self;
}

- (int) addPropertiesFromRow: (struct SRow *) aRow
{
  int rc;

  rc = [super addPropertiesFromRow: aRow];
  if (rc == MAPISTORE_SUCCESS)
    {
      [sogoObject appendProperties: properties];
      [properties removeAllObjects];
    }

  return rc;
}

- (void) addProperties: (NSDictionary *) newProperties
{
  [super addProperties: newProperties];
  [sogoObject appendProperties: newProperties];
  [properties removeAllObjects];
}

- (uint64_t) objectVersion
{
  NSNumber *version;

  version = [[sogoObject properties] objectForKey: @"version"];

  return (version
          ? exchange_globcnt ([version unsignedLongLongValue])
          : ULLONG_MAX);
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
           inMemCtx: (TALLOC_CTX *) memCtx
{
  id value;
  int rc;
 
  value = [[sogoObject properties] objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getMAPIValue: data forTag: propTag inMemCtx: memCtx];
  else
    rc = [super getProperty: data withTag: propTag inMemCtx: memCtx];

  return rc;
}

- (int) getPrSubject: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  /* if we get here, it means that the properties file didn't contain a
     relevant value */
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPrMessageClass: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.Note" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrChangeKey: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  NSData *changeKey;
  int rc;

  changeKey = [[sogoObject properties]
                objectForKey: MAPIPropertyKey (PR_CHANGE_KEY)];
  if (changeKey)
    {
      *data = [changeKey asBinaryInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = [super getPrChangeKey: data inMemCtx: memCtx];

  return rc;
}

- (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSArray *keys;
  NSUInteger count, max;
  NSString *key;
  struct SPropTagArray *availableProps;

  keys = [[sogoObject properties] allKeys];
  max = [keys count];

  availableProps = talloc_zero (NULL, struct SPropTagArray);
  availableProps->cValues = max;
  availableProps->aulPropTag = talloc_array (availableProps, enum MAPITAGS, max);
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      if ([key isKindOfClass: NSNumberK])
        {
#if (GS_SIZEOF_LONG == 4)
          availableProps->aulPropTag[count] = [[keys objectAtIndex: count] unsignedLongValue];
#elif (GS_SIZEOF_INT == 4)
          availableProps->aulPropTag[count] = [[keys objectAtIndex: count] unsignedIntValue];
#endif
        }
    }

  *propertiesP = availableProps;

  return MAPISTORE_SUCCESS;  
}

- (NSArray *) attachmentsKeysMatchingQualifier: (EOQualifier *) qualifier
                              andSortOrderings: (NSArray *) sortOrderings
{
  NSDictionary *attachments;
  NSArray *keys;
  NSString *key, *newKey;
  NSUInteger count, max, aid;
  MAPIStoreAttachment *attachment;

  if (!fetchedAttachments)
    {
      attachments = [[sogoObject properties] objectForKey: @"attachments"];
      keys = [attachments allKeys];
      max = [keys count];
      if (max > 0)
        {
          aid = [keys count];
          for (count = 0; count < max; count++)
            {
              key = [keys objectAtIndex: count];
              attachment = [attachments objectForKey: key];
              newKey = [NSString stringWithFormat: @"%ul", (aid + count)];
              [attachmentParts setObject: attachment forKey: newKey];
            }
        }
      fetchedAttachments = YES;
    }

  return [super attachmentKeysMatchingQualifier: qualifier
                               andSortOrderings: sortOrderings];
}

- (void) save
{
  [self subclassResponsibility: _cmd];
}

@end