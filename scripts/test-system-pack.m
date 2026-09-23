// Opt-in graphical-session integration test: briefly changes and restores the
// system pointer. Compile with Sources/CursorSystem/CursorSystem.c, include its
// include/ directory, and link ApplicationServices. Do not run in CI by default.
#import <Cocoa/Cocoa.h>
#include "CursorSystem.h"
#include <dlfcn.h>
#include <stdio.h>
#include <math.h>

typedef int32_t (*Connection)(void);
typedef CGError (*Copy)(int32_t, const char *, CGSize *, CGPoint *, size_t *, double *, CFArrayRef *);
typedef struct { CGSize size; CGPoint point; size_t frames; double duration; CFArrayRef images; } Snapshot;

static bool equalImages(CFArrayRef a, CFArrayRef b) {
    if (!a || !b || CFArrayGetCount(a) != CFArrayGetCount(b)) return false;
    for (CFIndex i = 0; i < CFArrayGetCount(a); i++) {
        CGImageRef ai = (CGImageRef)CFArrayGetValueAtIndex(a, i);
        CGImageRef bi = (CGImageRef)CFArrayGetValueAtIndex(b, i);
        if (CGImageGetWidth(ai) != CGImageGetWidth(bi) || CGImageGetHeight(ai) != CGImageGetHeight(bi)) return false;
        CFDataRef ad = CGDataProviderCopyData(CGImageGetDataProvider(ai));
        CFDataRef bd = CGDataProviderCopyData(CGImageGetDataProvider(bi));
        bool same = ad && bd && CFEqual(ad, bd);
        if (ad) CFRelease(ad);
        if (bd) CFRelease(bd);
        if (!same) return false;
    }
    return true;
}

int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    for (NSCursor *cursor in @[[NSCursor arrowCursor], [NSCursor IBeamCursor], [NSCursor pointingHandCursor],
        [NSCursor openHandCursor], [NSCursor closedHandCursor], [NSCursor resizeLeftRightCursor],
        [NSCursor resizeUpDownCursor], [NSCursor crosshairCursor], [NSCursor operationNotAllowedCursor]]) { (void)[cursor image]; }
    if (@available(macOS 15.0, *)) {
        for (NSNumber *position in @[@(NSCursorFrameResizePositionTopLeft), @(NSCursorFrameResizePositionTopRight),
                @(NSCursorFrameResizePositionLeft), @(NSCursorFrameResizePositionTop)]) {
            (void)[[NSCursor frameResizeCursorFromPosition:position.unsignedIntegerValue inDirections:NSCursorFrameResizeDirectionsAll] image];
        }
    }
    if (!CSSystemAvailable()) return 2;
    void *lib = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY);
    Connection connection = (Connection)dlsym(lib, "CGSMainConnectionID");
    Copy copy = (Copy)dlsym(lib, "CGSCopyRegisteredCursorImages");
    const char *names[] = {"com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS", "com.apple.cursor.13",
        "com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamS", "com.apple.cursor.12", "com.apple.cursor.11",
        "com.apple.cursor.19", "com.apple.cursor.28", "com.apple.cursor.23", "com.apple.cursor.32",
        "com.apple.cursor.34", "com.apple.cursor.30", "com.apple.cursor.20", "com.apple.cursor.3"};
    enum { count = 15 };
    Snapshot before[count] = {0};
    bool present[count] = {0};
    for (int i = 0; i < count; i++) {
        present[i] = copy(connection(), names[i], &before[i].size, &before[i].point, &before[i].frames, &before[i].duration, &before[i].images) == 0;
        printf("%s: %s\n", names[i], present[i] ? "available" : "missing");
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 128, 128, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 0.43, 0.32, 0.78, 1);
    CGContextFillEllipseInRect(context, CGRectMake(20, 20, 88, 88));
    CGImageRef image = CGBitmapContextCreateImage(context);
    int failure = 0;
    for (int size = 24; size <= 32; size += 8) {
        CSCursorDefinition definitions[11];
        for (int i = 0; i < 11; i++) definitions[i] = (CSCursorDefinition){i, image, size, size, 3, 4};
        int result = CSApplyCursors(definitions, 11);
        printf("Apply 11 roles: %d\n", result);
        if (result) { failure = 4; break; }
        for (int i = 0; i < count; i++) {
            if (!present[i]) continue;
            Snapshot current = {0};
            if (copy(connection(), names[i], &current.size, &current.point, &current.frames, &current.duration, &current.images) || current.size.width != size || current.point.x != 3 || current.point.y != 4) failure = 5;
            if (current.images) CFRelease(current.images);
        }
    }
    // Switching to a pointer-only pack must restore every omitted role.
    if (!failure && CSApplyPointer(image, 28, 28, 2, 3)) failure = 8;
    for (int i = 2; i < count && !failure; i++) {
        if (!present[i]) continue;
        Snapshot after = {0};
        if (copy(connection(), names[i], &after.size, &after.point, &after.frames, &after.duration, &after.images) ||
            !CGSizeEqualToSize(after.size, before[i].size) || !CGPointEqualToPoint(after.point, before[i].point) ||
            !equalImages(after.images, before[i].images)) failure = 9;
        if (after.images) CFRelease(after.images);
    }
    if (CSRestorePointer()) failure = 6;
    for (int i = 0; i < count; i++) {
        if (!present[i]) continue;
        Snapshot after = {0};
        if (copy(connection(), names[i], &after.size, &after.point, &after.frames, &after.duration, &after.images) ||
            !CGSizeEqualToSize(after.size, before[i].size) || !CGPointEqualToPoint(after.point, before[i].point) ||
            !equalImages(after.images, before[i].images)) failure = 7;
        printf("%s: restored pixels %s\n", names[i], equalImages(after.images, before[i].images) ? "match" : "DIFFER");
        if (before[i].images) CFRelease(before[i].images);
        if (after.images) CFRelease(after.images);
    }
    if (CSHasAppliedCursors()) failure = 10;
    CGImageRelease(image); CGContextRelease(context); CGColorSpaceRelease(space);
    printf("System pack integration: %s (code %d)\n", failure ? "FAIL" : "PASS", failure);
    return failure;
} }
