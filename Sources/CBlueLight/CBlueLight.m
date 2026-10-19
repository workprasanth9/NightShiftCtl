#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include "CBlueLight.h"

// Layout of the structures used by CBBlueLightClient. These are private
// and undocumented, verified against the Objective-C type encodings:
// {?=BBBi{?={?=ii}{?=ii}}QB}
typedef struct { int hour; int minute; } NSCTime;
typedef struct { NSCTime from; NSCTime to; } NSCSchedule;
typedef struct {
    BOOL active;
    BOOL enabled;
    BOOL sunSchedulePermitted;
    int mode;
    NSCSchedule schedule;
    unsigned long long disableFlags;
    BOOL available;
} NSCRawStatus;

@protocol NSCBlueLightClient <NSObject>
- (BOOL)getBlueLightStatus:(NSCRawStatus *)status;
- (BOOL)setEnabled:(BOOL)enabled;
- (BOOL)getStrength:(float *)strength;
- (BOOL)setStrength:(float)strength commit:(BOOL)commit;
- (BOOL)setMode:(int)mode;
- (BOOL)setSchedule:(const NSCSchedule *)schedule;
@end

@protocol NSCTrueToneClient <NSObject>
- (BOOL)supported;
- (BOOL)available;
- (BOOL)enabled;
@end

static id<NSCBlueLightClient> gClient = nil;

static const char *kCoreBrightnessPath =
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness";

bool nsc_load(void) {
    if (gClient != nil) { return true; }
    if (dlopen(kCoreBrightnessPath, RTLD_LAZY) == NULL) { return false; }
    Class cls = NSClassFromString(@"CBBlueLightClient");
    if (cls == Nil) { return false; }
    id client = [[cls alloc] init];
    if (client == nil) { return false; }
    NSArray<NSString *> *required = @[
        @"getBlueLightStatus:", @"setEnabled:", @"getStrength:",
        @"setStrength:commit:", @"setMode:", @"setSchedule:"
    ];
    for (NSString *name in required) {
        if (![client respondsToSelector:NSSelectorFromString(name)]) { return false; }
    }
    gClient = client;
    return true;
}

bool nsc_supported(void) {
    if (!nsc_load()) { return false; }
    Class cls = NSClassFromString(@"CBBlueLightClient");
    SEL sel = NSSelectorFromString(@"supportsBlueLightReduction");
    if (![cls respondsToSelector:sel]) { return true; }
    BOOL (*fn)(id, SEL) = (BOOL (*)(id, SEL))[cls methodForSelector:sel];
    return fn(cls, sel) ? true : false;
}

bool nsc_get_status(NSCStatus *out) {
    if (out == NULL || !nsc_load()) { return false; }
    NSCRawStatus raw;
    memset(&raw, 0, sizeof(raw));
    if (![gClient getBlueLightStatus:&raw]) { return false; }
    out->active = raw.active;
    out->enabled = raw.enabled;
    out->sunSchedulePermitted = raw.sunSchedulePermitted;
    out->mode = raw.mode;
    out->fromHour = raw.schedule.from.hour;
    out->fromMinute = raw.schedule.from.minute;
    out->toHour = raw.schedule.to.hour;
    out->toMinute = raw.schedule.to.minute;
    out->disableFlags = raw.disableFlags;
    out->available = raw.available;
    return true;
}

bool nsc_set_enabled(bool enabled) {
    if (!nsc_load()) { return false; }
    return [gClient setEnabled:enabled] ? true : false;
}

bool nsc_get_strength(float *out) {
    if (out == NULL || !nsc_load()) { return false; }
    return [gClient getStrength:out] ? true : false;
}

bool nsc_set_strength(float strength) {
    if (!nsc_load()) { return false; }
    return [gClient setStrength:strength commit:YES] ? true : false;
}

bool nsc_set_mode(int32_t mode) {
    if (!nsc_load()) { return false; }
    return [gClient setMode:mode] ? true : false;
}

bool nsc_set_schedule(int32_t fromHour, int32_t fromMinute, int32_t toHour, int32_t toMinute) {
    if (!nsc_load()) { return false; }
    NSCSchedule schedule = { { fromHour, fromMinute }, { toHour, toMinute } };
    return [gClient setSchedule:&schedule] ? true : false;
}

bool nsc_truetone_status(bool *supported, bool *available, bool *enabled) {
    if (dlopen(kCoreBrightnessPath, RTLD_LAZY) == NULL) { return false; }
    Class cls = NSClassFromString(@"CBTrueToneClient");
    if (cls == Nil) { return false; }
    id<NSCTrueToneClient> client = [[cls alloc] init];
    if (client == nil) { return false; }
    if (![client respondsToSelector:@selector(supported)] ||
        ![client respondsToSelector:@selector(available)] ||
        ![client respondsToSelector:@selector(enabled)]) { return false; }
    if (supported) { *supported = [client supported]; }
    if (available) { *available = [client available]; }
    if (enabled) { *enabled = [client enabled]; }
    return true;
}
