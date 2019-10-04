-- Shapes
-- visual based sound manipulator/LFO
--
-- parameters are influenced by
-- each point's position on the
-- graph.
--
-- enc1: change focused shape
-- enc2: +/- res. focused shape
-- enc3: spin focused shape
--
-- key1: remove selected shape
-- key2: start/stop spinning
-- key2 HOLD: reset all shapes
-- key3: add shape in 2 steps
--  ^
-- -1. enc2: X pos, enc3: Y pos
-- -2. enc2: shape, enc3: size
--    -key2: move back a step
--    -key3: advance a step



--[[ to do list:
                      -pick an engine to use
                      -make enc2 function
                      -a way to distinguish which line-based shape is focused (i.e. blinking) or reduce level of all other shapes
                      -make any new shapes random
                      -CV control when crow is released
--]]



engine.name = "TestSine"



-- ---------------------------------------
-- Initialization
-- ---------------------------------------



-- local variables
-- modes and various states of being
local mode = 0                        -- mode 0: not-adding, mode 1: adding
local submode = 0                     -- s/m 0: nothing, s/m 1: first-step, s/m 2: second step
local spinning = true                 -- based on metro/count

-- shape variables
local shapes = {}
local defShape = {}
local focus = 0       -- the currently focused item

-- a grid table for easy coordinates
  -- lowercase x/y refer to their screen position
  -- capital X/Y refer to their coordinate relative to the grid
local x = {}
local y = {}

-- clocking variables
local position = 0
local counter = nil



function init()
  -- set up the default shape
  defShape.r = 16
  defShape.a = 0
  defShape.p = 4
  defShape.s = 0
  defShape.f = true

  -- set up the grid table
  for i = -8, 8 do
    x[i] = (i * 8 + 64)
  end
  for i = -4, 4 do
    y[i] = (i * -8 + 32)
  end

  -- metronome setup
  counter = metro.alloc()
  counter.time = 1/30 -- the "fps"
  counter.count = -1
  counter.callback = count
  counter:start()

  -- initial draw
  redraw()
end



-- --------------------------------------
-- controller functions
-- --------------------------------------



function enc(n,d)
  local ct = tab.count(shapes)

  --print("enc: " .. n .. " mode " ..  mode .. " submode " .. submode .. " shape " .. focus .. " of " .. ct)

  if focus <= 0 then return end
  if focus > ct then return end

  if mode == 0 then
    if n == 1 then
      if d > 0 then 
        focus = focus + 1
      elseif d < 0 then
        focus = focus - 1
      end
      
      focus = util.clamp(focus, 1, ct)
      refocus()
      redraw()
    elseif n == 3 then
      shapes[focus].s = shapes[focus].s + d
    end
  else
    -- must be mode 1...
    if submode == 1 then
      if n == 2 then
        if d > 0 then 
          shapes[focus].X = shapes[focus].X + 1
        elseif d < 0 then 
          shapes[focus].X = shapes[focus].X - 1
        end
        
        shapes[focus].X = util.clamp(shapes[focus].X, -8, 8)
        redraw()
      elseif n == 3 then
        if d > 0 then 
          shapes[focus].Y = shapes[focus].Y - 1
        elseif d < 0 then 
          shapes[focus].Y = shapes[focus].Y + 1
        end

        shapes[focus].Y = util.clamp(shapes[focus].Y, -4, 4)
        redraw()
      end
      print("enc result: X = " .. shapes[focus].X .. " Y = " .. shapes[focus].Y)
    elseif submode == 2 then
      if n == 2 then
        shapes[focus].p = shapes[focus].p + d
        shapes[focus].p = util.clamp(shapes[focus].p, 1, 5)
        redraw()
      elseif n == 3 then
        shapes[focus].r = shapes[focus].r + d
        shapes[focus].r = util.clamp(shapes[focus].r, 2, 40)
        redraw()
      end
      print("enc result: p = " .. shapes[focus].p .. " r = " .. shapes[focus].r)
    end
  end
end

function key(n,z)
  local cnt = tab.count(shapes)
  if z == 0 then return end

  if mode == 0 then
    if n == 1 then
      if (cnt > 0) and (focus > 0) then
        table.remove(shapes, focus)
        refocus()
        redraw()
      end
    elseif n == 2 then
      if spinning then
        counter:stop()
        spinning = false
        redraw()
      else
        counter:start()
        spinning = true
        -- doesn't need redraw() because that happens while counter is active
      end
    elseif n == 3 then
      mode = 1
      submode = 1

      local tmpTable = cloneTable(defShape)
      tmpTable.X = 0
      tmpTable.Y = 0
      table.insert(shapes, tmpTable)

      focus = tab.count(shapes)
      -- print("Focus: " .. focus)
      -- tab.print(shapes[focus])
      refocus()
      redraw()
    end
  else
    
    -- must be mode == 1
    -- undo!
    if submode == 2 then
      if n == 2 then
        mode = 1
        submode = 1
        return
      end
    elseif submode == 1 then
      if n == 2 then 
        mode = 0
        submode = 0
        if (cnt > 0) and (focus > 0) then
          table.remove(shapes, focus)
          refocus()
          redraw()
        end
        return
      end
    end

    -- keep going!
    if submode == 1 then
      if n == 3 then
        submode = 2
        redraw()
      end
    else
      if n == 3 then
        -- defShape = cloneTable(shapes[focus]) #clones the most recent shape
        mode = 0
        submode = 0
        redraw()
      end
    end
  end

  print("mode: " .. mode .. " submode: " .. submode .. " focus: " .. focus)
end



-- --------------------------------
-- active functions
-- --------------------------------



function count(c)
  local cnt = tab.count(shapes)
  call_x = {}
  call_y = {}

  for i = 1, cnt do
    shapes[i].a = shapes[i].a + (shapes[i].s / 100)
    
    -- calling the values of each point
    -- call_x[n][1] = X coordinate, call_x[n][2~points + 1] = coordinates of each point on shape
      -- all point 1s, point 2s, etc. are added together and returned to audio engine.
    call_x[i], call_y[i] = polygon(
      shapes[i].X,
      shapes[i].Y,
      shapes[i].r,
      shapes[i].a,
      shapes[i].p,
      false -- fill, irrelevant here.
      )
  end
  
  for i = 1, cnt do -- for as many shapes
    call_x[1][2] = call_x[1][2] + call_x[i][2] -- add together their first point
    -- this would be done for all 5 points, which would each have a respective parameter.
  end
  
  -- audio test
  if cnt <= 0 then return
  else
    engine.hz(call_x[1][2] * 27.5 + 222)
  end
  
  redraw()
end



-- ---------------------------------
-- passive functions
-- ---------------------------------



function refocus()
  local cnt = tab.count(shapes)

  -- if nothing left, zero it out
  if (cnt < 1)  then
    focus = 0
    return
  end

  -- if too low, choose the first
  if (focus < 1) then
    focus = 1
  end

  -- if too high, choose the last
  if (focus > cnt) then
    focus = cnt
  end

  for i=1, cnt do
    --print("checking " .. i .. " against " .. focus)
    if (focus == i) then
      shapes[i].f = true
    else
      shapes[i].f = false
    end
  end

  --print("focus set to " .. focus)
end

function redraw()
  local cnt = tab.count(shapes)

  -- draw grid
  screen.clear()
  screen.aa(0)
  gridlay(16,0,0)
  screen.level(15)

  screen.aa(1)      -- shapes are aa but everything else is not
  for i=1, cnt do
    polygon(
      x[shapes[i].X],
      y[shapes[i].Y],
      shapes[i].r,
      shapes[i].a,
      shapes[i].p,
      shapes[i].f
    )
  end

  screen.stroke()
  screen.aa(0)
  
  -- pause symbole
  if not spinning then
      screen.rect(117,53,2,6)
      screen.rect(120,53,2,6)
      screen.fill()
  end
  
  -- indicators for mode 1
  if mode == 1 then
    
    -- creating a black background, so numbers can't be covered.
    screen.level(0) 
    screen.rect(0,0,15,7)
    if submode == 1 then
      screen.rect(104,0,24,7)
    else
      screen.rect(112,0,24,7)
    end
    screen.fill()
    
    -- the numbers, top left and right corners.
    screen.level(15)
    screen.font_size(7)
    screen.font_face(1)
    screen.move(0,7)
    screen.text(submode.."/2")
    screen.font_size(7)
    screen.font_face(1)
    screen.move(128,7)
    if submode == 1 then
      screen.text_right("("..shapes[focus].X.." , "..shapes[focus].Y..")")
    else
      screen.text_right("r = "..shapes[focus].r)
    end
  end
  
  screen.update()
end



-- ----------------------------------
-- drawing functions
-- ----------------------------------



function gridlay(div,shiftx,shifty)

  local div = div            -- number of divisions, only powers of 4 divide cleanly
  local size = (128/div)    -- space between gridlines
  local shiftx = shiftx
  local shifty = shifty

    screen.line_width(1)    -- vertical gridlay
    for i = 1, div do
      screen.move(i * size+shiftx, 0)
      screen.line_rel(0,64)
      if i < div/2 then
          screen.level(i)
        else
          screen.level(div-i)
      end
     screen.stroke()
    end

    screen.level(7)         -- vertical centerline
    screen.line_width(1)
    screen.move(64,0)
    screen.line_rel(0,64)
    screen.stroke()

    screen.line_width(1)    -- horizontal gridlay
    for i = 1, div/2 do
      screen.move(0, i*size+shifty)
      screen.line_rel(128,0)
      if i < div/4 then
          screen.level(i*2)
        else
          screen.level(div-i*2)
      end
      screen.stroke()
    end

    screen.level(15)        -- horizontal centerline
    screen.line_width(1)
    screen.move(0,32)
    screen.line_rel(128,0)
    screen.stroke()

    screen.level(0)
      screen.move(0,31)
      screen.line_rel(128,0)
      screen.move(0,33)
      screen.line_rel(128,0)
      screen.move(63,0)
      screen.line_rel(0,64)
      screen.move(65,0)
      screen.line_rel(0,64)
      screen.stroke()

    screen.level(10)        -- center square
    screen.rect(62,30,3,3)
    screen.fill()

end

function polygon(cx, cy, radius, angle, points, fill)
	local radius = radius
	local angle = angle
	local points = points
	local fill = fill
	local adjustX = 0
	local adjustY = 0
	local x = {}
	local y = {}

	x[1] = cx
	y[1] = cy

	for i = 1, points + 1 do
		x[i+1] = x[1] + (radius * math.cos(angle + (i+i-1)*math.pi / points ))
		y[i+1] = y[1] + (radius * math.sin(angle + (i+i-1)*math.pi / points ))
	end
  
	if points == 1 then
	  screen.move(x[1],y[1])
	else
	  screen.move(x[2],y[2])
		  for i = 3, points + 1 do
		    -- ifs slighty adjustment shapes to make them appear more inline with the grid
		    if i % 3 >= 1 then
		      adjustX = -1
		    else adjustX = 0
		    end
		    if i % 3 <= 1 then
		      adjustY = -1
		    else
		      adjustY = 0
		    end
			  screen.line(x[i] + adjustX, y[i] + adjustY)
		  end
	end
	screen.line(x[2],y[2])
	screen.close()
	if (fill) then
	  if points <= 2 then
	    -- do nothing.
	  else
	  screen.fill()
	  end
	end
	screen.stroke()
return x,y end



-- -------------------
-- Utility functions
-- -------------------



function cloneTable(fromTable)
  local toTable = {}
  for orig_key, orig_value in pairs(fromTable) do
    toTable[orig_key] = orig_value
  end
  return toTable
end
