local point = {}

function point:new(group, weight, distance_from_center)
  local o = {}
  self.__index = self
  setmetatable(o, self)
  o.group    = group
  o.weight   = weight
  o.distance = distance_from_center
  return o
end

function point:clone()
  return point:new(self.group, self.weight, self.distance)
end
  
return point