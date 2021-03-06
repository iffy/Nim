#
#
#            Nim's Runtime Library
#        (c) Copyright 2019 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

##[
  The ``std/monotimes`` module implements monotonic timestamps. A monotonic
  timestamp represents the time that has passed since some system defined
  point in time. The monotonic timestamps are guaranteed to always increase,
  meaning that that the following is guaranteed to work:

  .. code-block:: nim
    let a = getMonoTime()
    # ... do some work
    let b = getMonoTime()
    assert a <= b

  This is not guaranteed for the `times.Time` type! This means that the
  `MonoTime` should be used when measuring durations of time with
  high precision.

  However, since `MonoTime` represents the time that has passed since some
  unknown time origin, it cannot be converted to a human readable timestamp.
  If this is required, the `times.Time` type should be used instead.

  The `MonoTime` type stores the timestamp in nanosecond resolution, but note
  that the actual supported time resolution differs for different systems.

  See also
  ========
  * `times module <times.html>`_
]##

import times

type
  MonoTime* = object ## Represents a monotonic timestamp.
    ticks: int64

when defined(macosx):
  type
    MachTimebaseInfoData {.pure, final, importc: "mach_timebase_info_data_t",
        header: "<mach/mach_time.h>".} = object
      numer, denom: int32

  proc mach_absolute_time(): int64 {.importc, header: "<mach/mach.h>".}
  proc mach_timebase_info(info: var MachTimebaseInfoData) {.importc,
    header: "<mach/mach_time.h>".}

  let machAbsoluteTimeFreq = block:
    var freq: MachTimebaseInfoData
    mach_timebase_info(freq)
    freq

when defined(js):
  proc getJsTicks: float =
    {.emit: """
      var isNode = typeof module !== 'undefined' && module.exports

      if (isNode) {
        var process = require('process');
        var time = process.hrtime()
        return time[0] + time[1] / 1000000000;
      } else {
        return window.performance.now() * 1000000;
      }
    """.}

  # Workaround for #6752.
  {.push overflowChecks: off.}
  proc `-`(a, b: int64): int64 =
    system.`-`(a, b)
  proc `+`(a, b: int64): int64 =
    system.`+`(a, b)
  {.pop.}

elif defined(posix):
  import posix

elif defined(windows):
  proc QueryPerformanceCounter(res: var uint64) {.
    importc: "QueryPerformanceCounter", stdcall, dynlib: "kernel32".}
  proc QueryPerformanceFrequency(res: var uint64) {.
    importc: "QueryPerformanceFrequency", stdcall, dynlib: "kernel32".}

  let queryPerformanceCounterFreq = block:
    var freq: uint64
    QueryPerformanceFrequency(freq)
    1_000_000_000'u64 div freq

proc getMonoTime*(): MonoTime {.tags: [TimeEffect].} =
  ## Get the current `MonoTime` timestamp.
  ##
  ## When compiled with the JS backend and executed in a browser,
  ## this proc calls `window.performance.now()`, which is not supported by
  ## older browsers. See [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Performance/now)
  ## for more information.
  when defined(JS):
    let ticks = getJsTicks()
    result = MonoTime(ticks: (ticks * 1_000_000_000).int64)
  elif defined(macosx):
    let ticks = mach_absolute_time()
    result = MonoTime(ticks: ticks * machAbsoluteTimeFreq.numer div
      machAbsoluteTimeFreq.denom)
  elif defined(posix):
    var ts: Timespec
    discard clock_gettime(CLOCK_MONOTONIC, ts)
    result = MonoTime(ticks: ts.tv_sec.int64 * 1_000_000_000 +
      ts.tv_nsec.int64)
  elif defined(windows):
    var ticks: uint64
    QueryPerformanceCounter(ticks)
    result = MonoTime(ticks: (ticks * queryPerformanceCounterFreq).int64)

proc ticks*(t: MonoTime): int64 =
  ## Returns the raw ticks value from a `MonoTime`. This value always uses
  ## nanosecond time resolution.
  t.ticks

proc `$`*(t: MonoTime): string =
  $t.ticks

proc `-`*(a, b: MonoTime): Duration =
  ## Returns the difference between two `MonoTime` timestamps as a `Duration`.
  initDuration(nanoseconds = (a.ticks - b.ticks))

proc `+`*(a: MonoTime, b: Duration): MonoTime =
  ## Increases `a` by `b`.
  MonoTime(ticks: a.ticks + b.inNanoseconds)

proc `-`*(a: MonoTime, b: Duration): MonoTime =
  ## Reduces `a` by `b`.
  MonoTime(ticks: a.ticks - b.inNanoseconds)

proc `<`*(a, b: MonoTime): bool =
  ## Returns true if `a` happened before `b`.
  a.ticks < b.ticks

proc `<=`*(a, b: MonoTime): bool =
  ## Returns true if `a` happened before `b` or if they happened simultaneous.
  a.ticks <= b.ticks

proc `==`*(a, b: MonoTime): bool =
  ## Returns true if `a` and `b` happened simultaneous.
  a.ticks == b.ticks

proc high*(typ: typedesc[MonoTime]): MonoTime =
  ## Returns the highest representable `MonoTime`.
  MonoTime(ticks: high(int64))

proc low*(typ: typedesc[MonoTime]): MonoTime =
  ## Returns the lowest representable `MonoTime`.
  MonoTime(ticks: low(int64))

when isMainModule:
  let d = initDuration(nanoseconds = 10)
  let t1 = getMonoTime()
  let t2 = t1 + d

  doAssert t2 - t1 == d
  doAssert t1 == t1
  doAssert t1 != t2
  doAssert t2 - d == t1
  doAssert t1 < t2
  doAssert t1 <= t2
  doAssert t1 <= t1
  doAssert not(t2 < t1)
  doAssert t1 < high(MonoTime)
  doAssert low(MonoTime) < t1