// Reading one line of g-code.
//
// Only what the machine actually uses: a letter and a number, then the words
// that follow. Comments run from a semicolon to the end of the line, or sit
// between brackets, and case does not matter. Like the geometry, this builds on
// a PC so it can be tested there.
#pragma once

#include <math.h>
#include <stdint.h>

namespace gc {

struct Line {
  char kind = 0;     // 'G', 'M', or 0 when the line carried no command
  int code = -1;     // the number after it
  bool empty = true; // nothing but blanks and comments

  bool has(char letter) const { return mask_ & maskOf(letter); }
  float get(char letter, float fallback = 0) const {
    return has(letter) ? word_[index(letter)] : fallback;
  }
  int getInt(char letter, int fallback = 0) const {
    return has(letter) ? (int)lroundf(word_[index(letter)]) : fallback;
  }
  void set(char letter, float value);

 private:
  static int index(char letter);
  // Not called `bit`: the Arduino headers already have a macro by that name.
  static uint32_t maskOf(char letter) { return 1u << index(letter); }
  float word_[26] = {0};
  uint32_t mask_ = 0;
};

// Parses in place from a null-terminated string. Returns false and sets `error`
// when the line is malformed; an empty or comment-only line parses fine and
// comes back with `empty` set.
bool parse(const char *text, Line &out, const char **error);

}  // namespace gc
