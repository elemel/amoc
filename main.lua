function normalize(x, y, z)
  local length = math.sqrt(x * x + y * y + z * z)
  return x / length, y / length, z / length, length
end

function randomPointInSphere(random)
  while true do
    local x = love.math.random() * 2 - 1
    local y = love.math.random() * 2 - 1
    local z = love.math.random() * 2 - 1

    if x * x + y * y + z * z <= 1 then
      return x, y, z
    end
  end
end

function randomPointOnSphere()
  return normalize(randomPointInSphere())
end

-- See: https://www.rorydriscoll.com/2009/01/07/better-sampling/
function cosineSampleHemisphere()
  local u1 = love.math.random()
  local u2 = love.math.random()

  local r = math.sqrt(u1)
  local theta = 2 * math.pi * u2

  local x = r * math.cos(theta)
  local y = r * math.sin(theta)
  local z = math.sqrt(math.max(0, 1 - u1))

  return x, y, z
end

-- See: https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Line_defined_by_two_points
function distanceFromPointToLine(x, y, ax, ay, bx, by)
  return math.abs((bx - ax) * (ay - y) - (ax - x) * (by - ay))
    / math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
end

function isBlock(mask, dx, dy)
  assert(-1 <= dx and dx <= 1)
  assert(-1 <= dy and dy <= 1)
  assert(dx ~= 0 or dy ~= 0)
  local n = 3 * (dy + 1) + (dx + 1)

  if n >= 5 then
    n = n - 1
  end

  assert(0 <= n and n <= 7)
  return bit.band(bit.rshift(mask, n), 1) ~= 0
end

function love.load()
  mapSize = 32
  imageSize = mapSize * 16
  globalPixel = 0

  meanLightings = {}
  sampleCounts = {}

  imageData = love.image.newImageData(imageSize, imageSize, "rgba16f")
  image = love.graphics.newImage(imageData)
  image:setFilter("linear", "nearest")

  mask = 255
end

function sampleLighting(mask, ax, ay)
  -- local dx, dy = randomPointOnSphere()
  local dx, dy = cosineSampleHemisphere()
  local radius = 1 -- love.math.random()

  local bx = ax + radius * dx
  local by = ay + radius * dy

  local blockDx = math.floor(bx)
  local blockDy = math.floor(by)

  local lighting = 1

  if blockDx ~= 0 or blockDy ~= 0 then
    if isBlock(mask, blockDx, blockDy) then
      lighting = 0
    else
      if blockDx ~= 0 and blockDy ~= 0 then
        if
          distanceFromPointToLine(blockDx, 0, ax, ay, bx, by)
          < distanceFromPointToLine(0, blockDy, ax, ay, bx, by)
        then
          lighting = isBlock(mask, blockDx, 0) and 0 or 1
        else
          lighting = isBlock(mask, 0, blockDy) and 0 or 1
        end
      end
    end
  end

  return lighting
end

function love.update(dt)
  for i = 1, 8192 do
    local globalPixelX = globalPixel % imageSize
    local globalPixelY = math.floor(globalPixel / imageSize)

    local mapX = math.floor(globalPixelX / mapSize)
    local mapY = math.floor(globalPixelY / mapSize)

    local mask = 16 * mapY + mapX

    local pixelX = globalPixelX % mapSize
    local pixelY = globalPixelY % mapSize

    local ax = (pixelX + 0.5) / mapSize
    local ay = (pixelY + 0.5) / mapSize

    local meanLighting = meanLightings[globalPixel] or 0
    local sampleCount = sampleCounts[globalPixel] or 0

    for j = 1, 16 do
      local lighting = sampleLighting(mask, ax, ay)

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
  if key == "escape" or key == "return" then
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

  if key == "escape" then
    love.event.quit()
  end
end
