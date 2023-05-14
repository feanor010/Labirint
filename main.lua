local PriorityQueue = require('priority-queue')

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local TYPE = {
  FLOOR = 0,
  WALL = 100,
}

local symbols = {
  floor = string.byte('_'),
  wall = string.byte('#'),
  water = string.byte('^'),
  player = string.byte('@'),
  target = string.byte('>'),
  newline = string.byte('\n')
}

local mapData = trim [[
_____________________
#__________>___#____#
#_####_________####_#
#______#____________#
#____#_#_______#____#
######_#_______######
_____________________
####_#####__#########
####_#####__#########
####_##_______#######
_________#_#_________
_#_#######_#######_#_
_#_#________#____#_#_
_#____#_____#____#_#_
_#_####_____###__#_#_
_@___________________
]]

-- local mapData = trim[[
-- ^^_____#______^^
-- ^^_____#______^^
-- ^^_____#______^^
-- ^^____________^^
-- ^^_____________^
-- _____^^^^^^_____
-- _____^^^^^______
-- _____^^^^^______
-- _@___^^^^^____>_
-- ______###_______
-- ______##________
-- ^^___^^^^^____^^
-- ^^___^^^^^^^#_^^
-- ^^____________^^
-- ^^_____#______^^
-- ^^_____#______^^
-- ]]

-- local mapData = trim[[
-- ________________
-- _____________>__
-- _##############_
-- ______________#_
-- ______________#_
-- ______________#_
-- ______________#_
-- ______________#_
-- ______________#_
-- ______________#_
-- ______________#_
-- ______________#_
-- ___@__________#_
-- ______________#_
-- __#############_
-- ________________
-- ]]

local function l1(src, dst)
  -- l1 метрика aka Манхеттенское расстояние
  return math.abs(src.x - dst.x) + math.abs(src.y - dst.y)
end

local function parseWorld(data)
  local map = {}
  local playerPos = nil
  local targetPos = nil

  local x = 1
  local y = 1

  table.insert(map, {}) -- first line

  for i = 1, #data do
    local cell = data:byte(i)

    if cell == symbols.newline then
      y = y + 1
      x = 1
      table.insert(map, {})
    else
      if cell == symbols.player then
        playerPos = { x = x, y = y }
        table.insert(map[y], { id = i, cost = 1, x = x, y = y, type = TYPE.FLOOR })
      elseif cell == symbols.target then
        targetPos = { x = x, y = y }
        table.insert(map[y], { id = i, cost = 1, x = x, y = y, type = TYPE.FLOOR })
      elseif cell == symbols.wall then
        table.insert(map[y], { id = i, cost = -1, x = x, y = y, type = TYPE.WALL })
      elseif cell == symbols.water then
        table.insert(map[y], { id = i, cost = 3, x = x, y = y, type = TYPE.WATER })
      else
        table.insert(map[y], { id = i, cost = 1, x = x, y = y, type = TYPE.FLOOR })
      end
      x = x + 1
    end
  end

  return { map = map, player = playerPos, target = targetPos }
end

local function neighbors(map, pos)
  local candidates = {
    { x = pos.x - 1, y = pos.y },
    { x = pos.x,     y = pos.y - 1 },
    { x = pos.x + 1, y = pos.y },
    { x = pos.x,     y = pos.y + 1 },
  }
  local result = {}
  local width = #map[1]
  local height = #map
  for _, candidate in ipairs(candidates) do
    if (candidate.x >= 1 and candidate.y >= 1 and candidate.x <= width and candidate.y <= height) then
      local cell = map[candidate.y][candidate.x]
      if cell.cost >= 0 then
        table.insert(result, cell)
      end
    end
  end
  return result
end

local world = nil
local search = nil
local UI = {
  bw = 32,
  bh = 32,
  pr = 12,
  tr = 12,
  dr = 4,
  padding = 2,
}

local function drawPos(x, y)
  local posX = x * (UI.bw + UI.padding)
  local posY = y * (UI.bh + UI.padding)
  return posX, posY
end

local function drawPosCircle(x, y, r)
  local posX, posY = drawPos(x, y)
  return posX + UI.bw / 2, posY + UI.bh / 2
end



local function aStarSearch(world)
  local start = world.map[world.player.y][world.player.x]
  start.visited = true
  start.from = nil
  start.costGot = 0

  local queue = PriorityQueue.new()
  queue:Add(start, 0)

  local function next()
    if queue:Size() < 1 then
      return false
    end

    local cur = queue:Pop()

    -- ранний выход
    if cur.x == world.target.x and cur.y == world.target.y then
      world.target.x = world.target.x + 1
      return false
    end

    local nlist = neighbors(world.map, cur)
    for _, n in ipairs(nlist) do
      local newCost = n.cost + (cur.costGot or 0)
      if n.visited ~= true or newCost < (n.costGot or 0) then
        n.visited = true
        n.from = cur
        n.costGot = newCost
        local priority = newCost + l1(world.target, n)
        queue:Add(n, -priority)
      end
    end

    return true
  end

  return { next = next }
end

local function backPath(world)
  local cur = world.map[world.target.y][world.target.x]
  local done = false
  local path = {}
  while not done do
    table.insert(path, cur)
    local prev = cur.from
    if prev.from == nil then
      done = true
    else
      cur = prev
    end
  end
  world.path = path
end

function love.load()
  world = parseWorld(mapData)
end

local time = 0
local hasNext = true
local kd = 0


function love.update(dt)
  if kd > 0 then
    kd = kd - dt
  end
  print('Player ' .. world.player.x, world.player.y)
  -- search = breadthSearch(world)
  -- search = breadthSearchOptimized(world)
  -- search = deikstraSearch(world)
  search = aStarSearch(world)


  if love.keyboard.isDown("right") and kd <= 0 then
    if world.player.x + 1 > #world.map[1] then
      world.player.x = 1
    elseif world.map[world.player.y][world.player.x + 1].type == TYPE.FLOOR then
      world.player.x = world.player.x + 1;
      kd = 0.2
    end
  end
  if love.keyboard.isDown("up") and kd <= 0 then
    if world.player.y - 1 < 1 then
      world.player.y = #world.map
    elseif world.map[world.player.y - 1][world.player.x].type == TYPE.FLOOR then
      world.player.y = world.player.y - 1;
      kd = 0.2
    end
  end
  if love.keyboard.isDown("down") and kd <= 0 then
    if world.player.y + 1 > #world.map then
      world.player.y = 1
    elseif world.map[world.player.y + 1][world.player.x].type == TYPE.FLOOR then
      world.player.y = world.player.y + 1;
      kd = 0.2
    end
  end
  if love.keyboard.isDown("left") and kd <= 0 then
    if world.player.x - 1 < 1 then
      world.player.x = #world.map[1]
    elseif world.map[world.player.y][world.player.x - 1].type == TYPE.FLOOR then
      world.player.x = world.player.x - 1;
      kd = 0.2
    end
  end



  if hasNext then
    hasNext = search.next()
    if not hasNext then
      backPath(world)
      print('Save path')
    end
  end
end

local floorImage = love.graphics.newImage("Floor.jpg")
local kripWall = love.graphics.newImage("krip.jpg")

function love.draw()
  for y, line in ipairs(world.map) do
    for x, cell in ipairs(line) do
      local bx, by = drawPos(x, y)
      if cell.type == TYPE.FLOOR then
        love.graphics.draw(floorImage, bx, by)
      else
        love.graphics.draw(kripWall, bx, by)
      end
    end
  end

  local px, py = drawPosCircle(world.player.x, world.player.y, UI.pr)
  love.graphics.setColor(1, 0, 1)
  love.graphics.circle('fill', px, py, UI.pr)

  local tx, ty = drawPosCircle(world.target.x, world.target.y, UI.tr)
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle('fill', tx, ty, UI.tr)

  if world.path ~= nil then
    for _, d in ipairs(world.path) do
      local dx, dy = drawPosCircle(d.x, d.y, UI.dr)
      love.graphics.setColor(1, 1, 1)
      love.graphics.circle('fill', dx, dy, UI.dr)
    end
  end
end
