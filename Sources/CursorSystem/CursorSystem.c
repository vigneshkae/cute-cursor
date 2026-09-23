#include "CursorSystem.h"
#include <dlfcn.h>
#include <pthread.h>
#include <math.h>

// Independently authored, optional bridge to undocumented macOS symbols.
// Resolve at runtime so image editing and preview remain usable without them.
typedef int32_t (*ConnectionFunction)(void);
typedef CGError (*RegisterFunction)(int32_t, const char *, bool, bool, CGSize,
                                  CGPoint, size_t, double, CFArrayRef, int *);
typedef CGError (*ResetFunction)(int32_t);
typedef CGError (*CopyFunction)(int32_t, const char *, CGSize *, CGPoint *, size_t *, double *, CFArrayRef *);
static ConnectionFunction connection;
static RegisterFunction registerCursor;
static ResetFunction resetCursor;
static CopyFunction copyCursor;
static pthread_once_t once = PTHREAD_ONCE_INIT;
// Identifiers verified against the local system registry. Numeric names are
// macOS CoreCursor IDs (not Carbon ThemeCursor constants).
static const char *names[] = {
    "com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS",
    "com.apple.cursor.13", "com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamS",
    "com.apple.cursor.12", "com.apple.cursor.11", "com.apple.cursor.19", "com.apple.cursor.28",
    "com.apple.cursor.23", "com.apple.cursor.32", "com.apple.cursor.34", "com.apple.cursor.30",
    "com.apple.cursor.20", "com.apple.cursor.3"
};
static const int roles[] = {0,0,1,2,2,3,4,5,5,6,6,7,8,9,10};
#define SLOT_COUNT (sizeof(names) / sizeof(names[0]))
typedef struct {
    CGSize size;
    CGPoint point;
    size_t frames;
    double duration;
    CFArrayRef images;
} SavedCursor;
static SavedCursor saved[SLOT_COUNT];

static void resolve(void) {
    void *library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY | RTLD_LOCAL);
    if (!library) return;
    connection = (ConnectionFunction)dlsym(library, "CGSMainConnectionID");
    registerCursor = (RegisterFunction)dlsym(library, "CGSRegisterCursorWithImages");
    resetCursor = (ResetFunction)dlsym(library, "CoreCursorUnregisterAll");
    // Cursor registration lives in SkyLight, while reset is exported through
    // ApplicationServices on current macOS releases.
    void *services = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY | RTLD_LOCAL);
    if (services) {
        if (!resetCursor) resetCursor = (ResetFunction)dlsym(services, "CoreCursorUnregisterAll");
        copyCursor = (CopyFunction)dlsym(services, "CGSCopyRegisteredCursorImages");
    }
}

bool CSSystemAvailable(void) {
    pthread_once(&once, resolve);
    return connection && registerCursor && resetCursor && copyCursor;
}

static void releaseSaved(void) {
    for (size_t i = 0; i < SLOT_COUNT; i++) {
        if (saved[i].images) CFRelease(saved[i].images);
        saved[i].images = NULL;
    }
}

bool CSHasAppliedCursors(void) {
    for (size_t i = 0; i < SLOT_COUNT; i++) if (saved[i].images) return true;
    return false;
}

static CGError registerSaved(size_t i) {
    int seed = 0;
    return registerCursor(connection(), names[i], true, true, saved[i].size, saved[i].point,
                          saved[i].frames, saved[i].duration, saved[i].images, &seed);
}

CFArrayRef CSCreatePointerImages(CGImageRef image, double width, double height) {
    if (!image || !isfinite(width) || !isfinite(height) || width < 1 || height < 1 || width > 64 || height > 64) return NULL;
    // The first bitmap must represent the logical cursor at 1x, followed by
    // a Retina bitmap at 2x. Passing the stored 256px artwork as the 1x image
    // can be accepted by the API without producing a usable system cursor.
    CFMutableArrayRef images = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    for (size_t scale = 1; scale <= 2; scale++) {
        size_t pixelWidth = (size_t)ceil(width * scale);
        size_t pixelHeight = (size_t)ceil(height * scale);
        CGContextRef context = CGBitmapContextCreate(NULL, pixelWidth, pixelHeight, 8, 0, space,
                                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        if (!context) { CGColorSpaceRelease(space); CFRelease(images); return NULL; }
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        CGContextDrawImage(context, CGRectMake(0, 0, pixelWidth, pixelHeight), image);
        CGImageRef representation = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        if (!representation) { CGColorSpaceRelease(space); CFRelease(images); return NULL; }
        CFArrayAppendValue(images, representation);
        CGImageRelease(representation);
    }
    CGColorSpaceRelease(space);
    return images;
}

// Must be called on the main thread, like AppKit's cursor operations.
int32_t CSApplyCursors(const CSCursorDefinition *definitions, size_t count) {
    if (!definitions || count < 1 || count > 11) return -2;
    CFArrayRef bitmaps[11] = {0};
    bool seen[11] = {0};
    bool available[SLOT_COUNT] = {0};
    bool captured[SLOT_COUNT] = {0};
    int result = 0;
    // Validate every definition before touching the registry.
    for (size_t i = 0; i < count; i++) {
        CSCursorDefinition d = definitions[i];
        if (d.role < 0 || d.role >= 11 || seen[d.role] || !isfinite(d.x) || !isfinite(d.y) ||
            d.x < 0 || d.y < 0 || d.x >= d.width || d.y >= d.height) { result = -2; goto cleanup; }
        seen[d.role] = true;
        bitmaps[i] = CSCreatePointerImages(d.image, d.width, d.height);
        if (!bitmaps[i]) { result = -3; goto cleanup; }
    }
    if (!CSSystemAvailable()) { result = -1; goto cleanup; }
    for (size_t d = 0; d < count; d++) {
        int matches = 0;
        for (size_t i = 0; i < SLOT_COUNT; i++) {
            if (roles[i] != definitions[d].role) continue;
            if (saved[i].images) { available[i] = true; matches++; continue; }
            SavedCursor original = {0};
            CGError copied = copyCursor(connection(), names[i], &original.size, &original.point,
                                        &original.frames, &original.duration, &original.images);
            if (copied == 0 && original.images && CFArrayGetCount(original.images) > 0) {
                saved[i] = original; available[i] = true; captured[i] = true; matches++;
            } else if (original.images) CFRelease(original.images);
        }
        if (!matches) { result = -100 - definitions[d].role; goto preflight_failed; }
    }
    // A pack is a complete desired set: restore roles omitted from the new pack.
    for (size_t i = 0; i < SLOT_COUNT; i++) {
        if (saved[i].images && (result = registerSaved(i)) != 0) goto rollback;
    }
    for (size_t d = 0; d < count; d++) {
        CSCursorDefinition definition = definitions[d];
        for (size_t i = 0; i < SLOT_COUNT; i++) {
            if (!available[i] || roles[i] != definition.role) continue;
            int seed = 0;
            result = registerCursor(connection(), names[i], true, true,
                CGSizeMake(definition.width, definition.height), CGPointMake(definition.x, definition.y),
                1, 0, bitmaps[d], &seed);
            if (result != 0) goto rollback;
        }
    }
    goto cleanup;
preflight_failed:
    // No registrations have changed. Preserve an existing active pack.
    for (size_t i = 0; i < SLOT_COUNT; i++) if (captured[i]) { CFRelease(saved[i].images); saved[i].images = NULL; }
    goto cleanup;
rollback:
    // Keep snapshots alive if recovery itself fails; Restore remains available.
    if (CSRestorePointer() != 0) result = -4;
cleanup:
    for (size_t i = 0; i < count; i++) if (bitmaps[i]) CFRelease(bitmaps[i]);
    return result;
}

int32_t CSApplyPointer(CGImageRef image, double width, double height, double x, double y) {
    CSCursorDefinition definition = {0, image, width, height, x, y};
    return CSApplyCursors(&definition, 1);
}

int32_t CSRestorePointer(void) {
    if (!CSSystemAvailable()) return -1;
    // Clear the process cache before re-registering: doing it afterward removes
    // the restored numeric cursor entries on current macOS.
    CGError resetResult = resetCursor(connection());
    CGError firstError = kCGErrorSuccess;
    for (size_t i = 0; i < SLOT_COUNT; i++) {
        if (!saved[i].images) continue;
        CGError result = registerSaved(i);
        if (result != 0 && firstError == 0) firstError = result;
    }
    if (firstError == 0 && resetResult == 0) releaseSaved();
    return firstError == 0 ? resetResult : firstError;
}
