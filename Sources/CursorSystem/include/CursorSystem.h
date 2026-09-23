#pragma once
#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>

bool CSSystemAvailable(void);
CFArrayRef CSCreatePointerImages(CGImageRef image, double width, double height) CF_RETURNS_RETAINED;
int32_t CSApplyPointer(CGImageRef image, double width, double height, double x, double y);
int32_t CSRestorePointer(void);

// Stable role order: pointer, link, text, grab, grabbing, horizontal, vertical,
// diagonal NW-SE, diagonal NE-SW, crosshair, not allowed.
typedef struct {
    int32_t role;
    CGImageRef image;
    double width, height, x, y;
} CSCursorDefinition;
int32_t CSApplyCursors(const CSCursorDefinition *definitions, size_t count);
bool CSHasAppliedCursors(void);
