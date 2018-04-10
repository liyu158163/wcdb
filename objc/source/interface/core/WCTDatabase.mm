/*
 * Tencent is pleased to support the open source community by making
 * WCDB available.
 *
 * Copyright (C) 2017 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use
 * this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 *       https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <WCDB/Interface.h>
#import <WCDB/WCTCore+Private.h>
#import <WCDB/WCTError+Private.h>
#import <WCDB/WCTUnsafeHandle+Private.h>

@implementation WCTDatabase

#if TARGET_OS_IPHONE
+ (void)initialize
{
    WCDB::SQLiteGlobal::shared()->hookVFSDidFileCreated([](const char *path) {
        if (!path) {
            return;
        }
        WCTFileOperation operation;
        NSError *error = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *nsPath = @(path);
        operation = WCTFileOperationGetAttribute;
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:nsPath error:&error];
        if (attributes) {
            NSString *fileProtection = [attributes objectForKey:NSFileProtectionKey];
            if ([fileProtection isEqualToString:NSFileProtectionCompleteUntilFirstUserAuthentication] || [fileProtection isEqualToString:NSFileProtectionNone]) {
                return;
            }
            operation = WCTFileOperationSetAttribute;
            NSDictionary *fileProtectionAttribute = @{NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication};
            [fileManager setAttributes:fileProtectionAttribute
                          ofItemAtPath:nsPath
                                 error:&error];
#ifdef DEBUG
            //only for testing
            [fileManager createFileAtPath:[nsPath stringByAppendingString:@"-fileProtection"]
                                 contents:[NSData data]
                               attributes:nil];
#endif
        }
        if (error) {
            WCDB::FileError fileError;
            fileError.operation = (WCDB::FileError::Operation) operation;
            fileError.path = path;
            fileError.level = WCDB::Error::Level::Error;
            fileError.code = (int) error.code;
            fileError.message = error.description.UTF8String;
            fileError.report();
        }
    });
}
#endif //TARGET_OS_IPHONE

- (instancetype)initWithPath:(NSString *)path
{
    if (self = [super initWithDatabase:WCDB::Database::databaseWithPath(path.UTF8String)]) {
    }
    return self;
}

- (instancetype)initWithExistingTag:(WCTTag)tag
{
    return [super initWithDatabase:WCDB::Database::databaseWithExistingTag(tag)];
}

- (void)setTag:(WCTTag)tag
{
    _database->setTag(tag);
}

- (BOOL)canOpen
{
    return _database->canOpen();
}

- (BOOL)isOpened
{
    return _database->isOpened();
}

- (void)close
{
    _database->close(nullptr);
}

- (void)close:(WCTCloseBlock)onClosed
{
    std::function<void(void)> callback = nullptr;
    if (onClosed) {
        callback = [onClosed]() {
            onClosed();
        };
    }
    _database->close(callback);
}

- (BOOL)isBlockaded
{
    return _database->isBlockaded();
}

- (void)blockade
{
    _database->blockade();
}

- (bool)blockadeUntilDone:(WCTBlockadeBlock)onBlockaded
{
    return _database->blockadeUntilDone([onBlockaded, self](WCDB::Handle *handle) {
        onBlockaded([[WCTHandle alloc] initWithDatabase:_database andHandle:handle]);
    });
}

- (void)unblockade
{
    _database->unblockade();
}

- (WCTError *)error
{
    return [WCTError errorWithWCDBError:_database->getError()];
}

@end
