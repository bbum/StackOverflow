//
//  http://stackoverflow.com/questions/17599401/what-advantages-does-dispatch-sync-have-over-synchronized
//
//  Created by Bill Bumgarner on 7/11/13.
//  Copyright (c) 2013 Bill Bumgarner. All rights reserved.
//

// This file will run and never exit (run loop runs forever).
// It also leaks under MRR, but can be compiled/run under either MRR or ARC.

#import <Foundation/Foundation.h>

@interface Sync:NSObject
@property(nonatomic, retain) NSMutableArray *a;
@property(nonatomic, retain) dispatch_queue_t q;
@property(nonatomic) NSUInteger c;
@end
@implementation Sync
- (id)init
{
	self = [super init];
	if (self) {
		_a = [[NSMutableArray alloc] init];
		_q = dispatch_queue_create("array q", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}

- (void) synchronizedAdd:(NSObject*)anObject
{
	@synchronized(self) {
		[_a addObject:anObject];
		[_a removeLastObject];
		_c++;
	}
}

- (void) dispatchSyncAdd:(NSObject*)anObject
{
	dispatch_sync(_q, ^{
		[_a addObject:anObject];
		[_a removeLastObject];
		_c++;
	});
}

- (void) dispatchASyncAdd:(NSObject*)anObject
{
	dispatch_async(_q, ^{
		[_a addObject:anObject];
		[_a removeLastObject];
		_c++;
	});
}

- (void) test
{
#define TESTCASES 1000000
	NSObject *o = [NSObject new];
	NSTimeInterval start;
	NSTimeInterval end;
	
	start = [NSDate timeIntervalSinceReferenceDate];
	_c = 0;
	for(int i = 0; i < TESTCASES; i++ ) {
		[self synchronizedAdd:o];
	}
	end = [NSDate timeIntervalSinceReferenceDate];
	assert(_c == TESTCASES);
	NSLog(@"@synchronized uncontended add: %2.5f seconds", end - start);

	start = [NSDate timeIntervalSinceReferenceDate];
	_c = 0;
	for(int i = 0; i < TESTCASES; i++ ) {
		[self dispatchSyncAdd:o];
	}
	end = [NSDate timeIntervalSinceReferenceDate];
	assert(_c == TESTCASES);
	NSLog(@"Dispatch sync uncontended add: %2.5f seconds", end - start);

	start = [NSDate timeIntervalSinceReferenceDate];
	_c = 0;
	for(int i = 0; i < TESTCASES; i++ ) {
		[self dispatchASyncAdd:o];
	}
	end = [NSDate timeIntervalSinceReferenceDate];
	NSLog(@"Dispatch async uncontended add: %2.5f seconds", end - start);
	
	dispatch_sync(_q, ^{;}); // wait for async stuff to complete
	end = [NSDate timeIntervalSinceReferenceDate];
	assert(_c == TESTCASES);
	NSLog(@"Dispatch async uncontended add completion: %2.5f seconds", end - start);


	dispatch_queue_t serial1 = dispatch_queue_create("serial 1", DISPATCH_QUEUE_SERIAL);
	dispatch_queue_t serial2 = dispatch_queue_create("serial 2", DISPATCH_QUEUE_SERIAL);
	
	dispatch_group_t group = dispatch_group_create();
	
#define TESTCASE_SPLIT_IN_2 (TESTCASES/2)
	start = [NSDate timeIntervalSinceReferenceDate];
	_c = 0;
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		dispatch_apply(TESTCASE_SPLIT_IN_2, serial1, ^(size_t i){
			[self synchronizedAdd:o];
		});
	});
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		dispatch_apply(TESTCASE_SPLIT_IN_2, serial2, ^(size_t i){
			[self synchronizedAdd:o];
		});
	});
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	end = [NSDate timeIntervalSinceReferenceDate];
	assert(_c == TESTCASES);
	NSLog(@"Synchronized, 2 queue: %2.5f seconds", end - start);

	start = [NSDate timeIntervalSinceReferenceDate];
	_c = 0;
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		dispatch_apply(TESTCASE_SPLIT_IN_2, serial1, ^(size_t i){
			[self dispatchSyncAdd:o];
		});
	});
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		dispatch_apply(TESTCASE_SPLIT_IN_2, serial2, ^(size_t i){
			[self dispatchSyncAdd:o];
		});
	});
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	end = [NSDate timeIntervalSinceReferenceDate];
	assert(_c == TESTCASES);
	NSLog(@"Dispatch sync, 2 queue: %2.5f seconds", end - start);

	start = [NSDate timeIntervalSinceReferenceDate];
	_c = 0;
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		dispatch_apply(TESTCASE_SPLIT_IN_2, serial1, ^(size_t i){
			[self dispatchASyncAdd:o];
		});
	});
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		dispatch_apply(TESTCASE_SPLIT_IN_2, serial2, ^(size_t i){
			[self dispatchASyncAdd:o];
		});
	});
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	end = [NSDate timeIntervalSinceReferenceDate];
	NSLog(@"Dispatch async, 2 queue: %2.5f seconds", end - start);
	dispatch_sync(_q, ^{;}); // wait for async stuff to complete
	end = [NSDate timeIntervalSinceReferenceDate];
	assert(_c == TESTCASES);
	NSLog(@"Dispatch async 2 queue add completion: %2.5f seconds", end - start);
}
@end

int main(int argc, const char * argv[])
{
	@autoreleasepool {
		Sync *s = [[Sync alloc] init];
		[s performSelector:@selector(test) withObject:nil afterDelay:0.0];
		[[NSRunLoop currentRunLoop] run];
	}
    return 0;
}

