#pragma once

#import <Foundation/Foundation.h>

void THLog(NSString *format, ...);
NSString *THGetTimestamp();
NSString *THGetThreadID();
NSString *THGetDocumentsPath();
NSURL *THGetLogFileURL();
void THWriteToFile(NSString *text, NSURL *fileURL);
NSString *THReadFile(NSURL *fileURL);
BOOL THFileExists(NSURL *fileURL);
void THDeleteFile(NSURL *fileURL);
NSString *THDeviceName();
NSString *THAppName();
NSString *THAppVersion();
