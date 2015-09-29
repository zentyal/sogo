/* MultiDomainLDAPSource.m - this file is part of SOGo
 *
 * Copyright (C) 2015 Jesús García Sáez
 *
 * Author: Jesús García Sáez <jgarcia@zentyal.com>
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

#include <ldap.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOControl.h>
#import <NGLdap/NGLdapConnection.h>
#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapEntry.h>
#import <NGLdap/NGLdapModification.h>
#import <NGLdap/NSString+DN.h>

#import "LDAPSourceSchema.h"
#import "NSArray+Utilities.h"
#import "NSString+Utilities.h"
#import "NSString+Crypto.h"
#import "SOGoCache.h"
#import "SOGoDomainDefaults.h"
#import "SOGoSystemDefaults.h"

#import "MultiDomainLDAPSource.h"
#import "../../Main/SOGo.h"

static Class NSStringK;

#define SafeLDAPCriteria(x) [[[x stringByReplacingString: @"\\" withString: @"\\\\"] \
                                 stringByReplacingString: @"'" withString: @"\\'"] \
                                 stringByReplacingString: @"%" withString: @"%%"]

@implementation MultiDomainLDAPSource

+ (void) initialize
{
  NSStringK = [NSString class];
}

+ (id) sourceFromUDSource: (NSDictionary *) udSource
                 inDomain: (NSString *) sourceDomain
{
  id newSource;

  newSource = [[self alloc] initFromUDSource: udSource
                                    inDomain: sourceDomain];
  [newSource autorelease];

  return newSource;
}

- (id) init
{
  if ((self = [super init]))
    {
      sourceID = nil;
      displayName = nil;

      bindDN = nil;
      password = nil;
      sourceBindDN = nil;
      sourceBindPassword = nil;
      hostname = nil;
      port = 389;
      encryption = nil;

      _baseDN = nil;
      schema = nil;
      IDField = @"cn";
      CNField = @"cn";
      UIDField = @"uid";
      mailFields = [NSArray arrayWithObject: @"mail"];
      [mailFields retain];
      contactMapping = nil;
      searchFields = [NSArray arrayWithObjects: @"sn", @"displayname",
                              @"telephonenumber", nil];
      [searchFields retain];
      groupObjectClasses = [NSArray arrayWithObjects: @"group", @"groupofnames",
                                    @"groupofuniquenames", @"posixgroup", nil];
      [groupObjectClasses retain];
      IMAPHostField = nil;
      IMAPLoginField = nil;
      SieveHostField = nil;
      bindFields = nil;
      _filter = nil;
      _userPasswordAlgorithm = nil;
      listRequiresDot = YES;

      searchAttributes = nil;
      passwordPolicy = NO;
      updateSambaNTLMPasswords = NO;

      kindField = nil;
      multipleBookingsField = nil;

      MSExchangeHostname = nil;

      modifiers = nil;
    }

  return self;
}

- (void) dealloc
{
  [schema release];
  [bindDN release];
  [password release];
  [sourceBindDN release];
  [sourceBindPassword release];
  [hostname release];
  [encryption release];
  [_baseDN release];
  [IDField release];
  [CNField release];
  [UIDField release];
  [contactMapping release];
  [mailFields release];
  [searchFields release];
  [groupObjectClasses release];
  [IMAPHostField release];
  [IMAPLoginField release];
  [SieveHostField release];
  [bindFields release];
  [_filter release];
  [_userPasswordAlgorithm release];
  [sourceID release];
  [modulesConstraints release];
  [searchAttributes release];
  [kindField release];
  [multipleBookingsField release];
  [MSExchangeHostname release];
  [modifiers release];
  [displayName release];
  [super dealloc];
}

- (id) initFromUDSource: (NSDictionary *) udSource
               inDomain: (NSString *) sourceDomain
{
  SOGoDomainDefaults *dd;
  NSNumber *udQueryLimit, *udQueryTimeout, *dotValue;

  if ((self = [self init]))
    {
      [self setSourceID: [udSource objectForKey: @"id"]];
      [self setDisplayName: [udSource objectForKey: @"displayName"]];

      [self setBindDN: [udSource objectForKey: @"bindDN"]
             password: [udSource objectForKey: @"bindPassword"]
             hostname: [udSource objectForKey: @"hostname"]
                 port: [udSource objectForKey: @"port"]
           encryption: [udSource objectForKey: @"encryption"]
    bindAsCurrentUser: [udSource objectForKey: @"bindAsCurrentUser"]];

      [self setBaseDN: [udSource objectForKey: @"baseDN"]
              IDField: [udSource objectForKey: @"IDFieldName"]
              CNField: [udSource objectForKey: @"CNFieldName"]
             UIDField: [udSource objectForKey: @"UIDFieldName"]
           mailFields: [udSource objectForKey: @"MailFieldNames"]
         searchFields: [udSource objectForKey: @"SearchFieldNames"]
   groupObjectClasses: [udSource objectForKey: @"GroupObjectClasses"]
        IMAPHostField: [udSource objectForKey: @"IMAPHostFieldName"]
       IMAPLoginField: [udSource objectForKey: @"IMAPLoginFieldName"]
       SieveHostField: [udSource objectForKey: @"SieveHostFieldName"]
           bindFields: [udSource objectForKey: @"bindFields"]
            kindField: [udSource objectForKey: @"KindFieldName"]
            andMultipleBookingsField: [udSource objectForKey: @"MultipleBookingsFieldName"]];

      dotValue = [udSource objectForKey: @"listRequiresDot"];
      if (dotValue)
        [self setListRequiresDot: [dotValue boolValue]];
      [self setContactMapping: [udSource objectForKey: @"mapping"]
             andObjectClasses: [udSource objectForKey: @"objectClasses"]];

      [self setModifiers: [udSource objectForKey: @"modifiers"]];

      if (sourceDomain)
        [self warnWithFormat: @"MultiDomainLDAPSource doesn't require a domain"];

      dd = [SOGoSystemDefaults sharedSystemDefaults];

      contactInfoAttribute
        = [udSource objectForKey: @"SOGoLDAPContactInfoAttribute"];
      if (!contactInfoAttribute)
        contactInfoAttribute = [dd ldapContactInfoAttribute];
      [contactInfoAttribute retain];

      udQueryLimit = [udSource objectForKey: @"SOGoLDAPQueryLimit"];
      if (udQueryLimit)
        queryLimit = [udQueryLimit intValue];
      else
        queryLimit = [dd ldapQueryLimit];

      udQueryTimeout = [udSource objectForKey: @"SOGoLDAPQueryTimeout"];
      if (udQueryTimeout)
        queryTimeout = [udQueryTimeout intValue];
      else
        queryTimeout = [dd ldapQueryTimeout];

      ASSIGN(modulesConstraints, [udSource objectForKey: @"ModulesConstraints"]);
      ASSIGN(_filter, [udSource objectForKey: @"filter"]);
      ASSIGN(_userPasswordAlgorithm, [udSource objectForKey: @"userPasswordAlgorithm"]);

      if (!_userPasswordAlgorithm)
        _userPasswordAlgorithm = @"none";

      if ([udSource objectForKey: @"passwordPolicy"])
        passwordPolicy = [[udSource objectForKey: @"passwordPolicy"] boolValue];

      if ([udSource objectForKey: @"updateSambaNTLMPasswords"])
        updateSambaNTLMPasswords = [[udSource objectForKey: @"updateSambaNTLMPasswords"] boolValue];

      ASSIGN(MSExchangeHostname, [udSource objectForKey: @"MSExchangeHostname"]);
    }

  return self;
}

- (void) setBindDN: (NSString *) theDN
{
  ASSIGN(bindDN, theDN);
}

- (NSString *) bindDN
{
  return bindDN;
}

- (void) setBindPassword: (NSString *) thePassword
{
  ASSIGN (password, thePassword);
}

- (NSString *) bindPassword
{
  return password;
}

- (BOOL) bindAsCurrentUser
{
  return _bindAsCurrentUser;
}

- (void) setBindDN: (NSString *) newBindDN
          password: (NSString *) newBindPassword
          hostname: (NSString *) newBindHostname
              port: (NSString *) newBindPort
        encryption: (NSString *) newEncryption
 bindAsCurrentUser: (NSString *) bindAsCurrentUser
{
  ASSIGN(bindDN, newBindDN);
  ASSIGN(password, newBindPassword);
  ASSIGN(sourceBindDN, newBindDN);
  ASSIGN(sourceBindPassword, newBindPassword);

  ASSIGN(encryption, [newEncryption uppercaseString]);
  if ([encryption isEqualToString: @"SSL"])
    port = 636;
  ASSIGN(hostname, newBindHostname);
  if (newBindPort)
    port = [newBindPort intValue];
  _bindAsCurrentUser = [bindAsCurrentUser boolValue];
}

- (void) setBaseDN: (NSString *) newBaseDN
           IDField: (NSString *) newIDField
           CNField: (NSString *) newCNField
          UIDField: (NSString *) newUIDField
        mailFields: (NSArray *) newMailFields
      searchFields: (NSArray *) newSearchFields
groupObjectClasses: (NSArray *) newGroupObjectClasses
     IMAPHostField: (NSString *) newIMAPHostField
    IMAPLoginField: (NSString *) newIMAPLoginField
    SieveHostField: (NSString *) newSieveHostField
        bindFields: (id) newBindFields
         kindField: (NSString *) newKindField
  andMultipleBookingsField: (NSString *) newMultipleBookingsField
{
  ASSIGN(_baseDN, [newBaseDN lowercaseString]);
  if (newIDField)
    ASSIGN(IDField, [newIDField lowercaseString]);
  if (newCNField)
    ASSIGN(CNField, [newCNField lowercaseString]);
  if (newUIDField)
    ASSIGN(UIDField, [newUIDField lowercaseString]);
  if (newIMAPHostField)
    ASSIGN(IMAPHostField, [newIMAPHostField lowercaseString]);
  if (newIMAPLoginField)
    ASSIGN(IMAPLoginField, [newIMAPLoginField lowercaseString]);
  if (newSieveHostField)
    ASSIGN(SieveHostField, [newSieveHostField lowercaseString]);
  if (newMailFields)
    ASSIGN(mailFields, newMailFields);
  if (newSearchFields)
    ASSIGN(searchFields, newSearchFields);
  if (newGroupObjectClasses)
    ASSIGN(groupObjectClasses, newGroupObjectClasses);
  if (newBindFields)
    {
      // Before SOGo v1.2.0, bindFields was a comma-separated list
      // of values. So it could be configured as:
      //
      // bindFields = foo;
      // bindFields = "foo, bar, baz";
      //
      // SOGo v1.2.0 and upwards redefined that parameter as an array
      // so we would have instead:
      //
      // bindFields = (foo);
      // bindFields = (foo, bar, baz);
      //
      // We check for the old format and we support it.
      if ([newBindFields isKindOfClass: [NSArray class]])
        ASSIGN(bindFields, newBindFields);
      else
        {
          [self logWithFormat: @"WARNING: using old bindFields format - please update it"];
          ASSIGN(bindFields, [newBindFields componentsSeparatedByString: @","]);
        }
    }
  if (newKindField)
    ASSIGN(kindField, [newKindField lowercaseString]);
  if (newMultipleBookingsField)
    ASSIGN(multipleBookingsField, [newMultipleBookingsField lowercaseString]);
}

- (void) setListRequiresDot: (BOOL) aBool
{
  listRequiresDot = aBool;
}

- (BOOL) listRequiresDot
{
  return listRequiresDot;
}

- (void) setContactMapping: (NSDictionary *) newMapping
          andObjectClasses: (NSArray *) newObjectClasses
{
  ASSIGN (contactMapping, newMapping);
  ASSIGN (contactObjectClasses, newObjectClasses);
}

- (BOOL) _setupEncryption: (NGLdapConnection *) encryptedConn
{
  BOOL rc;

  if ([encryption isEqualToString: @"SSL"])
    rc = [encryptedConn useSSL];
  else if ([encryption isEqualToString: @"STARTTLS"])
    rc = [encryptedConn startTLS];
  else
    {
      [self errorWithFormat: @"encryption scheme '%@' not supported:"
                             @" use 'SSL' or 'STARTTLS'", encryption];
      rc = NO;
    }

  return rc;
}

- (NGLdapConnection *) _ldapConnection
{
  NGLdapConnection *ldapConnection;

  NS_DURING
    {
      ldapConnection = [[NGLdapConnection alloc] initWithHostName: hostname
                                                             port: port];
      [ldapConnection autorelease];
      if (![encryption length] || [self _setupEncryption: ldapConnection])
        {
          [ldapConnection bindWithMethod: @"simple"
                                  binddn: bindDN
                             credentials: password];
          if (queryLimit > 0)
            [ldapConnection setQuerySizeLimit: queryLimit];
          if (queryTimeout > 0)
            [ldapConnection setQueryTimeLimit: queryTimeout];
          if (!schema)
            {
              schema = [LDAPSourceSchema new];
              [schema readSchemaFromConnection: ldapConnection];
            }
        }
      else
        ldapConnection = nil;
    }
  NS_HANDLER
    {
      [self errorWithFormat: @"Could not bind to the LDAP server %@ (%d) "
                             @"using the bind DN: %@", hostname, port, bindDN];
      [self errorWithFormat: @"%@", localException];
      ldapConnection = nil;
    }
  NS_ENDHANDLER;

  return ldapConnection;
}

- (NSString *) domain
{
  return nil;
}

- (NSString *) baseDN
{
  return _baseDN;
}

- (NSString *) _getUUIDForDomain: (NSString *) domain
{
  NGLdapConnection *ldapConnection;
  NSArray *attributes = [NSArray arrayWithObjects: @"dn", @"sAMAccountName", nil];
  NSEnumerator *entries;
  NGLdapEntry *ldapEntry = nil;
  NSString *dn, *uuid, *qs, *cacheKey;
  NSArray *parts;
  EOQualifier *qualifier;

  // Check cache first
  cacheKey = [NSString stringWithFormat: @"uuid-%@", domain];
  uuid = [[SOGoCache sharedCache] valueForKey: cacheKey];
  if (uuid) return uuid;

  // Find first user with sAMAccountName=*@domain, parse DN
  ldapConnection = [self _ldapConnection];
  qs = [NSString stringWithFormat: @"sAMAccountName like '*@%@'", domain];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
  entries = [ldapConnection deepSearchAtBaseDN: [self baseDN]
                                     qualifier: qualifier
                                    attributes: attributes];
  ldapEntry = [entries nextObject];
  if (!ldapEntry)
    {
      [self errorWithFormat: @"No users found for %@", domain];
      return nil;
    }
  dn = [ldapEntry dn];
  parts = [dn componentsSeparatedByString: @","];
  // The DN must have the following format:
  //    CN=username,CN=Users,CN=UUID_OF_THE_DOMAIN,$BASE_DN
  if ([parts count] < 4 ||
      [[parts objectAtIndex: 1] caseInsensitiveCompare: @"CN=Users"] != NSOrderedSame)
    {
      [self errorWithFormat: @"DN found doesn't match with expected format"];
      return nil;
    }
  uuid = [parts objectAtIndex: 2];
  if ([uuid hasPrefix: @"CN="])
    {
      [self errorWithFormat: @"UUID found doesn't match with expected format"];
      return nil;
    }
  uuid = [uuid substringFromIndex: 3];

  [[SOGoCache sharedCache] setValue: uuid forKey: cacheKey];

  return uuid;
}

- (NSString *) baseDNForDomain: (NSString *) domain
{
  NSString *uuid;

  uuid = [self _getUUIDForDomain: domain];
  if (!uuid)
    {
      [self errorWithFormat: @"Domain %@ not found, cannot retrieve baseDN",
            domain];
      return nil;
    }

  return [NSString stringWithFormat: @"CN=%@,%@", uuid, [self baseDN]];
}

/* user management */
- (EOQualifier *) _qualifierForBindFilter: (NSString *) uid
{
  NSMutableString *qs;
  NSString *escapedUid;
  NSEnumerator *fields;
  NSString *currentField;

  qs = [NSMutableString string];

  escapedUid = SafeLDAPCriteria(uid);

  fields = [bindFields objectEnumerator];
  while ((currentField = [fields nextObject]))
    [qs appendFormat: @" OR (%@='%@')", currentField, escapedUid];

  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  [qs deleteCharactersInRange: NSMakeRange(0, 4)];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSString *) _domainFromLogin: (NSString *) login
{
  NSArray *parts = [login componentsSeparatedByString: @"@"];
  if ([parts count] != 2)
    {
      [self errorWithFormat: @"Invalid login `%@`, excepted email format", login];
      return nil;
    }
  return [parts objectAtIndex:1];
}

- (NSString *) _fetchUserDNForLogin: (NSString *) loginToCheck
{
  NSEnumerator *entries;
  EOQualifier *qualifier;
  NSArray *attributes, *results;
  NGLdapConnection *ldapConnection;
  NSString *domain, *baseDN;

  ldapConnection = [self _ldapConnection];
  qualifier = [self _qualifierForBindFilter: loginToCheck];
  attributes = [NSArray arrayWithObject: @"dn"];
  domain = [self _domainFromLogin: loginToCheck];
  if (!domain) return nil;
  baseDN = [self baseDNForDomain: domain];
  if (!baseDN) return nil;

  entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                     qualifier: qualifier
                                    attributes: attributes];
  results = [entries allObjects];
  if ([results count] != 1)
    {
      [self logWithFormat: @"Expected one result, got %d", [results count]];
      return nil;
    }

  return [[results objectAtIndex: 0] dn];
}

- (BOOL) checkLogin: (NSString *) _login
           password: (NSString *) _pwd
               perr: (SOGoPasswordPolicyError *) _perr
             expire: (int *) _expire
              grace: (int *) _grace
{
  NGLdapConnection *bindConnection;
  NSString *userDN;
  BOOL didBind;

  didBind = NO;

  NS_DURING
    if ([_login length] > 0 && [_pwd length] > 0)
      {
        bindConnection = [[NGLdapConnection alloc] initWithHostName: hostname
                                                               port: port];
        if (![encryption length] || [self _setupEncryption: bindConnection])
          {
            if (queryTimeout > 0)
              [bindConnection setQueryTimeLimit: queryTimeout];

            userDN = [[SOGoCache sharedCache] distinguishedNameForLogin: _login];

            if (!userDN)
              {
                if (!bindFields)
                  {
                    [self errorWithFormat: @"bindFields is mandatory to be able to login"];
                    return NO;
                  }
                // We MUST always use the source's bindDN/password in
                // order to lookup the user's DN. This is important since
                // if we use bindAsCurrentUser, we could stay bound and
                // lookup the user's DN (for another user that is trying
                // to log in) but not be able to do so due to ACLs in LDAP.
                [self setBindDN: sourceBindDN];
                [self setBindPassword: sourceBindPassword];
                userDN = [self _fetchUserDNForLogin: _login];
              }

            if (userDN)
              {
                if (!passwordPolicy)
                  didBind = [bindConnection bindWithMethod: @"simple"
                                                    binddn: userDN
                                               credentials: _pwd];
                else
                  didBind = [bindConnection bindWithMethod: @"simple"
                                                    binddn: userDN
                                               credentials: _pwd
                                                      perr: (void *)_perr
                                                    expire: _expire
                                                     grace: _grace];

                if (didBind)
                  // We cache the _login <-> userDN entry to speed up things
                  [[SOGoCache sharedCache] setDistinguishedName: userDN
                                                       forLogin: _login];
              }
          }
      }
  NS_HANDLER
    {
      [self logWithFormat: @"%@", localException];
    }
  NS_ENDHANDLER;

  [bindConnection release];
  return didBind;
}

- (NSString *) _encryptPassword: (NSString *) plainPassword
{
  NSString *pass;
  pass = [plainPassword asCryptedPassUsingScheme: _userPasswordAlgorithm];

  if (pass == nil)
    {
      [self errorWithFormat: @"Unsupported user-password algorithm: %@",
            _userPasswordAlgorithm];
      return nil;
    }

  return [NSString stringWithFormat: @"{%@}%@", _userPasswordAlgorithm, pass];
}

- (BOOL)  _ldapModifyAttribute: (NSString *) theAttribute
                     withValue: (NSString *) theValue
                        userDN: (NSString *) theUserDN
                      password: (NSString *) theUserPassword
                    connection: (NGLdapConnection *) bindConnection
{
  NGLdapModification *mod;
  NGLdapAttribute *attr;
  NSArray *changes;

  BOOL didChange;

  attr = [[NGLdapAttribute alloc] initWithAttributeName: theAttribute];
  [attr addStringValue: theValue];

  mod = [NGLdapModification replaceModification: attr];

  changes = [NSArray arrayWithObject: mod];

  if ([bindConnection bindWithMethod: @"simple"
                              binddn: theUserDN
                         credentials: theUserPassword])
    {
      didChange = [bindConnection modifyEntryWithDN: theUserDN
                                            changes: changes];
    }
  else
    didChange = NO;

  RELEASE(attr);

  return didChange;
}

- (BOOL) changePasswordForLogin: (NSString *) login
                    oldPassword: (NSString *) oldPassword
                    newPassword: (NSString *) newPassword
                           perr: (SOGoPasswordPolicyError *) perr

{
  NGLdapConnection *bindConnection;
  NSString *userDN;
  BOOL didChange;

  didChange = NO;

  NS_DURING
    if ([login length] > 0)
      {
        bindConnection = [[NGLdapConnection alloc] initWithHostName: hostname
                                                               port: port];
        if (![encryption length] || [self _setupEncryption: bindConnection])
          {
            if (queryTimeout > 0)
              [bindConnection setQueryTimeLimit: queryTimeout];
            if (!bindFields)
              {
                [self errorWithFormat: @"bindFields is mandatory to be able to login"];
                return NO;
              }
            userDN = [self _fetchUserDNForLogin: login];
            if (userDN)
              {
                if ([bindConnection isADCompatible])
                  {
                    if ([bindConnection bindWithMethod: @"simple"
                                                binddn: userDN
                                           credentials: oldPassword])
                      didChange = [bindConnection changeADPasswordAtDn: userDN
                                                           oldPassword: oldPassword
                                                           newPassword: newPassword];
                  }
                else if (passwordPolicy)
                  didChange = [bindConnection changePasswordAtDn: userDN
                                                     oldPassword: oldPassword
                                                     newPassword: newPassword
                                                            perr: (void *)perr];
                else
                  {
                    // We don't use a password policy - we simply use
                    // a modify-op to change the password
                    NSString* encryptedPass;

                    if ([_userPasswordAlgorithm isEqualToString: @"none"])
                      encryptedPass = newPassword;
                    else
                      encryptedPass = [self _encryptPassword: newPassword];

                    if (encryptedPass != nil)
                      {
                        *perr = PolicyNoError;
                        didChange = [self _ldapModifyAttribute: @"userPassword"
                                                     withValue: encryptedPass
                                                        userDN: userDN
                                                      password: oldPassword
                                                    connection: bindConnection];
                      }
                  }

                // We must check if we must update the Samba NT/LM password hashes
                if (didChange && updateSambaNTLMPasswords)
                  {
                    [self _ldapModifyAttribute: @"sambaNTPassword"
                                     withValue: [newPassword asNTHash]
                                        userDN: userDN
                                      password: newPassword
                                    connection: bindConnection];

                    [self _ldapModifyAttribute: @"sambaLMPassword"
                                     withValue: [newPassword asLMHash]
                                        userDN: userDN
                                      password: newPassword
                                    connection: bindConnection];
                  }
              }
          }
      }
  NS_HANDLER
    {
      if ([[localException name] isEqual: @"LDAPException"] &&
          [[[localException userInfo] objectForKey: @"error_code"] intValue] == LDAP_CONSTRAINT_VIOLATION)
        *perr = PolicyInsufficientPasswordQuality;
      else
        [self logWithFormat: @"%@", localException];
    }
  NS_ENDHANDLER ;

  [bindConnection release];
  return didChange;
}

- (NSArray *) _constraintsFields
{
  NSMutableArray *fields;
  NSEnumerator *values;
  NSDictionary *currentConstraint;

  fields = [NSMutableArray array];
  values = [[modulesConstraints allValues] objectEnumerator];
  while ((currentConstraint = [values nextObject]))
    [fields addObjectsFromArray: [currentConstraint allKeys]];

  return fields;
}

- (NSArray *) allEntryIDs
{
  [self errorWithFormat: @"allEntryIDs method must not be used, use "
                         @"allEntryIDsVisibleFromDomain instead"];
  return nil;
}

- (NSArray *) allEntryIDsVisibleFromDomain: (NSString *) domain
{
  NSEnumerator *entries;
  NGLdapEntry *currentEntry;
  NGLdapConnection *ldapConnection;
  EOQualifier *qualifier;
  NSMutableString *qs;
  NSString *value, *baseDN;
  NSArray *attributes;
  NSMutableArray *ids;

  ids = [NSMutableArray array];

  ldapConnection = [self _ldapConnection];
  attributes = [NSArray arrayWithObject: UIDField];

  qs = [NSMutableString stringWithFormat: @"(%@='*')", CNField];
  if ([_filter length])
    [qs appendFormat: @" AND %@", _filter];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];

  baseDN = [self baseDNForDomain: domain];
  if (!baseDN) return nil;

  entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                     qualifier: qualifier
                                    attributes: attributes];

  while ((currentEntry = [entries nextObject]))
    {
      value = [[currentEntry attributeWithName: UIDField] stringValueAtIndex: 0];
      if ([value length] > 0)
        [ids addObject: value];
    }

  return ids;
}

- (void) _fillEmailsOfEntry: (NGLdapEntry *) ldapEntry
             intoLDIFRecord: (NSMutableDictionary *) ldifRecord
{
  NSEnumerator *emailFields;
  NSString *currentFieldName, *ldapValue;
  NSMutableArray *emails;
  NSArray *allValues;

  emails = [[NSMutableArray alloc] init];
  emailFields = [mailFields objectEnumerator];
  while ((currentFieldName = [emailFields nextObject]))
    {
      allValues = [[ldapEntry attributeWithName: currentFieldName] allStringValues];
      [emails addObjectsFromArray: allValues];
    }
  [ldifRecord setObject: emails forKey: @"c_emails"];
  [emails release];

  if (IMAPHostField)
    {
      ldapValue = [[ldapEntry attributeWithName: IMAPHostField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
        [ldifRecord setObject: ldapValue forKey: @"c_imaphostname"];
    }

  if (IMAPLoginField)
    {
      ldapValue = [[ldapEntry attributeWithName: IMAPLoginField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
        [ldifRecord setObject: ldapValue forKey: @"c_imaplogin"];
    }

  if (SieveHostField)
    {
      ldapValue = [[ldapEntry attributeWithName: SieveHostField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
        [ldifRecord setObject: ldapValue forKey: @"c_sievehostname"];
    }
}

- (void) _fillConstraints: (NGLdapEntry *) ldapEntry
                forModule: (NSString *) module
           intoLDIFRecord: (NSMutableDictionary *) ldifRecord
{
  NSDictionary *constraints;
  NSEnumerator *matches, *ldapValues;
  NSString *currentMatch, *currentValue, *ldapValue;
  BOOL result;

  result = YES;

  constraints = [modulesConstraints objectForKey: module];
  if (constraints)
    {
      matches = [[constraints allKeys] objectEnumerator];
      while (result == YES && (currentMatch = [matches nextObject]))
        {
          ldapValues = [[[ldapEntry attributeWithName: currentMatch]
                         allStringValues] objectEnumerator];
          currentValue = [constraints objectForKey: currentMatch];
          result = NO;

          while (result == NO && (ldapValue = [ldapValues nextObject]))
            if ([ldapValue caseInsensitiveMatches: currentValue])
              result = YES;
        }
    }

  [ldifRecord setObject: [NSNumber numberWithBool: result]
                 forKey: [NSString stringWithFormat: @"%@Access", module]];
}

/* conversion LDAP -> SOGo inetOrgPerson entry */
- (void) _applyContactMappingToResult: (NSMutableDictionary *) ldifRecord
{
  NSArray *sourceFields;
  NSArray *keys;
  NSString *key, *field, *value;
  NSUInteger count, max, fieldCount, fieldMax;
  BOOL filled;

  keys = [contactMapping allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      sourceFields = [contactMapping objectForKey: key];
      if ([sourceFields isKindOfClass: NSStringK])
        sourceFields = [NSArray arrayWithObject: sourceFields];
      fieldMax = [sourceFields count];
      filled = NO;
      for (fieldCount = 0; !filled && fieldCount < fieldMax; fieldCount++)
        {
          field = [[sourceFields objectAtIndex: fieldCount] lowercaseString];
          value = [ldifRecord objectForKey: field];
          if (value)
            {
              [ldifRecord setObject: value forKey: [key lowercaseString]];
              filled = YES;
            }
        }
    }
}

/* conversion SOGo inetOrgPerson entry -> LDAP */
- (void) _applyContactMappingToOutput: (NSMutableDictionary *) ldifRecord
{
  NSArray *sourceFields;
  NSArray *keys;
  NSString *key, *lowerKey, *field, *value;
  NSUInteger count, max, fieldCount, fieldMax;

  if (contactObjectClasses)
    [ldifRecord setObject: contactObjectClasses
                   forKey: @"objectclass"];

  keys = [contactMapping allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      lowerKey = [key lowercaseString];
      value = [ldifRecord objectForKey: lowerKey];
      if ([value length] > 0)
        {
          sourceFields = [contactMapping objectForKey: key];
          if ([sourceFields isKindOfClass: NSStringK])
            sourceFields = [NSArray arrayWithObject: sourceFields];

          fieldMax = [sourceFields count];
          for (fieldCount = 0; fieldCount < fieldMax; fieldCount++)
            {
              field = [[sourceFields objectAtIndex: fieldCount] lowercaseString];
              [ldifRecord setObject: value forKey: field];
            }
        }
    }
}

- (NSDictionary *) _convertLDAPEntryToContact: (NGLdapEntry *) ldapEntry
                                     inDomain: (NSString *) domain
{
  NSMutableDictionary *ldifRecord;
  NSString *value;
  static NSArray *resourceKinds = nil;
  NSMutableArray *classes;
  NSEnumerator *gclasses;
  NSString *gclass;
  id o;

  if (!resourceKinds)
    resourceKinds = [[NSArray alloc] initWithObjects: @"location", @"thing",
                                                      @"group", nil];

  ldifRecord = [ldapEntry asDictionary];
  [ldifRecord setObject: self forKey: @"source"];
  [ldifRecord setObject: [ldapEntry dn] forKey: @"dn"];

  // We get our objectClass attribute values. We lowercase
  // everything for ease of search after.
  o = [ldapEntry objectClasses];
  classes = nil;

  if (o)
    {
      size_t i, c;

      classes = [NSMutableArray arrayWithArray: o];
      c = [classes count];
      for (i = 0; i < c; i++)
        [classes replaceObjectAtIndex: i
                           withObject: [[classes objectAtIndex: i] lowercaseString]];
    }

  if (classes)
    {
      // We check if our entry is a resource. We also support
      // determining resources based on the KindFieldName attribute
      // value - see below.
      if ([classes containsObject: @"calendarresource"])
        {
          [ldifRecord setObject: [NSNumber numberWithInt: 1]
                         forKey: @"isResource"];
        }
      else
        {
        // We check if our entry is a group. If so, we set the
        // 'isGroup' custom attribute.
        gclasses = [groupObjectClasses objectEnumerator];
        while ((gclass = [gclasses nextObject]))
         if ([classes containsObject: [gclass lowercaseString]])
           {
             [ldifRecord setObject: [NSNumber numberWithInt: 1]
                            forKey: @"isGroup"];
             break;
           }
        }
    }

  // We check if that entry corresponds to a resource. For this,
  // kindField must be defined and it must hold one of those values
  //
  // location
  // thing
  // group
  //
  if ([kindField length] > 0)
    {
      value = [ldifRecord objectForKey: [kindField lowercaseString]];
      if ([value isKindOfClass: NSStringK]
          && [resourceKinds containsObject: value])
        [ldifRecord setObject: [NSNumber numberWithInt: 1]
                       forKey: @"isResource"];
    }

  // We check for the number of simultanous bookings that is allowed.
  // A value of 0 means that there's no limit.
  if ([multipleBookingsField length] > 0)
    {
      value = [ldifRecord objectForKey: [multipleBookingsField lowercaseString]];
      [ldifRecord setObject: [NSNumber numberWithInt: [value intValue]]
                     forKey: @"numberOfSimultaneousBookings"];
    }

  value = [[ldapEntry attributeWithName: IDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [ldifRecord setObject: value forKey: @"c_name"];
  value = [[ldapEntry attributeWithName: UIDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [ldifRecord setObject: value forKey: @"c_uid"];
  value = [[ldapEntry attributeWithName: CNField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [ldifRecord setObject: value forKey: @"c_cn"];
  /* if "displayName" is not set, we use CNField because it must exist */
  if (![ldifRecord objectForKey: @"displayname"])
    [ldifRecord setObject: value forKey: @"displayname"];

  if (contactInfoAttribute)
    {
      value = [[ldapEntry attributeWithName: contactInfoAttribute]
                stringValueAtIndex: 0];
      if (!value)
        value = @"";
    }
  else
    value = @"";
  [ldifRecord setObject: value forKey: @"c_info"];

  [ldifRecord setObject: domain forKey: @"c_domain"];

  [self _fillEmailsOfEntry: ldapEntry intoLDIFRecord: ldifRecord];
  [self _fillConstraints: ldapEntry forModule: @"Calendar"
          intoLDIFRecord: (NSMutableDictionary *) ldifRecord];
  [self _fillConstraints: ldapEntry forModule: @"Mail"
          intoLDIFRecord: (NSMutableDictionary *) ldifRecord];
  [self _fillConstraints: ldapEntry forModule: @"ActiveSync"
          intoLDIFRecord: (NSMutableDictionary *) ldifRecord];

  if (contactMapping)
    [self _applyContactMappingToResult: ldifRecord];

  return ldifRecord;
}

// Used on [self fetchContactsMatching:filter inDomain:domain]
- (EOQualifier *) _qualifierForFilter: (NSString *) filter
{
  NSMutableArray *fields;
  NSString *fieldFormat, *searchFormat, *escapedFilter;
  EOQualifier *qualifier;
  NSMutableString *qs;

  escapedFilter = SafeLDAPCriteria(filter);
  if ([escapedFilter length] > 0)
    {
      qs = [NSMutableString string];
      if ([escapedFilter isEqualToString: @"."])
        [qs appendFormat: @"(%@='*')", CNField];
      else
        {
          fieldFormat = [NSString stringWithFormat: @"(%%@='*%@*')",
                                  escapedFilter];
          fields = [NSMutableArray arrayWithArray: searchFields];
          [fields addObjectsFromArray: mailFields];
          [fields addObject: CNField];
          searchFormat = [[[fields uniqueObjects] stringsWithFormat: fieldFormat]
                           componentsJoinedByString: @" OR "];
          [qs appendString: searchFormat];
        }

      if (_filter && [_filter length])
        [qs appendFormat: @" AND %@", _filter];

      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
    }
  else if (!listRequiresDot)
    {
      qs = [NSMutableString stringWithFormat: @"(%@='*')", CNField];
      if ([_filter length])
        [qs appendFormat: @" AND %@", _filter];
      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
    }
  else
    qualifier = nil;

  return qualifier;
}

- (NSArray *) fetchContactsMatching: (NSString *) match
                           inDomain: (NSString *) domain
{
  NGLdapConnection *ldapConnection;
  NGLdapEntry *currentEntry;
  NSEnumerator *entries;
  NSMutableArray *contacts;
  EOQualifier *qualifier;
  NSArray *attributes;
  NSString *baseDN;

  contacts = [NSMutableArray array];

  if ([match length] > 0 || !listRequiresDot)
    {
      ldapConnection = [self _ldapConnection];
      qualifier = [self _qualifierForFilter: match];
      attributes = [NSArray arrayWithObject: @"*"];
      baseDN = [self baseDNForDomain: domain];
      if (!baseDN) return nil;

      entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                         qualifier: qualifier
                                        attributes: attributes];

      while ((currentEntry = [entries nextObject]))
        [contacts addObject: [self _convertLDAPEntryToContact: currentEntry
                                                     inDomain: domain]];
    }

  return contacts;
}

- (NGLdapEntry *) _lookupLDAPEntry: (EOQualifier *) qualifier
                          inDomain: (NSString *) domain
{
  NGLdapConnection *ldapConnection;
  NSArray *attributes;
  NSEnumerator *entries;
  NSString *baseDN;

  ldapConnection = [self _ldapConnection];
  attributes = [NSArray arrayWithObject: @"*"];
  baseDN = [self baseDNForDomain: domain];
  if (!baseDN) return nil;

  entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                     qualifier: qualifier
                                    attributes: attributes];

  return [entries nextObject];
}

- (NSDictionary *) lookupContactEntry: (NSString *) theID
                             inDomain: (NSString *) domain
{
  NGLdapEntry *ldapEntry;
  EOQualifier *qualifier;
  NSString *s;
  NSDictionary *ldifRecord;

  ldifRecord = nil;

  if ([theID length] > 0)
    {
      s = [NSString stringWithFormat: @"(%@='%@') or (%@='%@')",
                    UIDField, SafeLDAPCriteria(theID),
                    IDField, SafeLDAPCriteria(theID)];
      qualifier = [EOQualifier qualifierWithQualifierFormat: s];
      ldapEntry = [self _lookupLDAPEntry: qualifier inDomain: domain];

      if (ldapEntry)
        ldifRecord = [self _convertLDAPEntryToContact: ldapEntry
                                             inDomain: domain];
    }

  return ldifRecord;
}

// Used on [self lookupContactEntryWithUIDorEmail:uid inDomain:domain]
- (EOQualifier *) _qualifierForUIDFilter: (NSString *) uid
{
  NSString *mailFormat, *fieldFormat, *escapedUid, *currentField;
  NSEnumerator *bindFieldsEnum;
  NSMutableString *qs;

  escapedUid = SafeLDAPCriteria(uid);

  fieldFormat = [NSString stringWithFormat: @"(%%@='%@')", escapedUid];
  mailFormat = [[mailFields stringsWithFormat: fieldFormat]
                     componentsJoinedByString: @" OR "];
  qs = [NSMutableString stringWithFormat: @"(%@='%@') OR %@",
                        UIDField, escapedUid, mailFormat];
  if (bindFields)
    {
      bindFieldsEnum = [bindFields objectEnumerator];
      while ((currentField = [bindFieldsEnum nextObject]))
        {
          if ([currentField caseInsensitiveCompare: UIDField] != NSOrderedSame
              && ![mailFields containsObject: currentField])
            [qs appendFormat: @" OR (%@='%@')",
                [currentField stringByTrimmingSpaces], escapedUid];
        }
    }

  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) uid
                                           inDomain: (NSString *) domain
{
  NGLdapEntry *ldapEntry;
  EOQualifier *qualifier;
  NSDictionary *ldifRecord;

  ldifRecord = nil;

  if ([uid length] > 0)
    {
      qualifier = [self _qualifierForUIDFilter: uid];
      ldapEntry = [self _lookupLDAPEntry: qualifier inDomain: domain];
      if (ldapEntry)
        ldifRecord = [self _convertLDAPEntryToContact: ldapEntry
                                             inDomain: domain];
    }

  return ldifRecord;
}

- (NSString *) lookupLoginByDN: (NSString *) theDN
{
  NGLdapConnection *ldapConnection;
  NGLdapEntry *entry;
  NSString *login, *loginField;

  login = nil;
  ldapConnection = [self _ldapConnection];

  if (!bindFields) return nil;
  loginField = [bindFields objectAtIndex: 0];
  entry = [ldapConnection entryAtDN: theDN
                         attributes: [NSArray arrayWithObject: loginField]];
  if (entry)
    login = [[entry attributeWithName: loginField] stringValueAtIndex: 0];

  return login;
}

- (NSString *) lookupDNByLogin: (NSString *) theLogin
{
  return [[SOGoCache sharedCache] distinguishedNameForLogin: theLogin];
}

- (NGLdapEntry *) _lookupGroupEntryByAttributes: (NSArray *) theAttributes
                                       andValue: (NSString *) theValue
                                       inDomain: (NSString *) domain
{
  EOQualifier *qualifier;
  NGLdapEntry *ldapEntry = nil;
  NSString *s;

  if ([theValue length] > 0 && [theAttributes count] > 0)
    {
      if ([theAttributes count] == 1)
        {
          s = [NSString stringWithFormat: @"(%@='%@')",
                        [theAttributes lastObject], SafeLDAPCriteria(theValue)];
        }
      else
        {
          NSString *fieldFormat;

          fieldFormat = [NSString stringWithFormat: @"(%%@='%@')",
                                  SafeLDAPCriteria(theValue)];
          s = [[theAttributes stringsWithFormat: fieldFormat] componentsJoinedByString: @" OR "];
        }

      qualifier = [EOQualifier qualifierWithQualifierFormat: s];
      ldapEntry = [self _lookupLDAPEntry: qualifier inDomain: domain];
    }

  return ldapEntry;
}

- (NGLdapEntry *) lookupGroupEntryByUID: (NSString *) theUID
                               inDomain: (NSString *) domain
{
  return [self _lookupGroupEntryByAttributes: [NSArray arrayWithObject: UIDField]
                                    andValue: theUID
                                    inDomain: domain];
}

- (NGLdapEntry *) lookupGroupEntryByEmail: (NSString *) theEmail
                                 inDomain: (NSString *) domain
{
  return [self _lookupGroupEntryByAttributes: mailFields
                                    andValue: theEmail
                                    inDomain: domain];
}

- (void) setSourceID: (NSString *) newSourceID
{
  ASSIGN (sourceID, newSourceID);
}

- (NSString *) sourceID
{
  return sourceID;
}

- (void) setDisplayName: (NSString *) newDisplayName
{
  ASSIGN (displayName, newDisplayName);
}

- (NSString *) displayName
{
  return displayName;
}

- (NSString *) MSExchangeHostname
{
  return MSExchangeHostname;
}

- (void) setModifiers: (NSArray *) newModifiers
{
  ASSIGN (modifiers, newModifiers);
}

- (NSArray *) modifiers
{
  return modifiers;
}

- (NSArray *) groupObjectClasses
{
  return groupObjectClasses;
}

// ----------------------------------------------------------------------------
// Contacts ldif not supported
// ----------------------------------------------------------------------------

- (NSException *) addContactEntry: (NSDictionary *) roLdifRecord
                           withID: (NSString *) aId
{
  return [NSException exceptionWithName: @"NotImplementedException"
                                 reason: @"This method should not be used"
                               userInfo: nil];
}

- (NSException *) updateContactEntry: (NSDictionary *) roLdifRecord
{
  return [NSException exceptionWithName: @"NotImplementedException"
                                 reason: @"This method should not be used"
                               userInfo: nil];
}

- (NSException *) removeContactEntryWithID: (NSString *) aId
{
  return [NSException exceptionWithName: @"NotImplementedException"
                                 reason: @"This method should not be used"
                               userInfo: nil];
}

// ----------------------------------------------------------------------------
// User Addressbooks not supported
// ----------------------------------------------------------------------------

- (BOOL) hasUserAddressBooks
{
  return NO;
}

- (NSArray *) addressBookSourcesForUser: (NSString *) user
{
  [[NSException exceptionWithName: @"NotImplementedException"
                           reason: @"This method should not be used"
                         userInfo: nil] raise];
  return nil;
}

- (NSException *) addAddressBookSource: (NSString *) newId
                       withDisplayName: (NSString *) newDisplayName
                               forUser: (NSString *) user
{
  return [NSException exceptionWithName: @"NotImplementedException"
                                 reason: @"This method should not be used"
                               userInfo: nil];
}

- (NSException *) renameAddressBookSource: (NSString *) newId
                          withDisplayName: (NSString *) newDisplayName
                                  forUser: (NSString *) user
{
  return [NSException exceptionWithName: @"NotImplementedException"
                                 reason: @"This method should not be used"
                               userInfo: nil];
}

- (NSException *) removeAddressBookSource: (NSString *) newId
                                  forUser: (NSString *) user
{
  return [NSException exceptionWithName: @"NotImplementedException"
                                 reason: @"This method should not be used"
                               userInfo: nil];
}

@end
