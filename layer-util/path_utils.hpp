/* Copyright (c) 2017-2024 Hans-Kristian Arntzen
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#pragma once
#include <string>
#include <utility>

namespace Path
{
/// Join base directory with a relative path
/// Example: join("/home/user", "file.txt") -> "/home/user/file.txt"
std::string join(const std::string &base, const std::string &path);

/// Get the directory component of a path
/// Example: basedir("/home/user/file.txt") -> "/home/user"
std::string basedir(const std::string &path);

/// Get the filename component of a path
/// Example: basename("/home/user/file.txt") -> "file.txt"
std::string basename(const std::string &path);

/// Split path into directory and filename components
/// Example: split("/home/user/file.txt") -> {"/home/user", "file.txt"}
std::pair<std::string, std::string> split(const std::string &path);

/// Convert an absolute path to a path relative to base directory
/// Example: relpath("/home/user", "/home/user/files/data.txt") -> "files/data.txt"
std::string relpath(const std::string &base, const std::string &path);

/// Get file extension from a path
/// Example: ext("/home/user/file.txt") -> ".txt"
std::string ext(const std::string &path);

/// Split path into protocol and path components
/// Example: protocol_split("file:///home/user") -> {"file", "/home/user"}
std::pair<std::string, std::string> protocol_split(const std::string &path);

/// Check if path is absolute (starts with / on Unix)
bool is_abspath(const std::string &path);

/// Check if path is root directory
bool is_root_path(const std::string &path);

/// Canonicalize path by removing . and .. components
/// Example: canonicalize_path("/home/./user/../user/file.txt") -> "/home/user/file.txt"
std::string canonicalize_path(const std::string &path);

/// Ensure path has protocol prefix if required
std::string enforce_protocol(const std::string &path);

/// Get absolute path of currently running executable
std::string get_executable_path();

#ifdef _WIN32
std::string to_utf8(const wchar_t *wstr, size_t len);
std::wstring to_utf16(const char *str, size_t len);
std::string to_utf8(const std::wstring &wstr);
std::wstring to_utf16(const std::string &str);
#endif
}