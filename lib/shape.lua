local point = include "lib/point"

local function init_points(n, r)
  local t = {count = 0}
  for i=1, n do
    t[i] = point:new(i, 1, r)
    t.count = t.count + 1
  end
  return t
end

local function clone_points(points)
  local cloned = {count = 0}
  for i, p in pairs(points) do
    if type(p) == "table" then
      cloned[i] = p:clone()
      cloned.count = cloned.count + 1
    end
  end
  return cloned
end

local shape = {}

function shape:new(center, radius, angle, n_points, speed)
  local o = {}
  self.__index = self
  setmetatable(o, self)
  o.c = center
  o.a = angle
  o.p = init_points(n_points, radius)
  o.f = o.p[1]
  o.s = speed
  return o
end
  
function shape:clone()
  local c = {x = self.c.x, y = self.c.y}
  local cloned = shape:new(c, 0, self.a, 0, self.s)
  cloned.p = clone_points(self.p)
  cloned.f = cloned.p[1]
  return cloned
end
  
function shape:restore()
  for _, t in ipairs(self.p) do
    setmetatable(t, point.__index)
  end
end
  
function shape:change_radius(d)
  for _, point in pairs(self.p) do
    if type(point) == "table" then
      point.distance = util.clamp(point.distance + d, 1, 10)
    end
  end
end
  
function shape:change_points(d)
  self.p.count = util.clamp(self.p.count + d, 1, 4)
end
  
function shape:change_focused_point(d)
  local k = tab.key(self.p, self.f)
  if k then
    self.f = self.p[util.clamp(k + d, 1, self.p.count)]
  else
    self.f = self.p[1]
  end
end

function shape:change_point_radius(d)
  self.f.distance = util.clamp(self.f.distance + d, 1, 10)
end

function shape:change_point_weight(d)
  self.f.weight = util.clamp(self.f.weight + d, -9999, 9999)
end

function shape:change_point_group(d)
  self.f.group = util.clamp(self.f.group + d, 1, 4)
end
  
function shape:values()
  local center = self.c
  local angle  = self.a
  local points = self.p
  
  local xs = {}
  local ys = {}
  
  for i=1, points.count do
    local radius = points[i].distance
    local weight = points[i].weight
    local group  = points[i].group
    xs[i] = {
      v = center.x + (radius * math.cos( (((i-1)*2*math.pi) / points.count) + angle) ),
      w = weight,
      g = group
    }
    ys[i] = {
      v = center.y + (radius * math.sin( (((i-1)*2*math.pi) / points.count) + angle) ),
      w = weight,
      g = group
    }
  end
  
  return xs, ys
end
  
function shape:draw(map_x, map_y, brightness)
  local center = {x = map_x(self.c.x), y = map_y(self.c.y)}
  local xs, ys = self:values()
  local count = tab.count(xs)
  local first_point = { x = map_x(xs[1].v), y = map_y(ys[1].v) }
  local last_point  = { x = map_x(xs[count].v), y = map_y(ys[count].v) }

  screen.aa(1)

  if count == 1 then
    screen.move(center.x, center.y)
  else
    for i = 2, count do
      local from = { x = map_x(xs[i-1].v), y = map_y(ys[i-1].v) }
      local to   = { x = map_x(xs[i].v), y = map_y(ys[i].v) }
      screen.move(from.x, from.y)
      screen.line(to.x, to.y)
    end
    screen.move(last_point.x, last_point.y)
  end
  screen.line(first_point.x , first_point.y)
  screen.close()
	
  screen.level(brightness)
  screen.stroke()
  
  screen.aa(0)
end
  
function shape:draw_arrow_to_focused_point(map_x, map_y, offset)
  local center = {x = map_x(self.c.x), y = map_y(self.c.y)}
  local angle  = self.a
  local points = self.p
  
  screen.aa(1)
  
  local i = tab.key(points, self.f)
  local radius = points[i].distance * 6 + offset
  local x = center.x + (radius * math.cos( (((i-1)*2*math.pi) / points.count) + angle) )
  local y = center.y + (radius * math.sin( (((i-1)*2*math.pi) / points.count) + angle) )
  local arrow_side1x = x + (6  * math.cos( (((i-1)*2*math.pi) / points.count) - (math.pi/4)))
  local arrow_side1y = y + (6  * math.sin( (((i-1)*2*math.pi) / points.count) - (math.pi/4)))
  local arrow_side2x = x + (6  * math.cos( (((i-1)*2*math.pi) / points.count) + (math.pi/4)))
  local arrow_side2y = y + (6  * math.sin( (((i-1)*2*math.pi) / points.count) + (math.pi/4)))
  local arrow_shaftx1 = center.x + ((radius+2)  * math.cos( (((i-1)*2*math.pi) / points.count) + angle) )
  local arrow_shafty1 = center.y + ((radius+2)  * math.sin( (((i-1)*2*math.pi) / points.count) + angle) )
  local arrow_shaftx2 = center.x + ((radius+10) * math.cos( (((i-1)*2*math.pi) / points.count) + angle) )
  local arrow_shafty2 = center.y + ((radius+10) * math.sin( (((i-1)*2*math.pi) / points.count) + angle) )
  
  screen.move(x,y)
  screen.line(arrow_side1x, arrow_side1y)
  screen.move(x,y)
  screen.line(arrow_side2x, arrow_side2y)
  screen.line(arrow_side1x, arrow_side1y)
  screen.fill()
  screen.line_width(3)
  screen.move(arrow_shaftx1, arrow_shafty1)
  screen.line(arrow_shaftx2, arrow_shafty2)
  screen.stroke()
  screen.line_width(1)
  
  screen.aa(0)
end
  
return shape
