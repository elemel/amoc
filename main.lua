local band = assert(bit.band)
local cos = assert(math.cos)
local floor = assert(math.floor)
local huge = assert(math.huge)
local max = assert(math.max)
local min = assert(math.min)
local pi = assert(math.pi)
local sin = assert(math.sin)
local sqrt = assert(math.sqrt)

-- See: https://www.rorydriscoll.com/2009/01/07/better-sampling/
function cosineSampleHemisphere(u1, u2)
  local r = sqrt(u1)
  local theta = 2 * pi * u2

  local x = r * cos(theta)
  local y = r * sin(theta)
  -- local z = sqrt(max(0, 1 - u1))

  return x, y
end

-- See: https://tavianator.com/2011/ray_box.html
function rayCastBox(x, y, invDx, invDy, minX, minY, maxX, maxY)
  local tx1 = (minX - x) * invDx
  local tx2 = (maxX - x) * invDx

  local minTx = min(tx1, tx2)
  local maxTx = max(tx1, tx2)

  local ty1 = (minY - y) * invDy
  local ty2 = (maxY - y) * invDy

  local minTy = min(ty1, ty2)
  local maxTy = max(ty1, ty2)

  local minT = max(minTx, minTy)
  local maxT = min(maxTx, maxTy)

  return maxT >= 0 and minT <= maxT and max(0, minT) or huge
end

function rayCast(x, y, dx, dy, neighborMask)
  local invDx = 1 / dx
  local invDy = 1 / dy

  local distance = huge

  if dx < 0 and dy < 0 and band(neighborMask, 1) ~= 0 then
    distance = min(distance, rayCastBox(x, y, invDx, invDy, -1, -1, 0, 0))
  end

  if dy < 0 and band(neighborMask, 2) ~= 0 then
    distance = min(distance, rayCastBox(x, y, invDx, invDy, 0, -1, 1, 0))
  end

  if dx > 0 and dy < 0 and band(neighborMask, 4) ~= 0 then
    distance = min(distance, rayCastBox(x, y, invDx, invDy, 1, -1, 2, 0))
  end

  if dx < 0 and band(neighborMask, 8) ~= 0 then
    distance = min(distance, rayCastBox(x, y, invDx, invDy, -1, 0, 0, 1))
  end

  if dx > 0 and band(neighborMask, 16) ~= 0 then
    distance = min(distance, rayCastBox(x, y, invDx, invDy, 1, 0, 2, 1))
  end

  if dx < 0 and dy > 0 and band(neighborMask, 32) ~= 0 then
    distance = min(distance, rayCastBox(x, y, invDx, invDy, -1, 1, 0, 2))
  end

  if dy > 0 and band(neighborMask, 64) ~= 0 then
    distance = min(distance, rayCastBox(x, y, invDx, invDy, 0, 1, 1, 2))
  end

  if dx > 0 and dy > 0 and band(neighborMask, 128) ~= 0 then
    distance = min(distance, rayCastBox(x, y, invDx, invDy, 1, 1, 2, 2))
  end

  return distance
end

function saveScreenshot()
  local gammaImageData = love.image.newImageData(imageSize, imageSize)

  gammaImageData:mapPixel(function(x, y, r, g, b, a)
    return love.math.linearToGamma(imageData:getPixel(x, y))
  end)

  local filename = "screenshot-" .. os.time() .. ".png"
  gammaImageData:encode("png", filename)

  print(
    "Saved screenshot: "
      .. love.filesystem.getSaveDirectory()
      .. "/"
      .. filename
      .. ""
  )
end

function love.load()
  mapSize = 16
  imageSize = mapSize * 16
  globalPixel = 0

  meanLightings = {}
  sampleCounts = {}

  imageData = love.image.newImageData(imageSize, imageSize, "rgba16f")
  image = love.graphics.newImage(imageData)
  image:setFilter("linear", "nearest")

  neighborMask = 255
end

function love.update(dt)
  for i = 1, 4096 do
    local globalPixelX = globalPixel % imageSize
    local globalPixelY = floor(globalPixel / imageSize)

    local mapX = floor(globalPixelX / mapSize)
    local mapY = floor(globalPixelY / mapSize)

    local neighborMask = 16 * mapY + mapX

    local pixelX = globalPixelX % mapSize
    local pixelY = globalPixelY % mapSize

    local x = (pixelX + 0.5) / mapSize
    local y = (pixelY + 0.5) / mapSize

    local meanLighting = meanLightings[globalPixel] or 0
    local sampleCount = sampleCounts[globalPixel] or 0

    for j = 1, 16 do
      local u1 = love.math.random()
      local u2 = love.math.random()

      local dx, dy = cosineSampleHemisphere(u1, u2)
      local distance = rayCast(x, y, dx, dy, neighborMask)

      -- local lighting = min(distance, 1)
      local lighting = distance <= 1 and 0 or 1

      meanLighting = (meanLighting * sampleCount + lighting) / (sampleCount + 1)
      sampleCount = sampleCount + 1
    end

    meanLightings[globalPixel] = meanLighting
    sampleCounts[globalPixel] = sampleCount

    imageData:setPixel(
      globalPixelX,
      globalPixelY,
      meanLighting,
      meanLighting,
      meanLighting,
      1
    )

    globalPixel = (globalPixel + 1) % (imageSize * imageSize)
  end

  image:replacePixels(imageData)
end

function love.draw()
  local graphicsWidth, graphicsHeight = love.graphics.getDimensions()
  local scale = graphicsHeight / imageSize
  love.graphics.draw(
    image,
    0.5 * graphicsWidth,
    0.5 * graphicsHeight,
    0,
    scale,
    scale,
    0.5 * imageSize,
    0.5 * imageSize
  )

  love.graphics.print(love.timer.getFPS())
end

function love.keypressed(key, scancode, isrepeat)
  if key == "escape" then
    love.event.quit()
  elseif key == "return" then
    saveScreenshot()
  end
end

function love.quit()
  saveScreenshot()
end
