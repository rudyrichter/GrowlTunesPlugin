//
//  GTPController.m
//  GrowlTunes
//
//  Created by Rudy Richter on 9/27/09.
//  Copyright 2009 The Growl Project. All rights reserved.
//

#import "GTPController.h"
#import <Growl/Growl.h>

@implementation GTPController

@synthesize settings = _settings;
@synthesize notification = _notification;
@synthesize keyCombo = _keyCombo;

- (void)setup
{
	NSString *privateFrameworksPath = [[NSBundle bundleForClass:[self class]] privateFrameworksPath];
	NSString *ShortcutRecorderPath = [privateFrameworksPath stringByAppendingPathComponent:@"ShortcutRecorder.framework"];
	NSString *GrowlPath = [privateFrameworksPath stringByAppendingPathComponent:@"Growl.framework"];
	
	[[NSBundle bundleWithPath:ShortcutRecorderPath] load];
	[[NSBundle bundleWithPath:GrowlPath] load];
	
	NSInteger keyCode = -1;
	NSInteger modifiers = -1;
	
	//read the settings
	[self setSettings:[[[NSUserDefaults standardUserDefaults] persistentDomainForName:GTPBundleIdentifier] mutableCopy]];
	if(![self settings])
	{
		NSMutableDictionary *settings = [NSMutableDictionary dictionary];
		[settings setValue:[NSNumber numberWithInteger:40] forKey:GTPKeyCode];
		[settings setValue:[NSNumber numberWithInteger:(cmdKey | shiftKey)] forKey:GTPModifiers];
		[settings setValue:mDefaultTitleFormat forKey:@"titleString"];
		[settings setValue:mDefaultMessageFormat forKey:@"descriptionString"];
		[settings setValue:[NSNumber numberWithBool:NO] forKey:@"notifyInBGOnly"];
		[self setSettings:settings];
		[[NSUserDefaults standardUserDefaults] setPersistentDomain:[self settings] forName:GTPBundleIdentifier];
		
	}
	keyCode = [[[self settings] valueForKey:GTPKeyCode] integerValue];
	modifiers = [[[self settings] valueForKey:GTPModifiers] integerValue];
						  
	//configure the hotkey
	_keyCombo = [[SGKeyCombo alloc] initWithKeyCode:keyCode modifiers:modifiers];
	SGHotKey *hotKey = [[[SGHotKey alloc] initWithIdentifier:GTPBundleIdentifier keyCombo:_keyCombo target:self action:@selector(showCurrentTrack:)] autorelease];
	[[SGHotKeyCenter sharedCenter] registerHotKey:hotKey];
	
	//setup growl
	[NSClassFromString(@"GrowlApplicationBridge") setGrowlDelegate:self];

	[self setNotification:[GTPNotification notification]];
	
	[[self notification] setTitleFormat:[[self settings] objectForKey:@"titleString"]];
	[[self notification] setDescriptionFormat:[[self settings] objectForKey:@"descriptionString"]];
}

- (void)sendNotification:(id)sender
{
#pragma unused(sender)
	BOOL notifyInBGOnly = [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:GTPBundleIdentifier] valueForKey:@"notifyInBGOnly"] boolValue];
	NSLog(@"GTP: %d %d", notifyInBGOnly, [self appInBackground]);
	if((notifyInBGOnly && [self appInBackground]) || !notifyInBGOnly)
		[self showCurrentTrack:nil];
}

- (BOOL)appInBackground
{
	Boolean result = NO;
	
	ProcessSerialNumber frontProcess;
	ProcessSerialNumber currentProcess;
	
	GetFrontProcess(&frontProcess);
	GetCurrentProcess(&currentProcess);
	SameProcess(&frontProcess, &currentProcess, &result);
	
	return !result;
}

- (void)showCurrentTrack:(id)sender
{
#pragma unused(sender)
	NSDictionary *noteDict = [[self notification] dictionary];
    NSMutableDictionary *result = [[noteDict mutableCopy] autorelease];
    [result removeObjectForKey:GROWL_NOTIFICATION_ICON_DATA];
    NSLog(@"dictionary, %@", result);
	[GrowlApplicationBridge notifyWithTitle:[noteDict objectForKey:GROWL_NOTIFICATION_TITLE]
                                description:[noteDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]
                           notificationName:[noteDict objectForKey:GROWL_NOTIFICATION_NAME]
                                   iconData:[noteDict objectForKey:GROWL_NOTIFICATION_ICON_DATA]
                                   priority:0
                                   isSticky:0
                               clickContext:nil
                                 identifier:[noteDict objectForKey:GROWL_NOTIFICATION_IDENTIFIER]];
    //[GrowlApplicationBridge notifyWithDictionary:noteDict];
}

- (void)showSettingsWindow
{	
	if(!_settingsWindow)
		_settingsWindow = [[GTPSettingsWindowController alloc] initWithWindowNibName:@"Settings"];
	[_settingsWindow setDelegate:self];
	[_settingsWindow setKeyCombo:_keyCombo];
	[_settingsWindow showWindow:self];
	
}

- (NSData*)artworkForTitle:(NSString *)track byArtist:(NSString *)artist onAlbum:(NSString *)album composedBy:(NSString*)composer isCompilation:(BOOL)compilation
{
	NSLog(@"artworkForTitle: %@ %@ %@ %@ %d", track, artist, album, composer, compilation);
	NSData *result;
	NSImage *artwork = nil;
	

	result = [artwork TIFFRepresentation];
	return [result autorelease];
}

#pragma mark GrowlApplicationBridgeDelegate

- (NSDictionary *)registrationDictionaryForGrowl 
{
	NSArray	*allNotes = [[NSArray alloc] initWithObjects:
						 ITUNES_TRACK_CHANGED,
						 ITUNES_PLAYING,
						 nil];
	
	NSDictionary *readableNames = [NSDictionary dictionaryWithObjectsAndKeys:
								   NSLocalizedString(@"Changed Tracks", nil), ITUNES_TRACK_CHANGED,
								   NSLocalizedString(@"Started Playing", nil), ITUNES_PLAYING,
								   nil];
	
	NSImage			*iTunesIcon = [[NSWorkspace sharedWorkspace] iconForApplication:ITUNES_APP_NAME];
	NSDictionary	*regDict = [NSDictionary dictionaryWithObjectsAndKeys:
								APP_NAME,                        GROWL_APP_NAME,
								[iTunesIcon TIFFRepresentation], GROWL_APP_ICON_DATA,
								allNotes,                        GROWL_NOTIFICATIONS_ALL,
								allNotes,                        GROWL_NOTIFICATIONS_DEFAULT,
								readableNames,					 GROWL_NOTIFICATIONS_HUMAN_READABLE_NAMES,
								nil];
	[allNotes release];
	return regDict;
}

- (NSString *)applicationNameForGrowl 
{
	return APP_NAME;
}

#pragma mark GTPSettingsWindowController Delegate
- (void)keyComboChanged:(SGKeyCombo*)newCombo
{
	[self setKeyCombo:newCombo];
	
	SGHotKey *hotKey = [[[SGHotKey alloc] initWithIdentifier:GTPBundleIdentifier keyCombo:newCombo target:self action:@selector(showCurrentTrack:)] autorelease];
	[[SGHotKeyCenter sharedCenter] registerHotKey:hotKey];
}

- (void)titleStringChanged:(NSString*)newTitle
{
#pragma unused(newTitle)
}

- (void)descriptionStringChanged:(NSString*)newDescription
{
#pragma unused(newDescription)
	
}

@end