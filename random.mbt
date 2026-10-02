///|
/// A reproducible pseudo-random source backed by MoonBit core's ChaCha8 engine.
pub struct RandomSource {
  priv generator : @random.Rand
}

///|
/// Creates a random source from a non-negative integer seed.
pub fn RandomSource::new(seed : Int) -> Result[RandomSource, String] {
  if seed < 0 {
    Err("random seed must be non-negative")
  } else {
    Ok(RandomSource::{
      generator: @random.Rand::chacha8(seed=expand_seed(seed)),
    })
  }
}

///|
/// Returns a non-negative 31-bit integer.
pub fn RandomSource::next_int(self : RandomSource) -> Int {
  self.generator.int()
}

///|
/// Returns an unbiased integer in `[0, limit)`.
pub fn RandomSource::int_below(
  self : RandomSource,
  limit : Int,
) -> Result[Int, String] {
  if limit <= 0 {
    Err("random integer limit must be positive")
  } else {
    Ok(self.generator.int(limit~))
  }
}

///|
/// Returns a Double in `[0.0, 1.0)`.
pub fn RandomSource::next_double(self : RandomSource) -> Double {
  self.generator.double()
}

///|
fn expand_seed(seed : Int) -> Bytes {
  let mut state = seed.to_uint64()
  let bytes : Array[Byte] = Array(capacity=32)
  let mut block = 0
  while block < 4 {
    state += 0x9e3779b97f4a7c15UL
    let mut word = mix64(state)
    let mut offset = 0
    while offset < 8 {
      bytes.push((word & 0xffUL).to_uint().to_byte())
      word = word >> 8
      offset += 1
    }
    block += 1
  }
  Bytes::from_array(bytes)
}

///|
fn mix64(value : UInt64) -> UInt64 {
  let mixed1 = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9UL
  let mixed2 = (mixed1 ^ (mixed1 >> 27)) * 0x94d049bb133111ebUL
  mixed2 ^ (mixed2 >> 31)
}
