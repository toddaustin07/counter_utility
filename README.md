# counter_utility
Utility Edge device driver for timer and counter functions

Currently available from my [test channel](https://bestow-regional.api.smartthings.com/invite/Q1jP7BqnNNlL)

Once installed to your hub, using the mobile app, perform an *Add device / Scan for nearby devices* action and a new device labled "Counter Utility" will be created and placed in your 'No room assigned' room.

### Caveats
This driver is still in early implementation, so may have some hiccups, or may evolve based on community feedback.

#### Known Issues
Due to SmartThings platform issues the following might be observed:
* dashboard duration units may not show correct string (seconds, minutes, etc.)
* dashboard tile seems unnecessarily large (not an issue per se)
* labels on the Controls screen may not be displaying properly


### Device Functions
This device has two distinct functions:
1) Track the amount of time (duration) that a switch is 'ON' 
2) Increment or decrement a counter based on button presses

The device is meant for building automations where tracking a duration of time or a counter would be useful.

The duration of the switch can be tracked in any unit from seconds to weeks

The counter can also be tied to the switch such that it counts the number of times the switch is changed.

### Device Settings

##### Duration Resolution
Here is where you chose what 'unit' of measure you want to use: seconds, minutes, hours, days, weeks.  Typically you would choose the lowest granularity needed, as the duration values are integers.

##### Duration Auto-Update Frequency
How often the duration value is updated *for display and automations* is determined by this setting.  The frequency is provided in number of seconds, with a minimum of 10 and a maximum of 86400 (one day).  Note that duration is always continually tracked down to the second within the driver.  But because it would cause rate limit issues to try and update SmartThings cloud every second, this option merely determines the frequency of actual *displayed* values in the mobile app, and currency of values *available to automations*.

##### Switch Off Action
When the switch is turned OFF, it can either temporarily pause the duration tracking until the switch is turned ON again, or it can completely reset the duration tracking to 0 and stop tracking duration.  Use this Setting to determine which mode you need.

##### Switch / Counter Linkage
Normally the duration tracking of the switch, and the counter using the add and subtract buttons, are two separate and independent functions.  However if you want to not only track the duration that the switch is ON, but also how many times the switch is used, this Settings option allows you to make that linkage.  There are multiple choices: (1) count only when switch is turned ON, (2) count only when switch is turned OFF, (3) count either switch state change, or (4) don't count switch changes at all (no link).

##### Contact sensor Behavior
A hidden contact sensor is included in the device but not displayed on the device Controls screen.  This is included in order to facilitate integrations of this device into Alexa routines.  The contact sensor allows for creating the 'When this happens' part of the routine definition.  The contact sensor can be used as a surrogate for the switch state when this device Setting is configured.  Options are (1) set contact to **open** when switch is ON, (2) set contact to **closed** when switch is OFF, (3) disable setting of contact sensor state.

##### Dashboard State & Control
As a default, the dashboard tile for this device includes a button to control the switch, as well as the duration value including the selected units (seconds, minutes, etc.) However if the device is going to be used primarily for counting rather than switch duration tracking, this device Setting allows you to change the dashboard view to be a button for incrementing the counter, plus the current count value.

### Device Controls Screen

The screen has 2 sections ('components')
- **Main** includes the duration-related fields and controls as well as a button to create additional devices
- **Counter** includes the counting-related fields and controls.

#### Main
* Switch
* Duration value field (an integer value, with configured unit string); you can force an immediate update to this field by swiping down on the screen, otherwise it is updated based on the frequency configured in device Settings
* Reset button:  resets the duration value to 0.  If the switch is ON, duration tracking will continue
* Create additional device button

#### Counter
* Add button to increment counter
* Subtract button to decrement counter
* Count value field
* Reset button: resets the count value to 0

### Automations
#### Available as IF conditions
* switch, duration value, count
#### Available as THEN actions
* switch, reset duration, reset count, add-to count, subtract-from count
