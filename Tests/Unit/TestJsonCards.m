/* TestJsonCards.m - this file is part of $PROJECT_NAME_HERE$
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
#import <Foundation/NSDictionary.h>
#import <NGCards/CardJsonRenderer.h>
#import <NGCards/CardElement+Json.h>
#import <NGCards/CardGroup.h>

#import <SOGo/NSString+Utilities.h>

#import "SOGoTest.h"

@interface TestJsonCards : SOGoTest
@end

@implementation TestJsonCards

- (void) test_rendering
{
  CardElement *element;
  CardGroup *group;
  CardJsonRenderer *renderer;
  NSDictionary *result;

  renderer = [CardJsonRenderer new];
  [renderer autorelease];

  /* 1. simple value */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value" forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\","
               " \"values\": [[\"value\"]]}"
               objectFromJSONString]);

  /* 2. two values */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value2" atIndex: 1
                   forKey: @""];
  [element setSingleValue: @"value1" atIndex: 0
                   forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\","
               " \"values\": [[\"value1\"], [\"value2\"]]}"
               objectFromJSONString]);

  /* 3. one value with commma */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value1, with a comma" forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\","
               " \"values\": [[\"value1, with a comma\"]]}"
               objectFromJSONString]);

  /* 4. one value with a semicolon */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value1; with a semi-colon" forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\","
               " \"values\": [[\"value1; with a semi-colon\"]]}"
               objectFromJSONString]);

  /* 5. 3 named values:
       1. with multiple subvalues
       2. with commas
       3. with semicolon */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"1", @"2", @"3", nil]
           atIndex: 0 forKey: @"named1"];
  [element setSingleValue: @"1,2,3" forKey: @"named2"];
  [element setSingleValue: @"text1;text2" forKey: @"named3"];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\","
               " \"named-values\":"
               " {\"named1\": [[\"1\", \"2\", \"3\"]],"
               "  \"named2\": [[\"1,2,3\"]],"
               "  \"named3\": [[\"text1;text2\"]]}}"
               objectFromJSONString]);

  /* 6. values with 1 ordered value with a whitespace starting subvalues */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"", @"1", nil]
           atIndex: 0 forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\", \"values\": [[\"\", \"1\"]]}"
               objectFromJSONString]);

  /* 7. values with 1 ordered value with a subvalue, a whitespace and another
     subvalue */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"1", @"", @"2", nil]
           atIndex: 0 forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\", \"values\": [[\"1\", \"\", \"2\"]]}"
               objectFromJSONString]);

  /* 8.a. values with 1 empty ordered value and another non-empty one */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: nil]
           atIndex: 0 forKey: @""];
  [element setValues: [NSArray arrayWithObjects: @"1", nil]
           atIndex: 1 forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\", \"values\": [[], [\"1\"]]}"
               objectFromJSONString]);

  /* 8.b. a variant thereof: array with spaces */
  [element setValues: [NSArray arrayWithObjects: @"", @"", nil]
           atIndex: 0 forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\", \"values\": [[\"\", \"\"], [\"1\"]]}"
               objectFromJSONString]);

  /* 8.c. a variant thereof: nil array */
  [element setValues: nil atIndex: 0 forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\", \"values\": [[], [\"1\"]]}"
               objectFromJSONString]);

  /* 9. values with 1 non-empty ordered value and another empty one */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"1", nil]
           atIndex: 0 forKey: @""];
  [element setValues: [NSArray arrayWithObjects: nil]
           atIndex: 1 forKey: @""];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\", \"values\": [[\"1\"], []]}"
               objectFromJSONString]);

  /* 10. named values with 1 nil value, 1 empty value and another non-nil one */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: nil forKey: @"empty"];
  [element setSingleValue: nil forKey: @"empty2"];
  [element setSingleValue: @"coucou" forKey: @"nonempty"];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\","
               " \"named-values\":"
               "  {\"empty\": [[]],"
               "   \"empty2\": [[]],"
               "   \"nonempty\": [[\"coucou\"]]"
               "}}"
               objectFromJSONString]);

  /* 11. single values with 2 parameters */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value" forKey: @""];
  [element setValue: 1 ofAttribute: @"param" to: @"param-value"];
  result = [renderer render: element];
  testEquals(result,
             [@"{\"tag\": \"elem\","
               " \"values\": [[\"value\"]],"
               " \"parameters\": { \"param\": [\"\", \"param-value\"]}"
               "}"
               objectFromJSONString]);

  /* 12. a simple card group with 2 elements */
  group = [CardGroup elementWithTag: @"group"];
  element = [CardElement elementWithTag: @"elem1"];
  [element setSingleValue: @"pouet" forKey: @""];
  [group addChild: element];
  element = [CardElement elementWithTag: @"elem2"];
  [element setSingleValue: @"pouet" forKey: @""];
  [group addChild: element];
  result = [renderer render: group];
  testEquals(result,
             [@"{\"tag\": \"group\","
               " \"properties\":"
               "  [{\"tag\": \"elem1\","
               "    \"values\": [[\"pouet\"]]},"
               "   {\"tag\": \"elem2\","
               "    \"values\": [[\"pouet\"]]}]"
               "}"
                objectFromJSONString]);
}

- (void) test_parsing
{
  NSString *json;

  /* element parsing */
  {
      CardElement *element = [CardElement new];
      json = (@"{\"tag\": \"elem\","
              "  \"values\": [[\"value\"]],"
              "  \"named-values\": {\"name1\": [[\"value1\"]]},"
              "  \"parameters\": { \"param\": [\"\", \"param-value\"]}"
              "}");
      [element parseFromJsonString: json];
      testEquals([element tag], @"elem");
      NSArray *values = [element valuesAtIndex: 0 forKey: @""];
      testEquals(values, ([NSArray arrayWithObject: @"value"]));
      values = [element valuesAtIndex: 0 forKey: @"name1"];
      testEquals(values, ([NSArray arrayWithObject: @"value1"]));
      testEquals(@"", [element value: 0 ofAttribute: @"param"]);
      testEquals(@"param-value", [element value: 1 ofAttribute: @"param"]);
      [element release];
  }

  /* group parsing */
  {
      CardGroup *group = [CardGroup new];
      json = (@"{\"tag\": \"group\","
              "  \"properties\":"
              "   [{\"tag\": \"elem1\","
              "     \"values\": [[\"pouet\"]]},"
              "    {\"tag\": \"elem2\","
              "     \"values\": [[\"pouet\"]]}]"
              "}");
      [group parseFromJsonString: json];
      testEquals([group tag], @"group");

      NSArray *children = [group children];
      test([children count] == 2);
      testEquals([[children objectAtIndex: 0] tag], @"elem1");
      testEquals([[children objectAtIndex: 1] tag], @"elem2");

      [group release];
  }
}

@end
