#ifndef CBLUELIGHT_H
#define CBLUELIGHT_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Mirror of the private CoreBrightness status structure.
typedef struct {
    bool active;
    bool enabled;
    bool sunSchedulePermitted;
    int32_t mode;          // 0 = no schedule, 1 = sunset to sunrise, 2 = custom
    int32_t fromHour;
    int32_t fromMinute;
    int32_t toHour;
    int32_t toMinute;
    uint64_t disableFlags;
    bool available;
} NSCStatus;

/// Loads CoreBrightness and creates the clients. Returns false if unavailable.
bool nsc_load(void);
bool nsc_supported(void);
bool nsc_get_status(NSCStatus *outStatus);
bool nsc_set_enabled(bool enabled);
bool nsc_get_strength(float *outStrength);
bool nsc_set_strength(float strength);
bool nsc_set_mode(int32_t mode);
bool nsc_set_schedule(int32_t fromHour, int32_t fromMinute, int32_t toHour, int32_t toMinute);

/// True Tone (read only). Returns false if the client is unavailable.
bool nsc_truetone_status(bool *supported, bool *available, bool *enabled);

#ifdef __cplusplus
}
#endif

#endif
