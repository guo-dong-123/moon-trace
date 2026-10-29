///|
#borrow(path)
extern "C" fn mkdirs_native(path : Bytes) -> Int = "moontrace_mkdirs"

///|
#borrow(path, temp, content)
extern "C" fn write_atomic_native(
  path : Bytes,
  temp : Bytes,
  content : Bytes,
  size : Int,
  replace : Int,
) -> Int = "moontrace_write_atomic"

///|
fn ensure_directories(path : String) -> Bool {
  mkdirs_native(@utf8.encode(path) + b"\x00") == 0
}

// 0: committed, 1: target already exists, 2: I/O failure.

///|
fn atomic_write(path : String, content : String, replace : Bool) -> Int {
  let nonce = match @env.rand(16) {
    Some(bytes) => @hex.encode(bytes)
    None => return 2
  }
  let bytes = @utf8.encode(content)
  write_atomic_native(
    @utf8.encode(path) + b"\x00",
    @utf8.encode(path + ".tmp-" + nonce) + b"\x00",
    bytes,
    bytes.length(),
    if replace {
      1
    } else {
      0
    },
  )
}
