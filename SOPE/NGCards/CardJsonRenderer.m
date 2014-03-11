/* CardJsonRenderer.m - this file is part of SOPE
 *
 * Copyright (C) 2014 Zentyal
 *
 * Author: Wolfgang Sourdeau <wolfgang@contre.com>
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import "CardElement.h"
#import "CardGroup.h"

#import "NSString+NGCards.h"
#import "NSDictionary+NGCards.h"

#import "CardJsonRenderer.h"

@interface CardJsonRenderer (PrivateAPI)

- (NSDictionary *) renderProperty: (CardElement *) anElement;
- (NSDictionary *) renderComponent: (CardGroup *) aComponent;

@end

@implementation CardJsonRenderer

- (NSDictionary *) render: (id) anElement
{
  NSDictionary *dict;

  if ([anElement isKindOfClass: [CardGroup class]])
    dict = [self renderComponent: anElement];
  else
    dict = [self renderProperty: anElement];

  return dict;
}

- (NSDictionary *) renderProperty: (CardElement *) aProperty
{
  NSMutableDictionary *propertyDict;
  NSMutableString *propertyKey;
  NSMutableDictionary *attributes;
  NSMutableDictionary *valuesDict;
  NSArray *keys, *values;
  NSString *tag, *key, *lowerKey;
  NSUInteger count, max;

  if ([aProperty isVoid])
    propertyDict = nil;
  else
    {
      propertyDict = [NSMutableDictionary dictionaryWithCapacity: 8];

      propertyKey = [NSMutableString new];
      if ([aProperty group])
        [propertyKey appendFormat: @"%@.", [aProperty group]];
      tag = [aProperty tag];
      if (![tag length])
        {
          tag = @"<no-tag>";
          [self warnWithFormat: @"card property of class '%@' has an empty tag",
                NSStringFromClass([aProperty class])];
        }
      [propertyKey appendString: [tag lowercaseString]];
      [propertyDict setObject: propertyKey forKey: @"tag"];
      [propertyKey release];

      /* parameters */
      attributes = [[aProperty attributes] mutableCopy];
      max = [attributes count];
      if (max > 0)
        {
          keys = [attributes allKeys];
          for (count = 0; count < max; count++)
            {
              key = [keys objectAtIndex: count];
              lowerKey = [key lowercaseString];
              [attributes setObject: [attributes objectForKey: key]
                             forKey: lowerKey];
              if (![key isEqualToString: lowerKey])
                  [attributes removeObjectForKey: key];
            }
          [propertyDict setObject: attributes forKey: @"parameters"];
        }
      [attributes release];

      valuesDict = [[aProperty values] mutableCopy];

      /* values */
      values = [valuesDict objectForKey: @""];
      if ([values count])
        [propertyDict setObject: values forKey: @"values"];

      /* named values */
      [valuesDict removeObjectForKey: @""];
      if ([valuesDict count])
        [propertyDict setObject: valuesDict forKey: @"named-values"];
      [valuesDict release];
    }

  return propertyDict;
}

- (NSDictionary *) renderComponent: (CardGroup *) aComponent
{
  NSMutableDictionary *componentDict;
  NSMutableArray *jsonChildren;
  NSDictionary *currentChild;
  NSArray *children;
  NSUInteger count, max;
  NSString *tag;

  children = [aComponent children];
  max = [children count];
  if (max == 0)
    componentDict = nil;
  else
    {
      componentDict = [NSMutableDictionary dictionaryWithCapacity: 2];

      tag = [aComponent tag];
      if (![tag length])
        {
          tag = @"<no-tag>";
          [self warnWithFormat: @"card group of class '%@' has an empty tag",
                NSStringFromClass([aComponent class])];
        }
      [componentDict setObject: [tag lowercaseString] forKey: @"tag"];

      jsonChildren = [[NSMutableArray alloc] initWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          currentChild = [self render: [children objectAtIndex: count]];
          [jsonChildren addObject: currentChild];
        }
      [componentDict setObject: jsonChildren forKey: @"properties"];
      [jsonChildren release];
    }

  return componentDict;
}

@end
