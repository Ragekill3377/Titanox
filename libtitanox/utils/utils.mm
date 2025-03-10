#import "utils.h"
#import <stdarg.h>
#import <pthread.h>
#import <sys/utsname.h>

NSString *THGetTimestamp() {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    return [formatter stringFromDate:[NSDate date]];
}

NSString *THGetThreadID() {
    return [NSString stringWithFormat:@"%lu", (unsigned long)pthread_self()];
}

NSString *THGetDocumentsPath() {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject path];
}

NSURL *THGetLogFileURL() {
    return [NSURL fileURLWithPath:[THGetDocumentsPath() stringByAppendingPathComponent:@"TITANOX_LOGS.txt"]];
}

void THWriteToFile(NSString *text, NSURL *fileURL) {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];
    if (!fileHandle) {
        [text writeToFile:fileURL.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
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
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

NSString *THAppName() {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
}

NSString *THAppVersion() {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}


void THLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *logEntry = [NSString stringWithFormat:@"[%@] [Thread: %@] %@", THGetTimestamp(), THGetThreadID(), message];

    NSLog(@"%@", logEntry);
    THWriteToFile([logEntry stringByAppendingString:@"\n"], THGetLogFileURL());
}