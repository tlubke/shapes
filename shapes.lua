-- Shapes
-- visual based sound manipulator/LFO
--
-- parameters are influenced by
-- each point's position on the
-- graph.
--
-- enc1: change focused shape
-- enc2: spin all shapes
-- enc3: spin focused shape
--
-- key1: edit selected shape
-- key2: delete focused shape
-- key2 HOLD: stop and reset angle of all shapes
-- key3: create new shape
--  ^
-- -1. enc2: X pos, enc3: Y pos
-- -2. enc2: shape, enc3: size
--    -key2: move back a step
--    -key3: advance a step



-- ---------------------------------------
-- Initialization
-- ---------------------------------------



-- includes
local shape = include "lib/shape"

-- local variables
-- modes and various states of being
local mode = "PLAY"
local submode = "NONE"
local left_icon_text = "del"
local right_icon_text = "add"
local spinning = true

shapes = {}
default_shape = shape:new({x = 0, y = 0}, 2, 0, 4, 0) -- default shape is square
local focused_shape = nil

local out_1 = 0
local out_2 = 0
local out_3 = 0
local out_4 = 0

local avg_x_1 = 0.0
local avg_x_2 = 0.0
local avg_x_3 = 0.0
local avg_x_4 = 0.0

local avg_y_1 = 0.0
local avg_y_2 = 0.0
local avg_y_3 = 0.0
local avg_y_4 = 0.0

function init()
  for i=1, 4 do
    crow.output[i].volts = 0
    crow.output[i].slew = 0.0099
  end
  
  voltage_refresh = metro.init(tick, 1/100, -1)
  voltage_refresh:start()
  
  screen_refresh  = metro.init(function(c) redraw(c) end, 1/30, -1)
  screen_refresh:start()
end



-- --------------------------------------
-- controller functions
-- --------------------------------------



function enc(n,d)
  if focused_shape == nil then return end
  ----------
  -- PLAY
  ----------
  if     mode == "PLAY" then
    
    if n == 1 then
      focus_next(d)
    elseif n == 2 then
      for _, shp in pairs(shapes) do
        shp.s = shp.s + d
      end
    elseif n == 3 then
      focused_shape.s = focused_shape.s + d
    end
  --------------
  -- EDIT/CREATE
  --------------
  elseif mode == "EDIT" or mode == "CREATE" then
  
    if     submode == "POSITION" then
      if     n == 1 then
        -- nothing
      elseif n == 2 then
        focused_shape.c.x = util.clamp(focused_shape.c.x + d, -5, 5)
      elseif n == 3 then
        focused_shape.c.y = util.clamp(focused_shape.c.y - d, -5, 5)
      end
    elseif submode == "SIZE" then
      if     n == 1 then
        -- nothing
      elseif n == 2 then
        focused_shape.r = util.clamp(focused_shape.r + d, 1, 10)
      elseif n == 3 then
        focused_shape.p = util.clamp(focused_shape.p + d, 1, 4)
      end
    end
    
  end
end

function key(n,z)
  if z == 0 then return end

  ----------
  -- PLAY
  ----------
  if     mode == "PLAY" then
    
    if n == 1 and focused_shape then
      mode    = "EDIT"
      submode = "POSITION"
    elseif n == 2 then
      if #shapes < 1 then return end
      mode    = "DELETE?"
      submode = "NONE"
      left_icon_text = "no"
      right_icon_text = "yes"
    elseif n == 3 then
      mode    = "CREATE"
      submode = "POSITION"
      right_icon_text = "next"
      left_icon_text = "undo"
      new_shape = default_shape:clone()
      table.insert(shapes, #shapes + 1, new_shape)
      focused_shape = new_shape
    end
  ------------
  -- EDIT
  ------------
  elseif mode == "EDIT" then
  
    if     submode == "POSITION" then
      if     n == 1 then
        -- nothing
      elseif n == 2 then
        -- go back to playmode, undo any changes
      elseif n == 3 then
        submode = "SIZE"
        left_icon_text = "back"
      end
    elseif submode == "SIZE" then
      if     n == 1 then
        -- nothing
      elseif n == 2 then
        submode = "POSITION"
        right_icon_text = "next"
        left_icon_text = "undo"
      elseif n == 3 then
        play_mode()
      end
    end
  ----------
  -- CREATE
  ----------
  elseif mode == "CREATE" then
  
    if     submode == "POSITION" then
      if     n == 1 then
        -- nothing
      elseif n == 2 then
        delete_focused()
        play_mode()
      elseif n == 3 then
        submode = "SIZE"
        left_icon_text = "back"
      end
    elseif submode == "SIZE" then
      if     n == 1 then
        -- nothing
      elseif n == 2 then
        submode = "POSITION"
        right_icon_text = "next"
        left_icon_text = "undo"
      elseif n == 3 then
        play_mode()
      end
    end
  ----------
  -- CONFIRM
  ----------
  elseif mode == "DELETE?" then
    
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      play_mode()
    elseif n == 3 then
      delete_focused()
      play_mode()
    end
  
  end
  
  print("mode: "..mode.." submode: "..submode)
end



-- --------------------------------
-- active functions
-- --------------------------------



function tick()
  local x_values = {
    {n = 0, sum = 0},
    {n = 0, sum = 0},
    {n = 0, sum = 0},
    {n = 0, sum = 0}
  }
  
  local y_values = {
    {n = 0, sum = 0},
    {n = 0, sum = 0},
    {n = 0, sum = 0},
    {n = 0, sum = 0}
  }
  
  for _, shp in pairs(shapes) do
    shp.a = shp.a + (shp.s / 1000)
    
    local xs, ys = shp:values()
    for j = 1, #xs do
      if xs[j] <= 5 and xs[j] >= -5 then
        x_values[j].n = x_values[j].n + 1
        x_values[j].sum = x_values[j].sum + xs[j]
      end
    end
    for j = 1, #ys do
      if ys[j] <= 5 and ys[j] >= -5 then
        y_values[j].n = y_values[j].n + 1
        y_values[j].sum = y_values[j].sum + ys[j]
      end
    end
  end
  
  avg_x_1 = x_values[1].sum / x_values[1].n
  avg_x_2 = x_values[2].sum / x_values[2].n
  avg_x_3 = x_values[3].sum / x_values[3].n
  avg_x_4 = x_values[4].sum / x_values[4].n
  
  avg_y_1 = y_values[1].sum / y_values[1].n
  avg_y_2 = y_values[2].sum / y_values[2].n
  avg_y_3 = y_values[3].sum / y_values[3].n
  avg_y_4 = y_values[4].sum / y_values[4].n
  
  crow.output[1].volts = avg_x_1
  crow.output[2].volts = avg_x_2
  crow.output[3].volts = avg_x_3
  crow.output[4].volts = avg_x_4
  
  --[[ clamp values to -5,5? Or if it is out side grid, don't count?
  avg_x_1 = util.clamp(x_values[1].sum / x_values[1].n, -5, 5)
  avg_x_2 = util.clamp(x_values[2].sum / x_values[2].n, -5, 5)
  avg_x_3 = util.clamp(x_values[3].sum / x_values[3].n, -5, 5)
  avg_x_4 = util.clamp(x_values[4].sum / x_values[4].n, -5, 5)
  
  avg_y_1 = util.clamp(y_values[1].sum / y_values[1].n, -5, 5)
  avg_y_2 = util.clamp(y_values[2].sum / y_values[2].n, -5, 5)
  avg_y_3 = util.clamp(y_values[3].sum / y_values[3].n, -5, 5)
  avg_y_4 = util.clamp(y_values[4].sum / y_values[4].n, -5, 5)
  --]]
end



-- ---------------------------------
-- passive functions
-- ---------------------------------



function map_x(n)
  return n * 6 + 95.5
end

function map_y(n)
  return n * (-6) + 31.5
end

function play_mode()
  mode    = "PLAY"
  submode = "NONE"
  left_icon_text  = "del"
  right_icon_text = "add"
end

function focus_next(d)
  local k = tab.key(shapes, focused_shape)
  if k then
    focused_shape = shapes[util.clamp(k + d, 1, #shapes)]
  end
end

function delete_focused()
  local k = tab.key(shapes, focused_shape)
  if k then
    table.remove(shapes, k)
    focused_shape = shapes[util.clamp(k - 1, 1, #shapes)]
  end
end

function format_voltage(n)
  if     n ~= n then
    return "+_.__v" -- NaN
  elseif n >= 0 then
    return string.format("+%.02fv", n)
  else
    return string.format("%.02fv", n)
  end
end

function redraw(c)
  local blink = ((c or 0) % 5) == 0
  
  screen.clear()
  
  draw_bipolar_grid()

  screen.aa(1)
  screen.level(15)
  for _, shp in pairs(shapes) do
    if blink and shp == focused_shape then
      -- don't draw
    else
      shp:draw(map_x, map_y)
    end
  end
  screen.aa(0)
  
  -- blackout left side
  screen.level(0)
  screen.rect(0,0,64,64)
  screen.fill()
  
  -- (x, y)
  screen.level(15)
  screen.font_face(2)
  screen.move(0, 8)
  screen.text("1: ("..format_voltage(avg_x_1)..","..format_voltage(avg_y_1)..")")
  screen.move(0, 16)
  screen.text("2: ("..format_voltage(avg_x_2)..","..format_voltage(avg_y_2)..")")
  screen.move(0, 24)
  screen.text("3: ("..format_voltage(avg_x_3)..","..format_voltage(avg_y_3)..")")
  screen.move(0, 32)
  screen.text("4: ("..format_voltage(avg_x_4)..","..format_voltage(avg_y_4)..")")
  
  -- mode banner
  screen.rect(0,35, 58, 10)
  screen.fill()
  screen.level(0)
  screen.move(29, 43)
  screen.text_center(mode)
  screen.level(15)
  
  draw_left_icon()
  draw_right_icon()
  
  screen.update()
end



-- ----------------------------------
-- drawing functions
-- ----------------------------------



function draw_bipolar_grid()
  screen.line_width(1)
  
  for i=1, 5 do
    from_center = (i*6)
    
    -- x axis lines
    screen.move(64, 32 - from_center)
    screen.line_rel(63, 0)
    screen.move(64, 32 + from_center)
    screen.line_rel(63, 0)
    
    -- y axis lines
    screen.move(96 - from_center, 0)
    screen.line_rel(0, 63)
    screen.move(96 + from_center, 0)
    screen.line_rel(0, 63)
    
    screen.level(11 - (i*2))
    screen.stroke()
  end
  
  screen.level(15)
  
  -- x/y center lines
  screen.move(64, 32)
  screen.line_rel(63, 0)
  screen.move(96, 0)
  screen.line_rel(0, 63)
  screen.stroke()
  
  -- box around center line
  screen.rect(94, 30, 3, 3)
  screen.fill()
  
  -- box around grid
  screen.rect(65,1, 62, 62)
  screen.stroke()
end

function draw_left_icon()
  if #shapes == 0 then
    screen.level(1)
  else
    screen.level(15)
  end
  screen.rect(1, 48, 27, 15)
  screen.stroke()
  screen.move(14, 58)
  screen.text_center(left_icon_text or "TEST")
end

function draw_right_icon()
  screen.level(15)
  screen.rect(31, 48, 27, 15)
  screen.stroke()
  screen.move(44,58)
  screen.text_center(right_icon_text or "TEST")
end

