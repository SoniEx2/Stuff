-- So let's start with adding POSITIVE INTEGERS (integers > 0) without +

function increment1(i)
  for x=i,math.huge do
    if x>i then
      return x
    end
  end
end

function add2(a,b)
  for i=1,b do
    a = increment1(a)
  end
  return a
end

-- Oh so you want negative integers too?

function add3(a,b)
  if a == 0 then
    return b
  elseif b == 0 then
    return a
  end
  if b > 0 then
    return add2(a,b)
  else
    return -add2(-a,-b)
  end
end

-- Want anything?

function add1(x,y) return -((-x)-y) end

function add4(a,b)
  local x,y,z = a, math.huge, b
  if b < 0 then
    y = -y -- aka -math.huge
  end
  local c
  for i=x, y, z do
    if c then
      return i
    end
    c = true
  end
  -- b=0 handling
  return a
end

-- Multiply

function mul1(a,b)
  if b > 0 then
    for i=1,b do
      a = add1(a,a)
    end
  else
    for i=1,-b do
      a = add1(a,a)
    end
    return -a
  end
  return a
end

function mul2(a,b) -- POSITIVE a ONLY
  if b > 0 then
    for i=1,b do
      a = add2(a,a)
    end
  else
    for i=1,-b do
      a = add2(a,a)
    end
    return -a
  end
  return a
end

function mul3(a,b)
  if b > 0 then
    for i=1,b do
      a = add3(a,a)
    end
  else
    for i=1,-b do
      a = add3(a,a)
    end
    return -a
  end
  return a
end

-- Same logic as add1 above, but with division instead

function mul4(a,b)
  return a / (1/b)
end
