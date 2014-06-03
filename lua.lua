-- So let's start with adding POSITIVE INTEGERS (integers > 0) without +

function add1(x,y) return -((-x)-y) end

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
