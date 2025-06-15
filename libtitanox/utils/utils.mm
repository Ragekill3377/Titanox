#import "utils.h"
#import <stdarg.h>
#import <pthread.h>
#import <sys/utsname.h>

// had to do some caching because apparently this shit was causing some overhead???
static NSDateFormatter *sharedFormatter() {
    static NSDateFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    });
    return fmt;
}

NSString *THGetTimestamp() {
    return [sharedFormatter() stringFromDate:[NSDate date]];
}

NSString *THGetThreadID() {
    return [NSString stringWithFormat:@"%lu", (unsigned long)pthread_self()];
}

NSString *THGetDocumentsPath() {
    static NSString *docsPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        docsPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject path];
    });
    return docsPath;
}

NSURL *THGetLogFileURL() {
    static NSURL *logURL = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logURL = [NSURL fileURLWithPath:[THGetDocumentsPath() stringByAppendingPathComponent:@"TITANOX_LOGS.txt"]];
    });
    return logURL;
}

void THWriteToFile(NSString *text, NSURL *fileURL) {
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];
    if (fh) {
        [fh seekToEndOfFile];
        NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            [fh writeData:data];
        }
        [fh closeFile];
    } else {
        [text writeToFile:fileURL.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

NSString *THReadFile(NSURL *fileURL) {
    return [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil];
}

BOOL THFileExists(NSURL *fileURL) {
    return [[NSFileManager defaultManager] fileExistsAtPath:fileURL.path];
}

void THDeleteFile(NSURL *fileURL) {
    if (THFileExists(fileURL)) {
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    }
}

NSString *THDeviceName() {
    struct utsname sysInfo;
    uname(&sysInfo);
    return [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
}

NSString *THAppName() {
    static NSString *appName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    });
    return appName;
}

NSString *THAppVersion() {
    static NSString *appVersion = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    });
    return appVersion;
}

void THLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *entry = [NSString stringWithFormat:@"[%@] [Thread: %@] %@", THGetTimestamp(), THGetThreadID(), msg];

    NSLog(@"%@", entry);
    THWriteToFile([entry stringByAppendingString:@"\n"], THGetLogFileURL());
}
