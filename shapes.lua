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

local x1_weighted = 0/0
local x2_weighted = 0/0
local x3_weighted = 0/0
local x4_weighted = 0/0

local x1_unweighted = 0/0
local x2_unweighted = 0/0
local x3_unweighted = 0/0
local x4_unweighted = 0/0

local y1_weighted = 0/0
local y2_weighted = 0/0
local y3_weighted = 0/0
local y4_weighted = 0/0

local y1_unweighted = 0/0
local y2_unweighted = 0/0
local y3_unweighted = 0/0
local y4_unweighted = 0/0

local output_options = {
  {"X1 WEIGHTED",   function(i) crow.output[i].volts = x1_weighted   + params:get("offset_"..i) end},
  {"X1 UNWEIGHTED", function(i) crow.output[i].volts = x1_unweighted + params:get("offset_"..i) end},
  {"Y1 WEIGHTED",   function(i) crow.output[i].volts = y1_weighted   + params:get("offset_"..i) end},
  {"Y1 UNWEIGHTED", function(i) crow.output[i].volts = y1_unweighted + params:get("offset_"..i) end},
  {"X2 WEIGHTED",   function(i) crow.output[i].volts = x2_weighted   + params:get("offset_"..i) end},
  {"X2 UNWEIGHTED", function(i) crow.output[i].volts = x2_unweighted + params:get("offset_"..i) end},
  {"Y2 WEIGHTED",   function(i) crow.output[i].volts = y2_weighted   + params:get("offset_"..i) end},
  {"Y2 UNWEIGHTED", function(i) crow.output[i].volts = y2_unweighted + params:get("offset_"..i) end},
  {"X3 WEIGHTED",   function(i) crow.output[i].volts = x3_weighted   + params:get("offset_"..i) end},
  {"X3 UNWEIGHTED", function(i) crow.output[i].volts = x3_unweighted + params:get("offset_"..i) end},
  {"Y3 WEIGHTED",   function(i) crow.output[i].volts = y3_weighted   + params:get("offset_"..i) end},
  {"Y3 UNWEIGHTED", function(i) crow.output[i].volts = y3_unweighted + params:get("offset_"..i) end},
  {"X4 WEIGHTED",   function(i) crow.output[i].volts = x4_weighted   + params:get("offset_"..i) end},
  {"X4 UNWEIGHTED", function(i) crow.output[i].volts = x4_unweighted + params:get("offset_"..i) end},
  {"Y4 WEIGHTED",   function(i) crow.output[i].volts = y4_weighted   + params:get("offset_"..i) end},
  {"Y4 UNWEIGHTED", function(i) crow.output[i].volts = y4_unweighted + params:get("offset_"..i) end},
}

output_options.strings = {}
output_options.funcs   = {}
for i=1, #output_options do
  table.insert(output_options.strings, i, output_options[i][1])
  table.insert(output_options.funcs,   i, output_options[i][2])
end

local input_state = {
  key   = {0, 0, 0}, -- key 1, 2, 3 : pressed or not pressed
  key_t = {0, 0, 0}, -- key 1, 2, 3 : time of last press
}

function init()
  local offset_controlspec = controlspec.new(0, 5, "lin", 0, 0, "v")
  local offset_formatter   = function(p) return format_voltage(p:get(), 4) end
  
  for i=1, 4 do
    crow.output[i].volts = 0
    crow.output[i].slew = 0.0099
  end
  
  voltage_refresh = metro.init(tick, 1/24, -1)
  voltage_refresh:start()
  
  screen_refresh  = metro.init(function(c) redraw(c) end, 1/24, -1)
  screen_refresh:start()
  
  params:add_separator("OUTPUT MODES")
  params:add_option("out_1", "1:", output_options.strings, 3)
  params:add_option("out_2", "2:", output_options.strings, 7)
  params:add_option("out_3", "3:", output_options.strings, 11)
  params:add_option("out_4", "4:", output_options.strings, 15)
  params:add_separator("VOLTAGE OFFSETS")
  params:add_control("offset_1", "1:", offset_controlspec, offset_formatter)
  params:add_control("offset_2", "2:", offset_controlspec, offset_formatter)
  params:add_control("offset_3", "3:", offset_controlspec, offset_formatter)
  params:add_control("offset_4", "4:", offset_controlspec, offset_formatter)
  params:add_separator("DISPLAY OPTIONS")
  params:add_option("show_points", "SHOW POINT" , {"NONE", "WEIGHTED", "UNWEIGHTED"}, 2)
  params:add_option("show_shapes", "SHOW SHAPES", {"NO", "YES"}, 2)
  
  inject_param_method_extensions()
end

function cleanup()
  uninject_param_method_extensions()
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
          shp:change_radius(d*0.1)
        end
      else
        focused_shape:change_radius(d*0.1)
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
      focused_shape:change_points(d)
    elseif n == 2 then
      focused_shape.c.x = util.clamp(focused_shape.c.x + d, -5, 5)
    elseif n == 3 then
      focused_shape.c.y = util.clamp(focused_shape.c.y - d, -5, 5)
    end
  ---------
  -- CREATE
  ---------
  elseif mode == "X/Y" then
    
    if     n == 1 then
      --nothing
    elseif n == 2 then
      partial_shape.c.x = util.clamp(partial_shape.c.x + d, -5, 5)
    elseif n == 3 then
      partial_shape.c.y = util.clamp(partial_shape.c.y - d, -5, 5)
    end
    
  elseif mode == "SIDES/LENGTH" then
    
    if     n == 1 then
      partial_shape:change_focused_point(d)
    elseif n == 2 then
      partial_shape:change_points(d)
    elseif n == 3 then
      partial_shape:change_point_radius(d*0.1)
    end
 
  elseif mode == "GROUP/WEIGHT" then
    
    if     n == 1 then
      partial_shape:change_focused_point(d)
    elseif n == 2 then
      partial_shape:change_point_group(d)
    elseif n == 3 then
      partial_shape:change_point_weight(d)
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
  elseif mode == "X/Y" then
  
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      undo_create()
    elseif n == 3 then
      mode = "SIDES/LENGTH"
      left_icon_text = "BACK"
    end
    
  elseif mode == "SIDES/LENGTH" then
    
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      mode = "X/Y"
      right_icon_text = "NEXT"
      left_icon_text = "UNDO"
    elseif n == 3 then
      mode = "GROUP/WEIGHT"
      
    end
    
  elseif mode == "GROUP/WEIGHT" then
    
    if     n == 1 then
      -- nothing
    elseif n == 2 then
      mode = "SIDES/LENGTH"
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
  for _, shp in pairs(shapes) do
    shp.a = shp.a + (shp.s / 1000)
  end
  
  calculate_weighted_values()
  calculate_unweighted_values()
  
  output_options.funcs[params:get("out_1")](1)
  output_options.funcs[params:get("out_2")](2)
  output_options.funcs[params:get("out_3")](3)
  output_options.funcs[params:get("out_4")](4)
end



-- ---------------------------------
-- passive functions
-- ---------------------------------



function calculate_weighted_values()
  local x_values = {}
  local y_values = {}
  for i=1, 4 do
    x_values[i] = {sum = 0, total_weight = 0}
    y_values[i] = {sum = 0, total_weight = 0}
  end
  
  for _, shp in pairs(shapes) do
    -- each element is a table of value v, weight w, and group g
    local xs, ys = shp:values() 
    
    for _, x in pairs(xs) do
      local group = x.g
      if x.v <= 5 and x.v >= -5 then
        x_values[group].sum          = x_values[group].sum + (x.v * x.w)
        x_values[group].total_weight = x_values[group].total_weight + x.w
      end
    end
    
    for _, y in pairs(ys) do
      local group = y.g
      if y.v <= 5 and y.v >= -5 then
        y_values[group].sum          = y_values[group].sum + (y.v * y.w)
        y_values[group].total_weight = y_values[group].total_weight + y.w
      end
    end
  end
  
  x1_weighted = (x_values[1].sum / x_values[1].total_weight)
  x2_weighted = (x_values[2].sum / x_values[2].total_weight)
  x3_weighted = (x_values[3].sum / x_values[3].total_weight)
  x4_weighted = (x_values[4].sum / x_values[4].total_weight)
  
  y1_weighted = (y_values[1].sum / y_values[1].total_weight)
  y2_weighted = (y_values[2].sum / y_values[2].total_weight)
  y3_weighted = (y_values[3].sum / y_values[3].total_weight)
  y4_weighted = (y_values[4].sum / y_values[4].total_weight)
end

function calculate_unweighted_values()
  local x_values = {}
  local y_values = {}
  for i=1, 4 do
    x_values[i] = {sum = 0, n = 0}
    y_values[i] = {sum = 0, n = 0}
  end
  
  for _, shp in pairs(shapes) do
    
    -- each element is a table of value v, weight w, and group g
    local xs, ys = shp:values() 
    
    for _, x in pairs(xs) do
      local group = x.g
      if x.v <= 5 and x.v >= -5 then
        x_values[group].n            = x_values[group].n + 1
        x_values[group].sum          = x_values[group].sum + x.v
      end
    end
    
    for _, y in pairs(ys) do
      local group = y.g
      if y.v <= 5 and y.v >= -5 then
        y_values[group].n            = y_values[group].n + 1
        y_values[group].sum          = y_values[group].sum + y.v
      end
    end
  end
  
  x1_unweighted = x_values[1].sum / x_values[1].n
  x2_unweighted = x_values[2].sum / x_values[2].n
  x3_unweighted = x_values[3].sum / x_values[3].n
  x4_unweighted = x_values[4].sum / x_values[4].n
  
  y1_unweighted = y_values[1].sum / y_values[1].n
  y2_unweighted = y_values[2].sum / y_values[2].n
  y3_unweighted = y_values[3].sum / y_values[3].n
  y4_unweighted = y_values[4].sum / y_values[4].n
end

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

function format_voltage(n, decimal_places)
  local decimal_places = decimal_places or 2
  if     n ~= n then
    return "+_.__v" -- NaN
  elseif n >= 0 then
    return string.format("+%.0"..decimal_places.."fv", n)
  else
    return string.format("+%.0"..decimal_places.."fv", n)
  end
end

function format_weight(n)
  if     n ~= n then
    return "_" -- NaN
  elseif n >= 0 then
    return string.format("+%d", n)
  else
    return string.format("%d", n)
  end
end

function load_shapes(filename)
  local tmp = tab.load(filename)
  for _, t in pairs (tmp) do
    setmetatable(t, shape.__index)
    t:restore()
  end
  shapes = tmp
  if #shapes > 0 then focused_shape = shapes[1] end
end



---------
-- MISC.
---------



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
  mode = "X/Y"
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
  local c = c or 0 -- for when redraw() is called by norns menu changes
  screen.clear()
  
  draw_bipolar_grid()

  screen.aa(1)
  screen.level(15)
  if params:get("show_shapes") ~= 1 then
    for _, shp in pairs(shapes) do
      if shp == focused_shape then
        shp:draw(map_x, map_y, 6 + (c % 6))
      else
        shp:draw(map_x, map_y, 15) -- normal
      end
    end
    if partial_shape then
      partial_shape:draw(map_x, map_y, 15)
      partial_shape:draw_arrow_to_focused_point(map_x, map_y, 2 + ((c % 11)/3))
    end
  end
  screen.aa(0)
  
  screen.level(15)
  
  if     params:get("show_points") == 3 then
    draw_weighted_centers_on_grid()
  elseif params:get("show_points") == 2 then
    draw_unweighted_centers_on_grid()
  end
  
  -- black outline around grid
  screen.level(0)
  screen.rect(64,-1,64,65)
  screen.stroke()
  
  -- blackout left half
  screen.rect(0, 0, 64, 64)
  screen.fill()
  
  -- (output voltage) shape side, weight
  screen.level(15)
  screen.font_face(2)
  draw_crow_output_voltages_text()
  draw_focused_shape_point_info_text(15)
  draw_partial_shape_point_info_text((c+3) % 16)
  
  screen.level(15)
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

function draw_crow_output_voltages_text()
  for i=1, 4 do
    screen.move(0,i*8)
    screen.text("("..format_voltage(crow.output[i].volts)..")   ")
  end
end

function draw_focused_shape_point_info_text(brightness)
  screen.level(brightness)
  for i=1, 4 do
    if focused_shape and focused_shape.p.count >= i then
      screen.move(32, i*8)
      local group  = focused_shape.p[i].group
      local weight = format_weight(focused_shape.p[i].weight)
      screen.text(group..", "..weight)
    end
  end
end

function draw_partial_shape_point_info_text(brightness)
  for i=1, 4 do
    if partial_shape and partial_shape.p.count >= i then
      if partial_shape.f == partial_shape.p[i] then
        screen.level(brightness)
      else
        screen.level(15)
      end
      screen.move(32, i*8)
      local group  = partial_shape.p[i].group
      local weight = format_weight(partial_shape.p[i].weight)
      screen.text(group..", "..weight)
    end
  end
end

function draw_pixel_border(x, y)
  screen.level(0)
  screen.pixel(x-1,y)
  screen.pixel(x+1,y)
  screen.pixel(x-1,y-1)
  screen.pixel(x  ,y-1)
  screen.pixel(x+1,y-1)
  screen.pixel(x-1,y+1)
  screen.pixel(x  ,y+1)
  screen.pixel(x+1,y+1)
  screen.fill()
end

function draw_weighted_centers_on_grid()
  screen.pixel(map_x(x1_weighted), map_y(y1_weighted))
  screen.pixel(map_x(x2_weighted), map_y(y2_weighted))
  screen.pixel(map_x(x3_weighted), map_y(y3_weighted))
  screen.pixel(map_x(x4_weighted), map_y(y4_weighted))
  screen.fill()
  draw_pixel_border(map_x(x1_weighted), map_y(y1_weighted))
  draw_pixel_border(map_x(x2_weighted), map_y(y2_weighted))
  draw_pixel_border(map_x(x3_weighted), map_y(y3_weighted))
  draw_pixel_border(map_x(x4_weighted), map_y(y4_weighted))
end

function draw_unweighted_centers_on_grid()
  screen.pixel(map_x(x1_unweighted), map_y(y1_unweighted))
  screen.pixel(map_x(x2_unweighted), map_y(y2_unweighted))
  screen.pixel(map_x(x3_unweighted), map_y(y3_unweighted))
  screen.pixel(map_x(x4_unweighted), map_y(y4_unweighted))
  screen.fill()
  draw_pixel_border(map_x(x1_unweighted), map_y(y1_unweighted))
  draw_pixel_border(map_x(x2_unweighted), map_y(y2_unweighted))
  draw_pixel_border(map_x(x3_unweighted), map_y(y3_unweighted))
  draw_pixel_border(map_x(x4_unweighted), map_y(y4_unweighted))
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

