// File persistence requires native/LLVM; fail closed on other targets.
///|
fn ensure_directories(_path : String) -> Bool {
  false
}

///|
fn atomic_write(_path : String, _content : String, _replace : Bool) -> Int {
  2
}
