module crypto.utils;

import std.bigint;
import std.array;
import std.algorithm;
import std.traits : Unqual;
import std.conv;
import std.random;

struct BigIntHelper
{
    static ubyte[] bigIntToUByteArray(BigInt value)
    {
        Appender!(ubyte[]) app;

        while (value > 0)
        {
            app.put((value - ((value >> 8) << 8)).to!ubyte);
            value >>= 8;
        }

        reverse(app.data);

        return app.data;
    }

    static BigInt bigIntFromUByteArray(in ubyte[] buffer)
    {
        BigInt ret = BigInt("0");

        for (uint i; i < buffer.length; i++)
        {
            ret <<= 8;
            ret += buffer[i];
        }

        return ret;
    }

//    static BigInt powMod(BigInt base, BigInt modulus, BigInt exponent)
//    {
//        assert(base >= 1 && exponent >= 0 && modulus >= 1);
//
//        BigInt result = BigInt("1");
//
//        while (exponent > 0)
//        {
//            if (exponent & 1)
//            {
//                result = (result * base) % modulus;
//            }
//
//            base = ((base % modulus) * (base % modulus)) % modulus;
//            exponent >>= 1;
//        }
//
//        return result;
//    }

    static BigInt powMod(BigInt base, BigInt modulus, BigInt exponent)
    {
        assert(base >= 1 && exponent >= 0 && modulus >= 1);

        if (exponent == 0)
        {
            return BigInt(1) % modulus;
        }

        if (exponent == 1)
        {
            return base % modulus;
        }

        BigInt temp = powMod(base, modulus, exponent / 2);

        return (exponent & 1) ? (temp * temp * base) % modulus : (temp * temp) % modulus;
    }
}

/++ Fast but cryptographically insecure source of random numbers. +/
struct InsecureRandomGenerator
{
    private static Mt19937 generator;

    static this()
    {
        generator.seed(unpredictableSeed);
    }

    T next(T = uint)(T min = T.min, T max = T.max) if (is(Unqual!T == uint) || is(Unqual!T == int) || is(Unqual!T == ubyte) || is(Unqual!T == byte))
    {
        return uniform!("[]", T, T, typeof(generator))(min, max, generator);
    }
}

version (LDC)
{
    import ldc.intrinsics : llvm_memset;
}
else private @nogc nothrow pure @system
{
    version (linux)
        extern(C) void explicit_bzero(void* ptr, size_t cnt);
    version (FreeBSD)
        extern(C) void explicit_bzero(void* ptr, size_t cnt);
    version (OpenBSD)
        extern(C) void explicit_bzero(void* ptr, size_t cnt);
    version (OSX)
        extern(C) int memset_s(void* ptr, size_t destsz, int c, size_t n);
}

/++
Sets the array to all zero. When compiling with LDC uses an intrinsic
function that prevents the compiler from deeming the data write
unnecessary and omitting it. When not compiling with LDC uses
`explicit_bzero` on Linux, FreeBSD, and OpenBSD and `memset_s` on Mac
OS X for the same purpose. The typical use of this function is to
to erase secret keys after they are no longer needed.

Limitations:
On operating systems other than mentioned above, when not compiling
with LDC this function is the same as `array[] = 0` and is not
protected from being removed by the compiler.
+/
void explicitZero(scope ubyte[] array) @nogc nothrow pure @trusted
{
    if (__ctfe)
    {
        array[] = 0;
        return;
    }
    version (LDC)
    {
        static if (is(typeof(llvm_memset(array.ptr, 0, array.length, true)))) // LLVM 7+
            llvm_memset(array.ptr, 0, array.length, true); // "true" prevents removal.
        else // Pre-LLVM 7
            llvm_memset(array.ptr, 0, array.length, ubyte.alignof, true);
    }
    else version (linux)
        explicit_bzero(array.ptr, array.length);
    else version (FreeBSD)
        explicit_bzero(array.ptr, array.length);
    else version (OpenBSD)
        explicit_bzero(array.ptr, array.length);
    else version (OSX)
        memset_s(array.ptr, array.length, 0, array.length);
    else
        array[] = 0;
}
