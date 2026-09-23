// Opt-in graphical-session integration test: briefly changes and restores the
// system pointer. Compile with Sources/CursorSystem/CursorSystem.c, include its
// include/ directory, and link ApplicationServices. Do not run in CI by default.
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

int main(void) {
    if (!CSSystemAvailable()) return 2;
    void *lib = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY);
    Connection connection = (Connection)dlsym(lib, "CGSMainConnectionID");
    Copy copy = (Copy)dlsym(lib, "CGSCopyRegisteredCursorImages");
    const char *names[] = {"com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS"};
    Snapshot before[2] = {0};
    for (int i = 0; i < 2; i++) {
        if (copy(connection(), names[i], &before[i].size, &before[i].point, &before[i].frames, &before[i].duration, &before[i].images)) return 3;
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 128, 128, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 0.43, 0.32, 0.78, 1);
    CGContextFillEllipseInRect(context, CGRectMake(20, 20, 88, 88));
    CGImageRef image = CGBitmapContextCreateImage(context);
    int failure = 0;
    for (int size = 24; size <= 32; size += 8) {
        if (CSApplyPointer(image, size, size, 3, 4)) { failure = 4; break; }
        for (int i = 0; i < 2; i++) {
            Snapshot current = {0};
            if (copy(connection(), names[i], &current.size, &current.point, &current.frames, &current.duration, &current.images) || current.size.width != size || current.point.x != 3 || current.point.y != 4) failure = 5;
            if (current.images) CFRelease(current.images);
        }
    }
    if (CSRestorePointer()) failure = 6;
    for (int i = 0; i < 2; i++) {
        Snapshot after = {0};
        if (copy(connection(), names[i], &after.size, &after.point, &after.frames, &after.duration, &after.images) ||
            !CGSizeEqualToSize(after.size, before[i].size) || !CGPointEqualToPoint(after.point, before[i].point) ||
            !equalImages(after.images, before[i].images)) failure = 7;
        printf("%s: restored %.0fx%.0f, original %.0fx%.0f, pixels %s\n", names[i], after.size.width, after.size.height,
               before[i].size.width, before[i].size.height, equalImages(after.images, before[i].images) ? "match" : "DIFFER");
        if (before[i].images) CFRelease(before[i].images);
        if (after.images) CFRelease(after.images);
    }
    CGImageRelease(image); CGContextRelease(context); CGColorSpaceRelease(space);
    printf("System cursor integration: %s (code %d)\n", failure ? "FAIL" : "PASS", failure);
    return failure;
}
