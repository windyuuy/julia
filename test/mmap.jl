file = tempname()
s = open(file, "w") do f
    write(f, "Hello World\n")
end
t = "Hello World".data
@test mmap(file, UInt8, (11,1,1)) == reshape(t,(11,1,1))
gc()
@test mmap(file, UInt8, (1,11,1)) == reshape(t,(1,11,1))
gc()
@test mmap(file, UInt8, (1,1,11)) == reshape(t,(1,1,11))
gc()
@test_throws ArgumentError mmap(file, UInt8, (11,0,1)) # 0-dimension results in len=0
@test mmap(file, UInt8, (11,)) == t
gc()
@test mmap(file, UInt8, (1,11)) == t'
gc()
@test_throws ArgumentError mmap(file, UInt8, (0,12))
m = mmap(file, UInt8, (1,2,1))
@test m == reshape("He".data,(1,2,1))
m=nothing; gc()

# constructors
@test length(mmap(file)) == 12
@test length(mmap(file, Int8)) == 12
@test length(mmap(file, Int8, (12,1))) == 12
@test length(mmap(file, Int8, (12,1), 0)) == 12
@test length(mmap(file, Int8, (12,1), 0; grow=false)) == 12
@test length(mmap(file, Int8, (12,1), 0; shared=false)) == 12
@test length(mmap(file, Int8, 12)) == 12
@test length(mmap(file, Int8, 12, 0)) == 12
@test length(mmap(file, Int8, 12, 0; grow=false)) == 12
@test length(mmap(file, Int8, 12, 0; shared=false)) == 12
s = open(file)
@test length(mmap(s)) == 12
@test length(mmap(s, Int8)) == 12
@test length(mmap(s, Int8, (12,1))) == 12
@test length(mmap(s, Int8, (12,1), 0)) == 12
@test length(mmap(s, Int8, (12,1), 0; grow=false)) == 12
@test length(mmap(s, Int8, (12,1), 0; shared=false)) == 12
@test length(mmap(s, Int8, 12)) == 12
@test length(mmap(s, Int8, 12, 0)) == 12
@test length(mmap(s, Int8, 12, 0; grow=false)) == 12
@test length(mmap(s, Int8, 12, 0; shared=false)) == 12
close(s)
@test_throws ArgumentError mmap(file, Ref)
gc()

s = open(f->f,file,"w")
@test_throws ArgumentError mmap(file) # requested len=0 on empty file
@test_throws ArgumentError mmap(file,UInt8,0)
m = mmap(file,UInt8,12)
m[:] = "Hello World\n".data
Mmap.sync!(m)
m=nothing; gc()
@test open(readall,file) == "Hello World\n"

s = open(file, "r")
close(s)
@test_throws Base.UVError mmap(s) # closed IOStream
@test_throws ArgumentError mmap(s,UInt8,12,0) # closed IOStream
@test_throws SystemError mmap("")

# negative length
@test_throws ArgumentError mmap(file, UInt8, -1)
# negative offset
@test_throws ArgumentError mmap(file, UInt8, 1, -1)

for i = 0x01:0x0c
    @test length(mmap(file, UInt8, i)) == Int(i)
end
gc()

sz = filesize(file)
m = mmap(file, UInt8, sz+1)
@test length(m) == sz+1 # test growing
@test m[end] == 0x00
m=nothing; gc()
sz = filesize(file)
m = mmap(file, UInt8, 1, sz)
@test length(m) == 1
@test m[1] == 0x00
m=nothing; gc()
sz = filesize(file)
# test where offset is actually > than size of file; file is grown with zeroed bytes
m = mmap(file, UInt8, 1, sz+1)
@test length(m) == 1
@test m[1] == 0x00
m=nothing; gc()

# Uncomment out once #11351 is resolved
# s = open(file, "r")
# m = mmap(s)
# @test_throws OutOfMemoryError m[5] = UInt8('x') # tries to setindex! on read-only array
# m=nothing; gc()

s = open(file, "w") do f
    write(f, "Hello World\n")
end

s = open(file, "r")
m = mmap(s)
close(s)
m=nothing; gc()
m = mmap(file)
s = open(file, "r+")
c = mmap(s)
d = mmap(s)
c[1] = UInt8('J')
Mmap.sync!(c)
close(s)
@test m[1] == UInt8('J')
@test d[1] == UInt8('J')
m=nothing; c=nothing; d=nothing; gc()

s = open(file, "w") do f
    write(f, "Hello World\n")
end

s = open(file, "r")
@test isreadonly(s) == true
c = mmap(s, UInt8, (11,))
@test c == "Hello World".data
c=nothing; gc()
c = mmap(s, UInt8, (UInt16(11),))
@test c == "Hello World".data
c=nothing; gc()
@test_throws ArgumentError mmap(s, UInt8, (Int16(-11),))
@test_throws ArgumentError mmap(s, UInt8, (typemax(UInt),))
close(s)
s = open(file, "r+")
@test isreadonly(s) == false
c = mmap(s, UInt8, (11,))
c[5] = UInt8('x')
Mmap.sync!(c)
close(s)
s = open(file, "r")
str = readline(s)
close(s)
@test startswith(str, "Hellx World")
c=nothing; gc()

c = mmap(file)
@test c == "Hellx World\n".data
c=nothing; gc()
c = mmap(file, UInt8, 3)
@test c == "Hel".data
c=nothing; gc()
s = open(file, "r")
c = mmap(s, UInt8, 6)
@test c == "Hellx ".data
close(s)
c=nothing; gc()
c = mmap(file, UInt8, 5, 6)
@test c == "World".data
c=nothing; gc()

s = open(file, "w")
write(s, "Hello World\n")
close(s)

# test mmap
m = mmap(file)
t = "Hello World\n"
for i = 1:12
    @test m[i] == t.data[i]
end
@test_throws BoundsError m[13]
m=nothing; gc()

m = mmap(file,UInt8,6)
@test m[1] == "H".data[1]
@test m[2] == "e".data[1]
@test m[3] == "l".data[1]
@test m[4] == "l".data[1]
@test m[5] == "o".data[1]
@test m[6] == " ".data[1]
@test_throws BoundsError m[7]
m=nothing; gc()

m = mmap(file,UInt8,2,6)
@test m[1] == "W".data[1]
@test m[2] == "o".data[1]
@test_throws BoundsError m[3]
finalize(m); gc()

s = open(file, "w")
write(s, [0xffffffffffffffff,
          0xffffffffffffffff,
          0xffffffffffffffff,
          0x000000001fffffff])
close(s)
s = open(file, "r")
@test isreadonly(s)
b = mmap(s, BitArray, (17,13))
@test b == trues(17,13)
@test_throws ArgumentError mmap(s, BitArray, (7,3))
close(s)
s = open(file, "r+")
b = mmap(s, BitArray, (17,19))
rand!(b)
Mmap.sync!(b)
b0 = copy(b)
close(s)
s = open(file, "r")
@test isreadonly(s)
b = mmap(s, BitArray, (17,19))
@test b == b0
close(s)
finalize(b); finalize(b0)
b = nothing; b0 = nothing
gc()
rm(file)

# mmap with an offset
A = rand(1:20, 500, 300)
fname = tempname()
s = open(fname, "w+")
write(s, size(A,1))
write(s, size(A,2))
write(s, A)
close(s)
s = open(fname)
m = read(s, Int)
n = read(s, Int)
A2 = mmap(s, Int, (m,n))
@test A == A2
seek(s, 0)
A3 = mmap(s, Int, (m,n), convert(FileOffset,2*sizeof(Int)))
@test A == A3
A4 = mmap(s, Int, (m,150), convert(FileOffset,(2+150*m)*sizeof(Int)))
@test A[:, 151:end] == A4
close(s)
finalize(A2); finalize(A3); finalize(A4)
gc()
rm(fname)

# AnonymousMmap
m = Mmap.AnonymousMmap()
@test m.name == ""
@test !m.readonly
@test m.create
@test isopen(m)
@test isreadable(m)
@test iswritable(m)

m = mmap(UInt8, 12)
@test length(m) == 12
@test all(m .== 0x00)
@test m[1] === 0x00
@test m[end] === 0x00
m[1] = 0x0a
Mmap.sync!(m)
@test m[1] === 0x0a
m = mmap(UInt8, 12; shared=false)
m = mmap(Int, 12)
@test length(m) == 12
@test all(m .== 0)
@test m[1] === 0
@test m[end] === 0
m = mmap(Float64, 12)
@test length(m) == 12
@test all(m .== 0.0)
m = mmap(Int8, (12,12))
@test size(m) == (12,12)
@test all(m == zeros(Int8, (12,12)))
@test sizeof(m) == prod((12,12))
n = similar(m)
@test size(n) == (12,12)
n = similar(m, (2,2))
@test size(n) == (2,2)
n = similar(m, 12)
@test length(n) == 12
@test size(n) == (12,)
