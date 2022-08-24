--[[
  Copyright 2021 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  Edge utility device driver - track switch on duration and increment/decrement counter

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"                 -- just for time
local socket = require "cosock.socket"          -- just for time
local log = require "log"


-- Module variables
thisDriver = {}
local initialized = false

local DURATION_PROFILE = 'edgeutil.v1'
local COUNT_PROFILE = 'edgeutil_count.v1'

-- Custom Capabilities

local cap_duration = capabilities["partyvoice23922.duration2"]
local cap_count = capabilities["partyvoice23922.count"]
local cap_add = capabilities["partyvoice23922.add2"]
local cap_subtract = capabilities["partyvoice23922.subtract2"]
local cap_reset = capabilities["partyvoice23922.resetalt"]
local cap_create = capabilities["partyvoice23922.createanother"]

-- Functions

local function create_device(driver)

  local MFG_NAME = 'SmartThings Community'
  local MODEL = 'edgeUtil'
  local VEND_LABEL = 'Counter Utility'
  local ID = 'edgeUtility_' .. socket.gettime()
  local PROFILE = DURATION_PROFILE

  log.info (string.format('Creating new device: label=<%s>, id=<%s>', VEND_LABEL, ID))

  local create_device_msg = {
                              type = "LAN",
                              device_network_id = ID,
                              label = VEND_LABEL,
                              profile = PROFILE,
                              manufacturer = MFG_NAME,
                              model = MODEL,
                              vendor_provided_label = VEND_LABEL,
                            }
                      
  assert (driver:try_create_device(create_device_msg), "failed to create device")

end


local function _update_duration(device, duration)

  device:emit_component_event(device.profile.components.main, cap_duration.duration({value=duration, unit=device.preferences.scale}))

end

local function _update_count(device, count)

  device:emit_component_event(device.profile.components.counter, cap_count.count(count))

end


local function calc_duration(device)

  local basetime = device:get_field('baseTime')
  log.debug ('Calc: basetime=', basetime)

  if basetime then
  
    local rawduration = os.time() - basetime
    local devisor
    
    if device.preferences.scale == 'seconds' then
      devisor = 1
    elseif device.preferences.scale == 'minutes' then
      devisor = 60
    elseif device.preferences.scale == 'hours' then
      devisor = 3600
    elseif device.preferences.scale == 'days' then
      devisor = 86400
    elseif device.preferences.scale == 'weeks' then
      devisor = 604800
    end
    
    log.debug ('Calc: return=', math.floor(rawduration / devisor))
    return math.floor(rawduration / devisor)
  else
    return 0
  end
end


local function refresh_all(device)

  device:emit_component_event(device.profile.components.main, cap_duration.duration({value=calc_duration(device), unit=device.preferences.scale}))
  --device:emit_component_event(device.profile.components.counter, cap_count.count(device:get_field('count')))

end


local function stop_auto_refresh(device)

  local refreshtimer = device:get_field('refreshtimer')
  if refreshtimer then
    thisDriver:cancel_timer(refreshtimer)
  end

end


local function start_auto_refresh(device)

  stop_auto_refresh(device)

  refreshtimer = device.thread:call_on_schedule(device.preferences.frequency, 
                                                function()
                                                  refresh_all(device)
                                                end )
          
  device:set_field('refreshtimer', refreshtimer)

end


local function increment_count(device)

  local current_count = device:get_latest_state('counter', cap_count.ID, cap_count.count.NAME)
  _update_count(device, current_count + 1)

end

local function decrement_count(device)

  local current_count = device:get_latest_state('counter', cap_count.ID, cap_count.count.NAME)
  if current_count > 0 then
    _update_count(device, current_count - 1)
  end

end


-----------------------------------------------------------------------
--										COMMAND HANDLERS
-----------------------------------------------------------------------

-- DEVICE HANDLERS

local function handle_switch(driver, device, command)

  log.info ('Switch turned >> ' .. command.command .. ' <<')
  
  device:emit_event(capabilities.switch.switch(command.command))
  
  -- Set contactSensor according to preferences
  
  local contactset
  
  if device.preferences.behavior == 'on_open' then
    contactset =  {
                    ['on'] = 'open',
                    ['off'] = 'closed'
                  }
  elseif device.preferences.behavior == 'on_closed' then
    contactset =  {
                    ['on'] = 'closed',
                    ['off'] = 'open'
                  }
  end

  device:emit_event(capabilities.contactSensor.contact(contactset[command.command]))                
  
  
  -- Manage duration tracking
  
  local duration
  local basetime = device:get_field('baseTime')
  log.debug ('SW basetime=', basetime)
  log.debug ('SW pausetime=', device:get_field('pauseTime'))
  if command.command == 'on' then

    if basetime == nil then
      device:set_field('baseTime', os.time(), {persist = true})
      duration = 0
    else
      local newbase = basetime + (os.time() - device:get_field('pauseTime'))
      device:set_field('baseTime', newbase, {persist = true})
      device:set_field('pauseTime', 0, {persist = true})
      log.debug ('\tSW new basetime=', newbase)
      duration = calc_duration(device)
    end
    
    if device.preferences.countlink == 'counton' or  device.preferences.countlink == 'countany' then
      increment_count(device)
    end
    
    start_auto_refresh(device)

  else      -- switch == OFF
    if device.preferences.switchoff == 'pause' then
      device:set_field('pauseTime', os.time(), {persist = true})
      stop_auto_refresh(device)
      duration = calc_duration(device)
    else
      duration = 0
      device:set_field('pauseTime', 0, {persist = true})
      device:set_field('baseTime', nil, {persist = true})
    end
    
    if device.preferences.countlink == 'countoff' or device.preferences.countlink == 'countany' then
      increment_count(device)
    end
    
  end
  
  _update_duration(device, duration)

end 


local function handle_addbutton(driver, device, command)

  log.info ('Add Button pressed')
  
  increment_count(device)
  
end

local function handle_subtractbutton(driver, device, command)

  log.info ('Subtract Button pressed')
  
  decrement_count(device)
  
end


local function handle_reset(driver, device, command)

  log.info ('Reset button pressed')
  
  if command.component == 'main' then

    _update_duration(device, 0)
    device:set_field('pauseTime', 0, {persist = true})
    
    if device:get_latest_state('main', capabilities.switch.ID, capabilities.switch.switch.NAME) == 'on' then
      device:set_field('baseTime', os.time(), {persist = true})
    else
      device:set_field('baseTime', nil, {persist = true})
    end
  
  elseif command.component == 'counter' then
    
    _update_count(device, 0)
    
  end
    
end


local function handle_create(driver, device, command)

	log.info ('Create device requested')

	create_device(driver)

end


local function handle_stockrefresh(driver, device, command)

  log.info ('Stock refresh requested; command:', command.command)

  refresh_all(device)
  
end


------------------------------------------------------------------------
--             REQUIRED EDGE DRIVER LIFECYCLE HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
  log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")

  _update_duration(device, calc_duration(device))
  
  if device:get_latest_state('main', capabilities.switch.ID, capabilities.switch.switch.NAME) == 'on' then
    start_auto_refresh(device)
  end

  initialized = true
end


-- Called when device is first created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")
  
  device:emit_event(capabilities.switch.switch('off'))
  device:emit_event(capabilities.contactSensor.contact('closed'))
  
  _update_duration(device, 0)
  _update_count(device, 0)
  device:set_field('pauseTime', 0, {persist = true})
  device:set_field('baseTime', nil, {persist = true})

end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  log.info ('Device doConfigure lifecycle invoked')

end


-- Called when device was deleted
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")

  stop_auto_refresh(device)

	local device_list = driver:get_devices()

	if #device_list == 0 then
    log.warn('No more devices; driver not active')
		initialized = false
	end
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

  
  -- Did preferences change?
  if args.old_st_store.preferences then
  
    if args.old_st_store.preferences.frequency ~= device.preferences.frequency then
      log.info ('Refresh frequency changed to: ', device.preferences.frequency)
      
      if device:get_latest_state('main', capabilities.switch.ID, capabilities.switch.switch.NAME) == 'on' then
        start_auto_refresh(device)
      end
      
    elseif args.old_st_store.preferences.dashboard ~= device.preferences.dashboard then
      log.info ('Dashboard preference changed to: ', device.preferences.dashboard)
      
      if device.preferences.dashboard == 'duration' then
        device:try_update_metadata({profile=DURATION_PROFILE})
      elseif device.preferences.dashboard == 'count' then
        device:try_update_metadata({profile=COUNT_PROFILE})
      end
    end
  end
  
end


local function shutdown_handler(driver, event)

  if event == 'shutdown' then
    log.warn('*** Driver shutdown ***')
    
  end

end


-- Discovery (when 'Scan for nearby devices' invoked from mobile app)
local function discovery_handler(driver, _, should_continue)
  
  if not initialized then
  
    log.info("Creating counter device")
    
    create_device(driver)
    
    log.debug("Exiting device creation")
    
  else
    log.info ('At least one counter device already exists')
  end
end


-----------------------------------------------------------------------
--        DRIVER MAINLINE: Build driver context table
-----------------------------------------------------------------------
thisDriver = Driver("thisDriver", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    driverSwitched = handler_driverchanged,
    infoChanged = handler_infochanged,
    doConfigure = device_doconfigure,
    removed = device_removed
  },
  driver_lifecycle = shutdown_handler,
  capability_handlers = {
  
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = handle_switch,
      [capabilities.switch.commands.off.NAME] = handle_switch,
    },
    [cap_add.ID] = {
      [cap_add.commands.push.NAME] = handle_addbutton,
    },
		[cap_subtract.ID] = {
      [cap_subtract.commands.push.NAME] = handle_subtractbutton,
    },
    [cap_reset.ID] = {
      [cap_reset.commands.push.NAME] = handle_reset,
    },
    [cap_create.ID] = {
      [cap_create.commands.push.NAME] = handle_create,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_stockrefresh,
    },
  }
})

log.info ('Edge Counter-utility Device Version 0.4')


thisDriver:run()
