#include "gcode.h"

#include <math.h>
#include <stdlib.h>

namespace gc {

int Line::index(char letter) {
  if (letter >= 'a' && letter <= 'z') letter = (char)(letter - 'a' + 'A');
  int i = letter - 'A';
  return (i < 0 || i > 25) ? 0 : i;
}

void Line::set(char letter, float value) {
  word_[index(letter)] = value;
  mask_ |= maskOf(letter);
  empty = false;
}

static bool isSpace(char c) { return c == ' ' || c == '\t' || c == '\r' || c == '\n'; }

bool parse(const char *text, Line &out, const char **error) {
  out = Line();
  if (error) *error = nullptr;
  if (!text) return true;

  int depth = 0, words = 0;
  for (const char *p = text; *p; p++) {
    if (*p == ';') break;
    if (*p == '(') { depth++; continue; }
    if (*p == ')') { if (depth) depth--; continue; }
    if (depth || isSpace(*p)) continue;

    char letter = *p;
    if (!((letter >= 'A' && letter <= 'Z') || (letter >= 'a' && letter <= 'z'))) {
      // A stray checksum or line number is not worth failing a job over, but
      // anything else means the line is not what it claims to be.
      if (letter == '*') break;
      if (error) *error = "unexpected character";
      return false;
    }

    char *end = nullptr;
    float value = strtof(p + 1, &end);
    if (end == p + 1) {
      // A bare letter is only meaningful where it stands for the axis itself,
      // as in `G28 X`, and there it reads as zero.
      out.set(letter, 0);
      continue;
    }
    p = end - 1;

    if (letter == 'G' || letter == 'g' || letter == 'M' || letter == 'm') {
      if (out.kind) {
        if (error) *error = "two commands on one line";
        return false;
      }
      out.kind = (letter == 'g' || letter == 'G') ? 'G' : 'M';
      out.code = (int)lroundf(value);
      out.empty = false;
      words++;
      continue;
    }
    // A leading N is a line number and means nothing here. Anywhere else it is
    // a word like any other, which is how `M701 N288` counts its nails.
    if ((letter == 'N' || letter == 'n') && words == 0) { words++; continue; }
    out.set(letter, value);
    words++;
  }
  return true;
}

}  // namespace gc
