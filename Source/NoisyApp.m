/*
 * Copyright (c) 2010, Jon Shea <http:jonshea.com>
 * Copyright (c) 2008, Noisy Developers
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY Noisy Developers ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL Noisy Developers BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "NoisyApp.h"
#import "NoiseGenerator.h"

static NSString *sNoiseTypeKeyPath   = @"NoiseType";
static NSString *sPreviousNoiseTypeKeyPath = @"PreviousNoiseType";
static NSString *sNoiseVolumeKeyPath = @"NoiseVolume";

@implementation NoisyApp

+ (void)initialize
{
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    
    [defaults setObject:[NSNumber numberWithInteger:BrownNoiseType] forKey:sNoiseTypeKeyPath];
    [defaults setObject:[NSNumber numberWithInteger:BrownNoiseType] forKey:sNoiseTypeKeyPath];
    [defaults setObject:[NSNumber numberWithDouble:0.2] forKey:sNoiseVolumeKeyPath];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)awakeFromNib
{
    _generator = [[NoiseGenerator alloc] init];
    
    [self setVolume:[[NSUserDefaults standardUserDefaults] doubleForKey:sNoiseVolumeKeyPath]];
    
    //    int p = [[NSUserDefaults standardUserDefaults] integerForKey:sPreviousNoiseTypeKeyPath];
    [self setNoiseType:[[NSUserDefaults standardUserDefaults] integerForKey:sNoiseTypeKeyPath]];
    previousNoiseType = [[NSUserDefaults standardUserDefaults] integerForKey:sPreviousNoiseTypeKeyPath];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(handleWorkspaceWillSleepNotification:) name:NSWorkspaceWillSleepNotification object:NULL];
}


- (void)dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    
    [_generator release];
    
    [super dealloc];
}

- (double)volume {
    return [_generator volume];
}

- (void)setVolume:(double)newVolume {
    if (newVolume < sNoiseMinVolume) {
        newVolume = sNoiseMinVolume;
    }
    else if (newVolume > sNoiseMaxVolume) {
        newVolume = sNoiseMaxVolume;
    }
    
    [[NSUserDefaults standardUserDefaults] setDouble:newVolume forKey:sNoiseVolumeKeyPath];
    [_generator setVolume:newVolume];
}

- (int)noiseType {
    return [_generator type];
}

- (void)setNoiseType:(int)newNoiseType {
    // Save the previous noise type, unless the previous noise type was 'NoNoise'
    if ([self noiseType] != NoNoiseType) {
        previousNoiseType = [self noiseType];
        [[NSUserDefaults standardUserDefaults] setInteger:previousNoiseType forKey:sPreviousNoiseTypeKeyPath];
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:newNoiseType forKey:sNoiseTypeKeyPath];
    [_generator setType:newNoiseType];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setupStatusMenu];
}

- (id)setupStatusMenu
{
    self.statusItem       = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.image = [NSImage imageNamed:@"statusbar_icon.png"];
    [_statusItem.image setTemplate:YES]; // Set blue bg when clicked & enable inverted colors in Dark Mode
    
    NSMenu *menu       = [[NSMenu alloc] init];
    NSArray *menuItems = [self menuItems];
    
    for(int i = 0; i < [menuItems count]; i++) {
        [menu addItem:[menuItems objectAtIndex:i]];
    }
    _statusItem.menu = menu;
    return _statusItem;
}

- (id)menuItems
{
    NSMutableArray *menuItems = [NSMutableArray array];
    
    [menuItems addObject:[[NSMenuItem alloc] initWithTitle:@"About Noisy"  // About
                                                    action:@selector(orderFrontStandardAboutPanel:)
                                             keyEquivalent:@""]];
    [menuItems addObject:[NSMenuItem separatorItem]];                     // Divider
    [menuItems addObject:[self menuTypesSubmenu]];                        // Noise Color
    [menuItems addObject:[[NSMenuItem alloc] initWithTitle:@"Volume"      // Volume Label
                                                    action:nil
                                             keyEquivalent:@""]];
    [menuItems addObject:[self menuVolumeSlider]];                        // Volume Slider
    [menuItems addObject:[NSMenuItem separatorItem]];                     // Divider
    [menuItems addObject:[[NSMenuItem alloc] initWithTitle:@"Quit Noisy"  // Quit
                                                    action:@selector(terminate:)
                                             keyEquivalent:@""]];
    
    return menuItems;
}

- (id)menuTypesSubmenu
{
    NSMenuItem *menuTypes = [[NSMenuItem alloc] init];
    NSMenu *menuTypesSubmenu  = [[NSMenu alloc] init];
    
    NSMutableArray *submenuItems = [NSMutableArray array];
    NSArray *submenuLabels       = @[@"White", @"Pink", @"Brown"];
    NSInteger *submenuTags[3]    = {WhiteNoiseType, PinkNoiseType, BrownNoiseType};
    
    for(int i = 0; i < [submenuLabels count]; i++) {
        [submenuItems addObject:[[NSMenuItem alloc] initWithTitle:[submenuLabels objectAtIndex:i]
                                                           action:@selector(setTypeAction:)
                                                    keyEquivalent:@""]];
        [[submenuItems objectAtIndex:i] setTag:submenuTags[i]];
        [menuTypesSubmenu addItem:[submenuItems objectAtIndex:i]];
    }
    
    menuTypes.title   = @"Noise Color";
    menuTypes.submenu = menuTypesSubmenu;
    return menuTypes;
}

- (id)menuVolumeSlider
{
    NSMenuItem *menuVol   = [[NSMenuItem alloc] init];
    NSSlider *slider      = [[NSSlider alloc] init];
    
    slider.frame          = NSMakeRect ( 0, 0, 180, 20 ); // FIX ME – slider is not centered!
    slider.action         = @selector(setVolumeAction:);
    slider.doubleValue    = 0.2;
    slider.minValue       = 0.0;
    slider.maxValue       = 1.0;
    
    menuVol.view          = slider;
    return menuVol;
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    if ([menuItem action] == @selector(setTypeAction:))
        [menuItem setState:([menuItem tag] == [self noiseType]) ? NSOnState : NSOffState];
    return YES;
}

- (void)setTypeAction:(id)sender {
    [self setNoiseType:[sender tag]];
    [self validateMenuItem:sender];
}

- (void)setVolumeAction:(id)sender {
    [_generator setVolume:[sender doubleValue]];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [oWindow makeKeyAndOrderFront:self];
    return YES;
}

- (void)handleWorkspaceWillSleepNotification:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setInteger:NoNoiseType forKey:sNoiseTypeKeyPath];
}

#pragma mark -
#pragma mark AppleScript

- (id) scriptNoiseType
{
    NoiseType type = [[NSUserDefaults standardUserDefaults] integerForKey:sNoiseTypeKeyPath];
    OSType scriptType;
    
    if (type == WhiteNoiseType) {
        scriptType = 'Nwht';
    } else if (type == PinkNoiseType) {
        scriptType = 'Npnk';
    } else {
        scriptType = 'Nnon';
    }
    
    return [[[NSNumber alloc] initWithUnsignedInteger:scriptType] autorelease];
}


- (void)setScriptNoiseType:(id)scriptTypeAsNumber
{
    OSType scriptType = [scriptTypeAsNumber unsignedIntegerValue];
    NoiseType type;
    
    if (scriptType == 'Nnon') {
        type = NoNoiseType;
    } else if (scriptType == 'Npnk') {
        type = PinkNoiseType;
    } else if (scriptType == 'Nwht') {
        type = WhiteNoiseType;
    } else {
        type = NoNoiseType;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:type forKey:sNoiseTypeKeyPath];
}


- (id)scriptVolume
{
    double volume = [[NSUserDefaults standardUserDefaults] doubleForKey:sNoiseVolumeKeyPath];
    NSInteger roundedVolume = round(volume * 100);
    return [NSNumber numberWithInteger:roundedVolume];
}


- (void)setScriptVolume:(id)volumeAsNumber
{
    double volume = [volumeAsNumber doubleValue];
    
    volume /= 100.0;
    if (volume > 100.0) volume = 100.0;
    if (volume < 0.0)   volume = 0.0;
    
    [[NSUserDefaults standardUserDefaults] setDouble:volume forKey:sNoiseVolumeKeyPath];
}

@end
