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
#include <sstream>
#include <vector>
#include <type_traits>

namespace inner
{
/// Helper function for variadic template string joining (base case - single argument)
template<typename T>
void join_helper(std::ostringstream &stream, T &&t)
{
	stream << std::forward<T>(t);
}

/// Helper function for variadic template string joining (recursive case)
template<typename T, typename... Ts>
void join_helper(std::ostringstream &stream, T &&t, Ts &&... ts)
{
	stream << std::forward<T>(t);
	join_helper(stream, std::forward<Ts>(ts)...);
}
}

namespace Util
{
/// Variadic template function to join multiple arguments into a single string
/// Example: join("Hello", " ", 42, "!") -> "Hello 42!"
/// @param ts Arguments to concatenate (supports any type with operator<<)
/// @return Concatenated string result
template<typename... Ts>
inline std::string join(Ts &&... ts)
{
	std::ostringstream stream;
	inner::join_helper(stream, std::forward<Ts>(ts)...);
	return stream.str();
}

/// Split string by delimiter, including empty tokens
/// Example: split("a,b,,c", ",") -> {"a", "b", "", "c"}
/// @param str String to split
/// @param delim Delimiter character(s) to split on
/// @return Vector of substrings
std::vector<std::string> split(const std::string &str, const char *delim);

/// Split string by delimiter, excluding empty tokens
/// Example: split_no_empty("a,b,,c", ",") -> {"a", "b", "c"}
/// @param str String to split
/// @param delim Delimiter character(s) to split on
/// @return Vector of non-empty substrings
std::vector<std::string> split_no_empty(const std::string &str, const char *delim);

/// Remove leading and trailing whitespace from string
/// Example: strip_whitespace("  hello world  ") -> "hello world"
/// @param str String to strip
/// @return String with whitespace removed from both ends
std::string strip_whitespace(const std::string &str);
}
