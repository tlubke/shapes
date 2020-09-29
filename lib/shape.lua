local shape = {}

function shape:new(center, radius, angle, n_points, speed)
  local o = {}
  self.__index = self
  setmetatable(o, self)
  o.c = center
  o.r = radius
  o.a = angle
  o.p = n_points
  o.s = speed
  return o
end
  
function shape:clone()
  local c = {x = self.c.x, y = self.c.y}
  return shape:new(c, self.r, self.a, self.p, self.s)
end
  
function shape:values()
  local center = self.c
  local radius = self.r
  local angle  = self.a
  local points = self.p
  
  local xs = {}
  local ys = {}
  
  for i=1, points do
    xs[i] = center.x + (radius * math.cos( ((2*i*math.pi) / points) + angle) )
    ys[i] = -(center.y + (radius * math.sin( ((2*i*math.pi) / points) + angle) ))
  end
  
  return xs, ys
end
  
function shape:draw(map_x, map_y, brightness, show_numbers)
  local center = {x = map_x(self.c.x), y = map_y(self.c.y)}
  local radius = self.r * 6
  local angle  = self.a
  local points = self.p
  
	local xs = {}
	local ys = {}

	for i = 1, points do
		xs[i] = center.x + (radius * math.cos( ((2*i*math.pi) / points) + angle) )
		ys[i] = center.y + (radius * math.sin( ((2*i*math.pi) / points) + angle) )
	end
  
	if points == 1 then
	  screen.move(center.x, center.y)
	else
	  for i = 2, points do
	    screen.move(xs[i-1],ys[i-1])
		  screen.line(xs[i], ys[i])
	  end
	  screen.move(xs[points], ys[points])
	end
	screen.line(xs[1],ys[1])
	screen.close()
	
	if show_numbers then
	  for i = 1, points do
	    screen.move(xs[i], ys[i])
	    screen.text(i)
	  end
	end
	
	screen.level(brightness)
	screen.stroke()
end
  
return shape