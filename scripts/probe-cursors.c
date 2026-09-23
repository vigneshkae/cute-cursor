// Read-only cross-process diagnostic for the system cursor registry.
// Compile: clang scripts/probe-cursors.c -framework ApplicationServices -o /tmp/cursor-probe
#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdint.h>

typedef int32_t (*Connection)(void);
typedef CGError (*CopyImages)(int32_t, const char *, CGSize *, CGPoint *, size_t *, double *, CFArrayRef *);

int main(void) {
    void *library = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY);
    Connection connection = (Connection)dlsym(library, "CGSMainConnectionID");
    CopyImages copy = (CopyImages)dlsym(library, "CGSCopyRegisteredCursorImages");
    if (!connection || !copy) return 2;
    const char *names[] = {"com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS", "com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamS"};
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        CGSize size = CGSizeZero; CGPoint point = CGPointZero;
        size_t frames = 0; double duration = 0; CFArrayRef images = NULL;
        CGError result = copy(connection(), names[i], &size, &point, &frames, &duration, &images);
        printf("%s result=%d size=%.1fx%.1f point=%.2f,%.2f frames=%zu", names[i], result, size.width, size.height, point.x, point.y, frames);
        if (images) {
            for (CFIndex j = 0; j < CFArrayGetCount(images); j++) {
                CGImageRef image = (CGImageRef)CFArrayGetValueAtIndex(images, j);
                if (!image || CFGetTypeID(image) != CGImageGetTypeID()) continue;
                CFDataRef pixels = CGDataProviderCopyData(CGImageGetDataProvider(image));
                uint64_t hash = 14695981039346656037ULL;
                if (pixels) {
                    const UInt8 *data = CFDataGetBytePtr(pixels);
                    for (CFIndex k = 0; k < CFDataGetLength(pixels); k++) { hash ^= data[k]; hash *= 1099511628211ULL; }
                    CFRelease(pixels);
                }
                printf(" image=%zux%zu hash=%016llx", CGImageGetWidth(image), CGImageGetHeight(image), (unsigned long long)hash);
            }
            CFRelease(images);
        }
        printf("\n");
    }
}
