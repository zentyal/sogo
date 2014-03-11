/* CardJsonParser.m - this file is part of SOPE
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

#import <SBJson/SBJsonParser.h>

#import "CardJsonRenderer.h"

#import "CardElement+Json.h"


@implementation CardElement (CardJsonParsing)

- (NSDictionary *) jsonDictionary
{
  NSDictionary *jsonDict;
  CardJsonRenderer *renderer;

  renderer = [CardJsonRenderer new];
  jsonDict = [renderer render: self];
  [renderer release];

  return jsonDict;
}

- (void) parseFromJsonString: (NSString *) aString
{
  NSDictionary *dict;
  SBJsonParser *parser;

  parser = [SBJsonParser new];
  [parser autorelease];

  dict = [parser objectWithString: aString];
  if (![dict isKindOfClass: [NSDictionary class]])
    [NSException raise: @"NGCardsException"
                format: @"resulting object is not a dictionary"];
  [self parseFromJsonDictionary: dict];
}

- (void) parseFromJsonDictionary: (NSDictionary *) aDict
{
  NSArray *jsonValues;
  NSMutableArray *jsonSubValues;
  NSMutableDictionary *jsonNamed;
  NSUInteger count, max;

  [self clear];

  [self setTag: [aDict objectForKey: @"tag"]];

  jsonNamed = [[aDict objectForKey: @"named-values"] mutableCopy];
  max = [jsonNamed count];
  if (max > 0)
    [self setValues: jsonNamed];
  [jsonNamed release];

  jsonValues = [aDict objectForKey: @"values"];
  max = [jsonValues count];
  for (count = 0; count < max; count++)
    {
      jsonSubValues = [[jsonValues objectAtIndex: count] mutableCopy];
      [self setValues: jsonSubValues atIndex: count forKey: @""];
      [jsonSubValues release];
    }

  jsonNamed = [[aDict objectForKey: @"parameters"] mutableCopy];
  if ([jsonNamed count] > 0)
    [self addAttributes: jsonNamed];
  [jsonNamed release];
}

@end


@implementation CardGroup (CardJsonParsing)

- (void) parseFromJsonDictionary: (NSDictionary *) aDict
{
  NSArray *properties;
  NSUInteger count, max;

  [self clear];

  [self setTag: [aDict objectForKey: @"tag"]];

  properties = [aDict objectForKey: @"properties"];
  max = [properties count];
  for (count = 0; count < max; count++)
    {
      CardElement *newElement = [CardElement new];
      [newElement parseFromJsonDictionary:
                      [properties objectAtIndex: count]];
      [self addChild: newElement];
      [newElement release];
    }
}

@end
