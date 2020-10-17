-- Shapes
-- visual based modulation source
--
-- parameters are influenced by
-- each point's position on the
-- graph.
--
-- enc1: change focused shape
-- enc2: resize focused shape
-- enc3: spin focused shape
--
-- key1: move focused shape
-- key2: delete focused shape
-- key3: create new shape
--
-- HOLD
-- key2 + enc2: resize all shapes
-- key3 + enc3: spin all shapes



-- ---------------------------------------
-- Initialization
-- ---------------------------------------



-- includes
local shape = include "lib/shape"

-- local variables
-- modes and various states of being
local mode = "PLAY"
local left_icon_text = "DEL"
local right_icon_text = "ADD"

local shapes = {}
local default_shape = shape:new({x = 0, y = 0}, 2, 0, 4, 0) -- default shape is square
local partial_shape = nil
local focused_shape = nil
local position_before_move = nil

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

local x_1 = 0/0
local x_2 = 0/0
local x_3 = 0/0
local x_4 = 0/0

local y_1 = 0/0
local y_2 = 0/0
local y_3 = 0/0
local y_4 = 0/0

function output_avg_x(i)
  crow.output[i].volts = x_values[i].sum / x_values[i].n
end

function output_avg_y(i)
  crow.output[i].volts = y_values[i].sum / y_values[i].n
end

local output_modes = {
  output_avg_x,
  output_avg_y
}

local input_state = {
  key   = {0, 0, 0},
  key_t = {0, 0, 0}
}

function init()
  for i=1, 4 do
    crow.output[i].volts = 0
    crow.output[i].slew = 0.0099
  end
  
  voltage_refresh = metro.init(tick, 1/100, -1)
  voltage_refresh:start()
  
  screen_refresh  = metro.init(function(c) redraw(c) end, 1/30, -1)
  screen_refresh:start()
  
  params:add_option("out_1", "output mode 1:", {"avg. of x's", "avg. of y's"}, 2)
  params:add_option("out_2", "output mode 2:", {"avg. of x's", "avg. of y's"}, 2)
  params:add_option("out_3", "output mode 3:", {"avg. of x's", "avg. of y's"}, 2)
  params:add_option("out_4", "output mode 4:", {"avg. of x's", "avg. of y's"}, 2)
  
  uninject_param_method_extensions()
  inject_param_method_extensions()
end



-- --------------------------------------
-- controller functions
-- --------------------------------------



function enc(n,d)
  ----------
  -- PLAY
  ----------
  if     mode == "PLAY" then
    
    if n == 1 then
      focus_next(d)
    elseif n == 2 then
      if input_state.key[n] == 1 then
        for _, shp in pairs(shapes) do
          shp.r = util.clamp(shp.r + d, 1, 10)
        end
      else
        focused_shape.r = util.clamp(focused_shape.r + d, 1, 10)
      end
    elseif n == 3 then
      if input_state.key[n] == 1 then
        for _, shp in pairs(shapes) do
          shp.s = shp.s + d
        end
      else
        focused_shape.s = focused_shape.s + d
      end
    end
  --------
  -- MOVE
  --------
  elseif mode == "MOVE" then
  
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      focused_shape.c.x = util.clamp(focused_shape.c.x + d, -5, 5)
    elseif n == 3 then
      focused_shape.c.y = util.clamp(focused_shape.c.y - d, -5, 5)
    end
  ---------
  -- CREATE
  ---------
  elseif mode == "PLACE" then
    
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      partial_shape.c.x = util.clamp(partial_shape.c.x + d, -5, 5)
    elseif n == 3 then
      partial_shape.c.y = util.clamp(partial_shape.c.y - d, -5, 5)
    end
    
  elseif mode == "SHAPE" then
    
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      partial_shape.r = util.clamp(partial_shape.r + d, 1, 10)
    elseif n == 3 then
      partial_shape.p = util.clamp(partial_shape.p + d, 1, 4)
    end
    
  end
end

function key(n,z)
  input_state.key[n] = z
  
  if z == 1 then
    -- record time of press
    input_state.key_t[n] = util.time()
    return 
  elseif n == 1 then
    -- don't ignore held release of key 1
  else
    -- ignore held releases
    if util.time() - input_state.key_t[n] > 0.5 then
      return
    end
  end
  
  ----------
  -- PLAY
  ----------
  if     mode == "PLAY" then
    
    if n == 1 and focused_shape then
      start_move()
    elseif n == 2 then
      if #shapes < 1 then return end
      start_delete()
    elseif n == 3 then
      start_create()
    end
  ------------
  -- MOVE
  ------------
  elseif mode == "MOVE" then
  
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      undo_move()
    elseif n == 3 then
      finish_move()
    end
  ----------
  -- CREATE
  ----------
  elseif mode == "PLACE" then
  
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      undo_create()
    elseif n == 3 then
      mode = "SHAPE"
      left_icon_text = "BACK"
    end
    
  elseif mode == "SHAPE" then
    
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      mode = "PLACE"
      right_icon_text = "NEXT"
      left_icon_text = "UNDO"
    elseif n == 3 then
      finish_create()
    end
  ----------
  -- DELETE
  ----------
  elseif mode == "DELETE?" then
    
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      undo_delete()
    elseif n == 3 then
      finish_delete()
    end
  
  end
end



-- --------------------------------
-- active functions
-- --------------------------------



function tick()
  reset_x_values()
  reset_y_values()
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
  
  x_1 = x_values[1].sum / x_values[1].n
  x_2 = x_values[2].sum / x_values[2].n
  x_3 = x_values[3].sum / x_values[3].n
  x_4 = x_values[4].sum / x_values[4].n
  
  y_1 = y_values[1].sum / y_values[1].n
  y_2 = y_values[2].sum / y_values[2].n
  y_3 = y_values[3].sum / y_values[3].n
  y_4 = y_values[4].sum / y_values[4].n

  output_modes[params:get("out_1")](1)
  output_modes[params:get("out_2")](2)
  output_modes[params:get("out_3")](3)
  output_modes[params:get("out_4")](4)
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

function reset_x_values()
  for _, v in pairs(x_values) do
    v.n = 0
    v.sum = 0
  end
end

function reset_y_values()
  for _, v in pairs(y_values) do
    v.n = 0
    v.sum = 0
  end
end

function load_shapes(filename)
  local tmp = tab.load(filename)
  for _, t in pairs (tmp) do
    setmetatable(t, shape.__index)
  end
  shapes = tmp
  if #shapes > 0 then focused_shape = shapes[1] end
end

function clone_function(fn)
  local dumped = string.dump(fn)
  local cloned = load(dumped)
  local i = 1
  while true do
    local name = debug.getupvalue(fn, i)
    if not name then
      break
    end
    debug.upvaluejoin(cloned, i, fn, i)
    i = i + 1
  end
  return cloned
end

function inject_param_method_extensions()
  -- extend paramset:write()
  if params.write2 == nil then
    params.write2 = clone_function(params.write)
    params.write = function(paramset, filename, name)
      params:write2(filename, name)
      if norns.state.name == "shapes" then
        tab.save(shapes, paths.this.data..filename..".data")
      end
    end
  end
  
  -- extend paramset:read()
  if params.read2 == nil then
    params.read2 = clone_function(params.read)
    params.read = function(paramset, filename) 
      params:read2(filename)
      if norns.state.name == "shapes" then
        load_shapes(paths.this.data..filename..".data")
      end
    end
  end
end

function uninject_param_method_extensions()
  -- reverse paramset:write() extension
  if params.write2 ~= nil then
    params.write  = clone_function(params.write2)
    params.write2 = nil
  end
  
  -- reverse paramset:read() extension
  if params.read2 ~= nil then
    params.read   = clone_function(params.read2)
    params.read2  = nil
  end
end

--------
-- STATE
--------



function play_mode()
  mode = "PLAY"
  left_icon_text  = "DEL"
  right_icon_text = "ADD"
end

function start_move()
  mode = "MOVE"
  left_icon_text  = "UNDO"
  right_icon_text = "DONE"
  position_before_move = { x = focused_shape.c.x, y = focused_shape.c.y }
end

function undo_move()
  focused_shape.c = position_before_move
  play_mode()
end

function finish_move()
  position_before_move = nil
  play_mode()
end

function start_create()
  mode = "PLACE"
  left_icon_text  = "UNDO"
  right_icon_text = "NEXT"
  partial_shape = default_shape:clone()
end

function undo_create()
  partial_shape = nil
  play_mode()
end

function finish_create()
  table.insert(shapes, partial_shape)
  focused_shape = partial_shape
  partial_shape = nil
  play_mode()
end

function start_delete()
  mode = "DELETE?"
  left_icon_text  = "NO"
  right_icon_text = "YES"
end

function undo_delete()
  play_mode()
end

function finish_delete()
  delete_focused()
  play_mode()
end



-- ----------------------------------
-- drawing functions
-- ----------------------------------



function redraw(c)
  screen.clear()
  
  draw_bipolar_grid()

  screen.aa(1)
  screen.level(15)
  for _, shp in pairs(shapes) do
    if shp == focused_shape then
      -- don't draw
    else
      shp:draw(map_x, map_y, 15)
    end
  end
  if focused_shape then
    focused_shape:draw(map_x, map_y, 6 + (c % 6))
  end
  if partial_shape then
    partial_shape:draw(map_x, map_y, c % 16)
  end
  if partial_shape then
    partial_shape:draw_numbers(map_x, map_y)
  elseif focused_shape then
    focused_shape:draw_numbers(map_x, map_y)
  end
  screen.aa(0)
  
  -- black outline around grid
  screen.level(0)
  screen.rect(64,-1,64,65)
  screen.stroke()
  
  -- blackout left half
  screen.rect(0, 0, 64, 64)
  screen.fill()
  
  -- (x, y)
  screen.level(15)
  screen.font_face(2)
  screen.move(0, 8)
  screen.text("1: ("..format_voltage(x_1)..","..format_voltage(y_1)..")")
  screen.move(0, 16)
  screen.text("2: ("..format_voltage(x_2)..","..format_voltage(y_2)..")")
  screen.move(0, 24)
  screen.text("3: ("..format_voltage(x_3)..","..format_voltage(y_3)..")")
  screen.move(0, 32)
  screen.text("4: ("..format_voltage(x_4)..","..format_voltage(y_4)..")")
  
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
    
    screen.level(3)
    screen.stroke()
  end
  
  screen.level(6)
  
  -- x/y center lines
  screen.move(64, 32)
  screen.line_rel(63, 0)
  screen.move(96, 0)
  screen.line_rel(0, 63)
  screen.stroke()
  
  -- box around center line
  screen.rect(94, 30, 3, 3)
  screen.fill()
  
  screen.level(15)
  
  -- box around grid
  screen.rect(65,1, 62, 62)
  screen.stroke()
end

function draw_left_icon()
  if #shapes == 0 and partial_shape == nil then
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

