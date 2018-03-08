--cc learns love 2d game

GRAVITY = 0.1
COLOURS = {
  normal = {220, 220, 220},
  target = {233, 21, 91}
}
BACKGROUND = {40, 38, 38}
SEGMENTS = 9
SEGMENT_HEIGHT = {
  min = 40,
  max = 800
}
WAIT_TIME = 2

local lander = {
  x = 0, y = 0,
  width = 50, height = 50,
  fuel = 0,
  maxFuel = 80,
  speed = { x = 0, y = 0 },
  terminalSpeed = 20,
  thrust = {
    left = -0.1,
    right = 0.1,
    down = -0.3
  },
  direction = {
    left = false,
    right = false,
    down = false
  }
}

local sagments = {}

local keyConfig = {
  left = {
    left = true,
    a = true
  },
  right = {
    right = true,
    d = true
  },
  down = {
    down = true,
    space = true
  }
}

local pulse = 0
local waitingtimer = 0
local waiting = false
local pss = {}

function love.load()
  math.randomseed(love.timer.getTime())
  love.window.setMode(700, 700, {
      vsync = true,
      highdpi = true,
      fullscreen = false,
      msaa = 0,
  })

  -- create all the particle systems
  psMain = createPs(1.57, 0.6)
  psLeft = createPs(3.14, 0.3)
  psRight = createPs(0, 0.3)
  psExplode = createPs(0, 1, 256)
  psExplode:setSpread(math.rad(360))
  psExplode:setSpeed(300, 500)
  psExplode:setSizes(0.25)
  psWin = createPs(0, 2, 32)
  psWin:setSpread(math.rad(360))
  psWin:setSpeed(400, 400)
  psWin:setSizes(0.3)
  psWin:setLinearDamping(0.4)
  psWin:setColors(COLOURS.target,{255,255,255,255,0})

  WIDTH = love.graphics.getWidth()
  HEIGHT = love.graphics.getHeight()
  CENTER = { x = WIDTH / 2, y = HEIGHT / 2}

  love.graphics.setBackgroundColor(BACKGROUND)
  love.graphics.setLineWidth(0)
  love.graphics.setFont(love.graphics.newFont(25))

  initLander()
end

function love.update(dt)
  if not waiting then
    lander.speed.y = lander.speed.y + GRAVITY
    if lander.speed.y > lander.terminalSpeed then
      lander.speed.y = lander.terminalSpeed
    end

    if lander.fuel > 0 then
      if lander.direction.down then
        psMain:moveTo(lander.x + lander.width/2, lander.y + lander.height)
        psMain:emit(4)
        lander.speed.y = lander.speed.y + lander.thrust.down
        lander.fuel = lander.fuel - math.abs(lander.thrust.down)
      end

      if lander.direction.left then
        psRight:moveTo(lander.x + lander.width, lander.y + lander.height/2)
        psRight:emit(1)
        lander.speed.x = lander.speed.x + lander.thrust.left
        lander.fuel = lander.fuel - math.abs(lander.thrust.left)
      end

      if lander.direction.right then
        psLeft:moveTo(lander.x, lander.y + lander.height/2)
        psLeft:emit(1)
        lander.speed.x = lander.speed.x + lander.thrust.right
        lander.fuel = lander.fuel - math.abs(lander.thrust.right)
      end
    end

    lander.x = lander.x + lander.speed.x
    lander.y = lander.y + lander.speed.y
  end

  if pulse == 10 then
    pulse = 0
  else
    pulse = pulse + 1
  end

  -- simple collission detection
  if lander.x < 0 or lander.x > WIDTH or lander.y > HEIGHT then
    explode()
  end
  for index, segment in ipairs(sagments) do
    if lander.x + lander.width >= segment.x and lander.x <= segment.x + segment.width and lander.y + lander.height >= segment.y and lander.y <= segment.y + segment.height then
      if segment.isTarget then
        if lander.y < segment.y and lander.speed.y < 2 then
          win()
          break
        else
          explode()
        end
      else
        explode()
      end
    end
  end

  --update all particle systems
  for i, pSystem in ipairs(pss) do
    pSystem:update(dt)
  end

  if waiting then
    waitingtimer = waitingtimer + dt
    if waitingtimer > WAIT_TIME then
      waiting = false
      waitingtimer = 0
      initLander()
    end
  end
end

function love.draw()
  drawGround()
  drawFuelGauge()
  love.graphics.setColor({255, 255, 255})
  for i, pSystem in ipairs(pss) do
    love.graphics.draw(pSystem)
  end
  drawLander()
end

function love.keypressed(key)
  for dir, conf in pairs(keyConfig) do
    if conf[key] == true then
      lander.direction[dir] = true
    end
  end
end

function love.keyreleased(key)
  for dir, conf in pairs(keyConfig) do
    if conf[key] == true then
      lander.direction[dir] = false
    end
  end
end

-- create a particle system
function createPs(direction, life, particles)
  if particles == nil then particles = 128 end
  local ps = love.graphics.newParticleSystem(love.graphics.newImage('particle.png'), particles)
  ps:setParticleLifetime(life)
  ps:setSizes(0.15)
  ps:setSpeed(800, 1000)
  ps:setAreaSpread('uniform', lander.width / 2, lander.width / 2)
  ps:setColors(COLOURS.target, {40, 38, 38, 0})
  ps:setDirection(direction)
  pss[#pss + 1] = ps
  return ps
end

-- initialise new game state
function initLander()
  lander.y = lander.height
  lander.x = CENTER.x - lander.width / 2
  lander.speed = {x = 0, y = 0}
  lander.fuel = lander.maxFuel
  lander.finished = false
  lander.hide = false
  lander.won = false

  local target = math.random(1, SEGMENTS)

  for index = 1, SEGMENTS, 1 do
    local height = math.random(SEGMENT_HEIGHT.min, SEGMENT_HEIGHT.max)
    sagments[index] = {
      x = index * WIDTH  / SEGMENTS - (lander.width * 2),
      y = HEIGHT - height,
      width = lander.width * 1.5,
      height = height,
      isTarget = index == target
    }
  end
end

-- draw ground segments
function drawGround()
  for index, segment in ipairs(sagments) do
    local colour = COLOURS.normal
    if segment.isTarget and not lander.won == true then colour = COLOURS.target end
    love.graphics.setColor(colour)
    love.graphics.rectangle("fill", segment.x, segment.y, segment.width, segment.height)
  end
end

-- draw the lander
function drawLander()
  if lander.hide then return nil end

  local colour = COLOURS.target

  love.graphics.setColor(BACKGROUND)
  love.graphics.rectangle("fill", lander.x, lander.y, lander.width, lander.height, 2)
  love.graphics.setLineWidth(4)
  love.graphics.setColor(colour)
  love.graphics.rectangle("line", lander.x, lander.y, lander.width, lander.height, 2)
  love.graphics.setLineWidth(0)

  local fuelHeight = lander.fuel / lander.maxFuel * lander.height
  love.graphics.rectangle("fill", lander.x, lander.y + lander.height - fuelHeight, lander.width, fuelHeight, 2)
end

-- draw the fuel warning
function drawFuelGauge()
  love.graphics.setColor(COLOURS.target)
  if lander.fuel <= 0 and pulse < 8 then
    love.graphics.rectangle("fill", 30, 30, 170, 50)
    love.graphics.setColor(BACKGROUND)
    love.graphics.print("EMPTY FUEL", 40, 40)
  end
end

-- handle lander crash
function explode()
  if not waiting then
    psExplode:moveTo(lander.x, lander.y)
    psExplode:emit(256)
    waiting = true
    lander.hide = true
  end
end

-- handle lander landing sucessfully
function win()
  if not waiting then
    waiting = true
    lander.won = true
    lander.fuel = lander.maxFuel
    psWin:moveTo(lander.x, lander.y)
    psWin:emit(30)
  end
end
