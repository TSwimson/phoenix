/*
 * Phoenix is released under the MIT License. Refer to https://github.com/kasper/phoenix/blob/master/LICENSE.md
 */

#import "NSArray+PHExtension.h"
#import "NSScreen+PHExtension.h"
#import "PHSpace.h"
#import "PHWindow.h"

/* XXX: Undocumented private typedefs for CGSSpace */

typedef NSUInteger CGSConnectionID;
typedef NSUInteger CGSSpaceID;

typedef enum {

    kCGSSpaceIncludesCurrent = 1 << 0,
    kCGSSpaceIncludesOthers = 1 << 1,
    kCGSSpaceIncludesUser = 1 << 2,

    kCGSAllSpacesMask = kCGSSpaceIncludesCurrent | kCGSSpaceIncludesOthers | kCGSSpaceIncludesUser

} CGSSpaceMask;

typedef enum {

    kCGSSpaceUser,
    kCGSSpaceFullScreen = 4

} CGSSpaceType;

@interface PHSpace ()

@property CGSSpaceID identifier;

@end

@implementation PHSpace

static NSString * const PHScreenIDKey = @"Display Identifier";
static NSString * const PHSpacesKey = @"Spaces";
static NSString * const PHSpaceIDKey = @"ManagedSpaceID";
static NSString * const PHWindowIDKey = @"identifier";

// XXX: Undocumented private API to get the CGSConnectionID for the default connection for this process
CGSConnectionID CGSMainConnectionID();

// XXX: Undocumented private API to get the CGSSpaceID for the active space
CGSSpaceID CGSGetActiveSpace(CGSConnectionID connection);

// XXX: Undocumented private API to get the CGSSpaceIDs for all spaces in order
CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID connection);

// XXX: Undocumented private API to get the CGSSpaceIDs for the given windows (CGWindowIDs)
CFArrayRef CGSCopySpacesForWindows(CGSConnectionID connection, CGSSpaceMask mask, CFArrayRef windowIds);

// XXX: Undocumented private API to get the CGSSpaceType for a given space
CGSSpaceType CGSSpaceGetType(CGSConnectionID connection, CGSSpaceID space);

// XXX: Undocumented private API to add the given windows (CGWindowIDs) to the given spaces (CGSSpaceIDs)
void CGSAddWindowsToSpaces(CGSConnectionID connection, CFArrayRef windowIds, CFArrayRef spaceIds);

// XXX: Undocumented private API to remove the given windows (CGWindowIDs) from the given spaces (CGSSpaceIDs)
void CGSRemoveWindowsFromSpaces(CGSConnectionID connection, CFArrayRef windowIds, CFArrayRef spaceIds);

#pragma mark - Initialise

- (instancetype) initWithIdentifier:(NSUInteger)identifier {

    if (self = [super init]) {
        self.identifier = identifier;
    }

    return self;
}

#pragma mark - Spaces

+ (instancetype) activeSpace {

    return [[PHSpace alloc] initWithIdentifier:CGSGetActiveSpace(CGSMainConnectionID())];
}

+ (NSArray<PHSpace *> *) spaces {

    NSMutableArray *spaces = [NSMutableArray array];
    NSArray *displaySpacesInfo = CFBridgingRelease(CGSCopyManagedDisplaySpaces(CGSMainConnectionID()));

    for (NSDictionary<NSString *, id> *spacesInfo in displaySpacesInfo) {

        NSArray<NSNumber *> *identifiers = [spacesInfo[PHSpacesKey] valueForKey:PHSpaceIDKey];

        for (NSNumber *identifier in identifiers) {
            [spaces addObject:[[PHSpace alloc] initWithIdentifier:identifier.unsignedLongValue]];
        }
    }
    
    return spaces;
}

+ (NSArray<PHSpace *> *) spacesForWindow:(PHWindow *)window {

    NSMutableArray *spaces = [NSMutableArray array];
    NSArray<NSNumber *> *identifiers = CFBridgingRelease(CGSCopySpacesForWindows(CGSMainConnectionID(),
                                                                                 kCGSAllSpacesMask,
                                                                                 (__bridge CFArrayRef) @[ @([window identifier]) ]));
    for (PHSpace *space in [self spaces]) {

        NSNumber *identifier = @([space hash]);

        if ([identifiers containsObject:identifier]) {
            [spaces addObject:[[PHSpace alloc] initWithIdentifier:identifier.unsignedLongValue]];
        }
    }

    return spaces;
}

#pragma mark - Identifying

- (NSUInteger) hash {

    return self.identifier;
}

- (BOOL) isEqual:(id)object {

    return [object isKindOfClass:[PHSpace class]] && [self hash] == [object hash];
}

#pragma mark - Space

- (instancetype) next {

    return [[PHSpace spaces] nextFrom:self];
}

- (instancetype) previous {

    return [[PHSpace spaces] previousFrom:self];
}

#pragma mark - Properties

- (BOOL) isNormal {

    return CGSSpaceGetType(CGSMainConnectionID(), self.identifier) == kCGSSpaceUser;
}

- (BOOL) isFullScreen {

    return CGSSpaceGetType(CGSMainConnectionID(), self.identifier) == kCGSSpaceFullScreen;
}

- (NSScreen *) screen {

    NSArray *displaySpacesInfo = CFBridgingRelease(CGSCopyManagedDisplaySpaces(CGSMainConnectionID()));

    for (NSDictionary<NSString *, id> *spacesInfo in displaySpacesInfo) {

        NSString *screenIdentifier = spacesInfo[PHScreenIDKey];
        NSArray<NSNumber *> *identifiers = [spacesInfo[PHSpacesKey] valueForKey:PHSpaceIDKey];

        if ([identifiers containsObject:@(self.identifier)]) {
            return [NSScreen screenForIdentifier:screenIdentifier];
        }
    }

    return nil;
}

#pragma mark - Windows

- (NSArray<PHWindow *> *) filteredWindowsOnSameSpace:(NSArray<PHWindow *> *)windows {

    NSPredicate *windowOnSameSpace = [NSPredicate predicateWithBlock:
                                      ^BOOL (PHWindow *window, __unused NSDictionary<NSString *, id> *bindings) {

                                          return [[window spaces] containsObject:self];
                                      }];

    return [windows filteredArrayUsingPredicate:windowOnSameSpace];
}

- (NSArray<PHWindow *> *) windows {

    return [self filteredWindowsOnSameSpace:[PHWindow windows]];
}

- (NSArray<PHWindow *> *) visibleWindows {

    return [self filteredWindowsOnSameSpace:[PHWindow visibleWindows]];
}

- (void) addWindows:(NSArray<PHWindow *> *)windows {

    CGSAddWindowsToSpaces(CGSMainConnectionID(),
                          (__bridge CFArrayRef) [windows valueForKey:PHWindowIDKey],
                          (__bridge CFArrayRef) @[ @(self.identifier) ]);
}

- (void) removeWindows:(NSArray<PHWindow *> *)windows {

    CGSRemoveWindowsFromSpaces(CGSMainConnectionID(),
                               (__bridge CFArrayRef) [windows valueForKey:PHWindowIDKey],
                               (__bridge CFArrayRef) @[ @(self.identifier) ]);
}

@end