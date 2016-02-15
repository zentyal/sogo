/* NSData+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
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

#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreTypes.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "NSData+MAPIStore.h"

#undef DEBUG
#include <stdbool.h>
#include <libmapi/libmapi.h>
#include <talloc.h>
#include <util/time.h>
#include <gen_ndr/exchange.h>

@implementation NSData (MAPIStoreDataTypes)

+ (id) dataWithBinary: (const struct Binary_r *) binData
{
  return [NSData dataWithBytes: binData->lpb length: binData->cb];
}

- (struct Binary_r *) asBinaryInMemCtx: (void *) memCtx
{
  struct Binary_r *binary;

  binary = talloc_zero (memCtx, struct Binary_r);
  binary->cb = [self length];
  binary->lpb = (uint8_t *) [self bytes];
  [self tallocWrapper: binary];

  return binary;
}

+ (id) dataWithShortBinary: (const struct SBinary_short *) binData
{
  return [NSData dataWithBytes: binData->lpb length: binData->cb];
}

- (struct SBinary_short *) asShortBinaryInMemCtx: (void *) memCtx
{
  struct SBinary_short *binary;

  binary = talloc_zero (memCtx, struct SBinary_short);
  binary->cb = [self length];
  binary->lpb = (uint8_t *) [self bytes];
  [self tallocWrapper: binary];

  return binary;
}

+ (id) dataWithFlatUID: (const struct FlatUID_r *) flatUID
{
  return [NSData dataWithBytes: flatUID->ab length: 16];
}

- (struct FlatUID_r *) asFlatUIDInMemCtx: (void *) memCtx
{
  struct FlatUID_r *flatUID;

  flatUID = talloc_zero (memCtx, struct FlatUID_r);
  [self getBytes: flatUID->ab];

  return flatUID;
}

static void _fillFlatUIDWithGUID (struct FlatUID_r *flatUID, const struct GUID *guid)
{
  flatUID->ab[0] = (guid->time_low & 0xFF);
  flatUID->ab[1] = ((guid->time_low >> 8)  & 0xFF);
  flatUID->ab[2] = ((guid->time_low >> 16) & 0xFF);
  flatUID->ab[3] = ((guid->time_low >> 24) & 0xFF);
  flatUID->ab[4] = (guid->time_mid & 0xFF);
  flatUID->ab[5] = ((guid->time_mid >> 8)  & 0xFF);
  flatUID->ab[6] = (guid->time_hi_and_version & 0xFF);
  flatUID->ab[7] = ((guid->time_hi_and_version >> 8) & 0xFF);
  memcpy (flatUID->ab + 8,  guid->clock_seq, sizeof (uint8_t) * 2);
  memcpy (flatUID->ab + 10, guid->node, sizeof (uint8_t) * 6);
}

+ (id) dataWithGUID: (const struct GUID *) guid
{
  struct FlatUID_r flatUID;

  _fillFlatUIDWithGUID (&flatUID, guid);

  return [self dataWithFlatUID: &flatUID];
}

- (void) _extractGUID: (struct GUID *) guid
{
  uint8_t *bytes;

  bytes = (uint8_t *) [self bytes];

  guid->time_low = (bytes[3] << 24 | bytes[2] << 16
                    | bytes[1] << 8 | bytes[0]);
  guid->time_mid = (bytes[5] << 8 | bytes[4]);
  guid->time_hi_and_version = (bytes[7] << 8 | bytes[6]);
  memcpy (guid->clock_seq, bytes + 8, sizeof (uint8_t) * 2);
  memcpy (guid->node, bytes + 10, sizeof (uint8_t) * 6);
}

- (struct GUID *) asGUIDInMemCtx: (void *) memCtx
{
  struct GUID *guid;

  guid = talloc_zero (memCtx, struct GUID);
  [self _extractGUID: guid];

  return guid;
}

+ (id) dataWithXID: (const struct XID *) xid
{
  NSMutableData *xidData;
  struct FlatUID_r flatUID;

  _fillFlatUIDWithGUID (&flatUID, &xid->NameSpaceGuid);

  xidData = [NSMutableData dataWithCapacity: 16 + xid->LocalId.length];
  [xidData appendBytes: flatUID.ab length: 16];
  [xidData appendBytes: xid->LocalId.data length: xid->LocalId.length];

  return xidData;
}

- (struct XID *) asXIDInMemCtx: (void *) memCtx
{
  struct XID *xid;
  uint8_t *bytes;
  NSUInteger max;

  max = [self length];
  if (max > 16)
    {
      xid = talloc_zero (memCtx, struct XID);

      [self _extractGUID: &xid->NameSpaceGuid];

      xid->LocalId.length = max - 16;

      bytes = (uint8_t *) [self bytes];
      xid->LocalId.data = talloc_memdup (xid, (bytes+16), xid->LocalId.length);
    }
  else
    {
      xid = NULL;
      abort ();
    }

  return xid;
}

- (struct SizedXid *) asSizedXidArrayInMemCtx: (void *) memCtx
                                         with: (uint32_t *) length
{
  struct Binary_r bin;
  struct SizedXid *sizedXIDArray;

  bin.cb = [self length];
  bin.lpb = (uint8_t *)[self bytes];

  sizedXIDArray = get_SizedXidArray(memCtx, &bin, length);
  if (!sizedXIDArray)
    {
      NSLog (@"Impossible to parse SizedXID array");
      return NULL;
    }

  return sizedXIDArray;
}

- (NSComparisonResult) compare: (NSData *) otherGlobCnt
{
  uint64_t globCnt = 0, oGlobCnt = 0;

  if ([self length] > 0)
    globCnt = *(uint64_t *) [self bytes];

  if ([otherGlobCnt length] > 0)
      oGlobCnt = *(uint64_t *) [otherGlobCnt bytes];

  return MAPICNCompare (globCnt, oGlobCnt, NULL);
}

+ (id) dataWithChangeKeyGUID: (NSString *) guidString
                      andCnt: (NSData *) globCnt;
{
  NSMutableData *changeKey;
  struct GUID guid;

  changeKey = [NSMutableData dataWithCapacity: 16 + [globCnt length]];

  [guidString extractGUID: &guid];
  [changeKey appendData: [NSData dataWithGUID: &guid]];
  [changeKey appendData: globCnt];

  return changeKey;
}

- (void) hexDumpWithLineSize: (NSUInteger) lineSize
{
  const char *bytes;
  NSUInteger lineCount, count, max, charCount, charMax;
  NSMutableString *line;

  bytes = [self bytes];
  max = [self length];

  lineCount = 0;
  for (count = 0; count < max; count++)
    {
      line = [NSMutableString stringWithFormat: @"%d: ", lineCount];
      if (lineSize)
        {
          if ((max - count) > lineSize)
            charMax = lineSize;
          else
            charMax = max - count;
        }
      else
        charMax = max;
      for (charCount = 0; charCount < charMax; charCount++)
        [line appendFormat: @" %.2x", *(bytes + count + charCount)];
      [self logWithFormat: @"  %@", line];
      count += charMax;
      lineCount++;
    }
}

- (NSString *) globalObjectIdToUid: (void *) memCtx
{
  NSString *uid = nil;
  char *bytesDup, *uidStart;
  NSUInteger length;

  /* NOTE: we only handle the generic case at the moment, see
     MAPIStoreAppointmentWrapper */
  length = [self length];
  bytesDup = talloc_array (memCtx, char, length + 1);
  if (!bytesDup)
    {
      NSLog (@"%s: Out of memory");
      return nil;
    }
  memcpy (bytesDup, [self bytes], length);

  bytesDup[length] = 0;
  uidStart = bytesDup + length - 1;
  while (uidStart != bytesDup && *(uidStart - 1))
    uidStart--;
  if (uidStart > bytesDup && *uidStart)
    uid = [NSString stringWithUTF8String: uidStart];

  talloc_free (bytesDup);
  return uid;
}

@end

@implementation NSMutableData (MAPIStoreDataTypes)

- (void) appendUInt8: (uint8_t) value
{
  [self appendBytes: (char *) &value length: 1];
}

- (void) appendUInt16: (uint16_t) value
{
  NSUInteger count;
  char bytes[2];

  for (count = 0; count < 2; count++)
    {
      bytes[count] = value & 0xff;
      value >>= 8;
    }

  [self appendBytes: bytes length: 2];
}

- (void) appendUInt32: (uint32_t) value
{
  NSUInteger count;
  char bytes[4];

  for (count = 0; count < 4; count++)
    {
      bytes[count] = value & 0xff;
      value >>= 8;
    }

  [self appendBytes: bytes length: 4];
}

@end
