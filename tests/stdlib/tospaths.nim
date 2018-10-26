discard """
  file: "tospaths.nim"
  output: ""
"""
# test the ospaths module

import os

doAssert unixToNativePath("") == ""
doAssert unixToNativePath(".") == $CurDir
doAssert unixToNativePath("..") == $ParDir
doAssert isAbsolute(unixToNativePath("/"))
doAssert isAbsolute(unixToNativePath("/", "a"))
doAssert isAbsolute(unixToNativePath("/a"))
doAssert isAbsolute(unixToNativePath("/a", "a"))
doAssert isAbsolute(unixToNativePath("/a/b"))
doAssert isAbsolute(unixToNativePath("/a/b", "a"))
doAssert unixToNativePath("a/b") == joinPath("a", "b")

when defined(macos):
  doAssert unixToNativePath("./") == ":"
  doAssert unixToNativePath("./abc") == ":abc"
  doAssert unixToNativePath("../abc") == "::abc"
  doAssert unixToNativePath("../../abc") == ":::abc"
  doAssert unixToNativePath("/abc", "a") == "abc"
  doAssert unixToNativePath("/abc/def", "a") == "abc:def"
elif doslikeFileSystem:
  doAssert unixToNativePath("./") == ".\\"
  doAssert unixToNativePath("./abc") == ".\\abc"
  doAssert unixToNativePath("../abc") == "..\\abc"
  doAssert unixToNativePath("../../abc") == "..\\..\\abc"
  doAssert unixToNativePath("/abc", "a") == "a:\\abc"
  doAssert unixToNativePath("/abc/def", "a") == "a:\\abc\\def"
  doAssert unixToNativePath("/abc/def", "C").parentDir == "C:\\abc"
else:
  #Tests for unix
  doAssert unixToNativePath("./") == "./"
  doAssert unixToNativePath("./abc") == "./abc"
  doAssert unixToNativePath("../abc") == "../abc"
  doAssert unixToNativePath("../../abc") == "../../abc"
  doAssert unixToNativePath("/abc", "a") == "/abc"
  doAssert unixToNativePath("/abc/def", "a") == "/abc/def"
  doAssert unixToNativePath("/abc/def").parentDir == "/abc"

block extractFilenameTest:
  doAssert extractFilename("") == ""
  when defined(posix):
    doAssert extractFilename("foo/bar") == "bar"
    doAssert extractFilename("foo/bar.txt") == "bar.txt"
    doAssert extractFilename("foo/") == ""
    doAssert extractFilename("/") == ""
  when doslikeFileSystem:
    doAssert extractFilename(r"foo\bar") == "bar"
    doAssert extractFilename(r"foo\bar.txt") == "bar.txt"
    doAssert extractFilename(r"foo\") == ""
    doAssert extractFilename(r"C:\") == ""

block lastPathPartTest:
  doAssert lastPathPart("") == ""
  when defined(posix):
    doAssert lastPathPart("foo/bar.txt") == "bar.txt"
    doAssert lastPathPart("foo/") == "foo"
    doAssert lastPathPart("/") == ""
  when doslikeFileSystem:
    doAssert lastPathPart(r"foo\bar.txt") == "bar.txt"
    doAssert lastPathPart(r"foo\") == "foo"
