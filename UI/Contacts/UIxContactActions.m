/* UIxContactActions.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/CardElement+Json.h>
#import <NGCards/NGVCard.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoPermissions.h>
#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSList.h>

#import <Common/WODirectAction+SOGo.h>

@interface NGVCard (SOGoActionCategory)

- (BOOL) addOrRemove: (BOOL) set
            category: (NSString *) newCategory;

@end

@implementation NGVCard (SOGoActionCategory)

- (BOOL) addOrRemove: (BOOL) set
            category: (NSString *) category
{
  NSMutableArray *categories;
  BOOL modified;
  NSUInteger idx;

  modified = NO;

  categories = [[self categories] mutableCopy];
  [categories autorelease];
  if (!categories)
    categories = [NSMutableArray array];
  if (set)
    {
      if (![categories containsObject: category])
        {
          [categories addObject: category];
          modified = YES;
        }
    }
  else
    {
      idx = [categories indexOfObject: category];
      if (idx != NSNotFound)
        {
          [categories removeObjectAtIndex: idx];
          modified = YES;
        }
    }

  if (modified)
    [self setCategories: categories];

  return modified;
}

@end

@interface UIxContactActions : WODirectAction

- (WOResponse *) setCategoryAction;
- (WOResponse *) unsetCategoryAction;

@end

@implementation UIxContactActions

- (WOResponse *) _setOrUnsetCategoryAction: (BOOL) set
{
  SOGoContactGCSEntry *contact;
  NSString *category;
  WORequest *rq;
  WOResponse *response;
  NGVCard *card;

  rq = [context request];
  category = [rq formValueForKey: @"category"];
  if ([category length] > 0)
    {
      contact = [self clientObject];
      if (![contact isNew])
        {
          card = [contact vCard];
          if ([card addOrRemove: set category: category])
            [contact save];
          response = [self responseWith204];
        }
      else
        response = [self responseWithStatus: 404
                                  andString: @"Contact does not exist"];
    }
  else
    response = [self responseWithStatus: 403
                              andString: @"Missing 'category' parameter"];

  return response;
}

- (WOResponse *) setCategoryAction
{
  return [self _setOrUnsetCategoryAction: YES];
}

- (WOResponse *) unsetCategoryAction
{
  return [self _setOrUnsetCategoryAction: NO];
}

// returns the raw content of the object
- (WOResponse *) rawAction
{
  NSMutableString *content;
  WOResponse *response;
  NSString *type;

  content = [NSMutableString string];
  response = [context response];

  [content appendFormat: [[self clientObject] contentAsString]];
  if ([[self clientObject] isKindOfClass: [SOGoContactGCSEntry class]])
      type = @"x-vcard";
  else if ([[self clientObject] isKindOfClass: [SOGoContactGCSList class]])
      type = @"x-vlist";
  else
      [NSException raise: @"SOGoException"
                   format: @"unhandled object class"];
  [response setHeader: [NSString stringWithFormat: @"text/%@; charset=utf-8",
                                 type]
            forKey: @"content-type"];
  [response appendContentString: content];

  return response;
}

- (WOResponse *) jsonAction
{
  WOResponse *response;
  id co, component;
  NSDictionary *rendering;

  co = [self clientObject];
  if ([co isKindOfClass: [SOGoContactGCSEntry class]])
    component = [co vCard];
  else if ([[self clientObject] isKindOfClass: [SOGoContactGCSList class]])
    component = [co vList];
  else
    [NSException raise: @"SOGoException"
                format: @"unhandled object class"];

  WORequest *rq = [context request];
  if ([[rq method] isEqualToString: @"GET"])
    {
      rendering = [component jsonDictionary];
      response = [self responseWithStatus: 200
                    andJSONRepresentation: rendering];
    }
  else if ([[rq method] isEqualToString: @"POST"])
  {
      NSArray *headers;
      NSString *contentType;

      headers = [rq headersForKey: @"content-type"];
      if ([headers count] > 0)
          contentType = [headers objectAtIndex: 0];
      else
          contentType = nil;

      if ([contentType hasPrefix: @"application/json"])
        {
          SoSecurityManager *sm;

          sm = [SoSecurityManager sharedSecurityManager];
          if (([co isNew]
               && [sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
                      onObject: [co container]
                      inContext: context])
              || (![co isNew]
                  && [sm validatePermission: SoPerm_ChangeImagesAndFiles
                      onObject: co
                         inContext: context]))
            response = (WOResponse *) [NSException exceptionWithHTTPStatus: 403
                                                   reason: @"Operation denied"];
          else
            {
              [component parseFromJsonString: [rq contentAsString]];
              response = (WOResponse *) [co save];
              if (!response)
                {
                  if ([co isNew])
                    response = [self responseWithStatus: 201];
                  else
                    response = [self responseWith204];
                }
            }
        }
      else
        response = [self responseWithStatus: 403
                                  andString: @"expected 'application/json'"];
  }

  return response;
}

@end
