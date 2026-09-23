// Deterministic registry-failure tests. Uses an in-memory fake, never changes
// system cursors. Including the bridge permits replacing its private callbacks.
#include "../Sources/CursorSystem/CursorSystem.c"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static SavedCursor registry[SLOT_COUNT];
static bool missing[SLOT_COUNT];
static int registrationCalls, failAt, failuresRemaining;
static int32_t fakeConnection(void) { return 1; }
static int lookup(const char *name) {
    for (int i = 0; i < (int)SLOT_COUNT; i++) if (strcmp(names[i], name) == 0) return i;
    return -1;
}
static CGError fakeCopy(int32_t c, const char *name, CGSize *size, CGPoint *point, size_t *frames, double *duration, CFArrayRef *images) {
    int i = lookup(name);
    if (i < 0 || missing[i]) return kCGErrorFailure;
    *size = registry[i].size; *point = registry[i].point; *frames = 1; *duration = 0;
    *images = CFRetain(registry[i].images); return 0;
}
static CGError fakeRegister(int32_t c, const char *name, bool a, bool b, CGSize size, CGPoint point, size_t frames, double duration, CFArrayRef images, int *seed) {
    registrationCalls++;
    if (registrationCalls >= failAt && failuresRemaining > 0) { failuresRemaining--; return kCGErrorFailure; }
    int i = lookup(name); assert(i >= 0);
    CFRelease(registry[i].images); registry[i] = (SavedCursor){size, point, frames, duration, CFRetain(images)};
    return 0;
}
static CGError fakeReset(int32_t c) { return 0; }

int main(void) {
    // Resolve once without invoking any system registry operation, then use fakes.
    pthread_once(&once, resolve);
    connection = fakeConnection; copyCursor = fakeCopy; registerCursor = fakeRegister; resetCursor = fakeReset;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 32, 32, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGImageRef image = CGBitmapContextCreateImage(context);
    CFArrayRef original = CSCreatePointerImages(image, 20, 20);
    for (size_t i = 0; i < SLOT_COUNT; i++) registry[i] = (SavedCursor){CGSizeMake(20,20), CGPointMake(2,2), 1, 0, CFRetain(original)};
    CSCursorDefinition pointer = {0,image,32,32,3,4};
    CSCursorDefinition link = {1,image,24,24,5,6};
    assert(CSApplyCursors(&pointer,1) == 0);
    assert(registry[0].size.width == 32);
    // Missing-role preflight must leave the previous active pointer unchanged.
    missing[2] = true;
    assert(CSApplyCursors(&link,1) == -101);
    assert(registry[0].size.width == 32 && CSHasAppliedCursors());
    missing[2] = false;
    // Fail after originals have been restored and a new registration attempted.
    registrationCalls = 0; failAt = 4; failuresRemaining = 1;
    assert(CSApplyCursors(&link,1) != 0);
    assert(!CSHasAppliedCursors());
    for (size_t i = 0; i < SLOT_COUNT; i++) assert(registry[i].size.width == 20 && registry[i].point.x == 2);
    // If rollback also fails, retain originals so an explicit retry can recover.
    registrationCalls = 0; failAt = 2; failuresRemaining = 2;
    assert(CSApplyCursors(&pointer,1) == -4);
    assert(CSHasAppliedCursors());
    failuresRemaining = 0;
    assert(CSRestorePointer() == 0 && !CSHasAppliedCursors());
    for (size_t i = 0; i < SLOT_COUNT; i++) { assert(registry[i].size.width == 20); CFRelease(registry[i].images); }
    CFRelease(original); CGImageRelease(image); CGContextRelease(context); CGColorSpaceRelease(space);
    puts("Cursor transactions: PASS (preflight, rollback, failed rollback, recovery retry)");
    return 0;
}
