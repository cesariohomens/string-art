// Reading a line of g-code. The job is written by a machine and read by a
// machine, but people type into the console too, so the odd cases matter.
#include <unity.h>

#include "gcode.cpp"

static gc::Line read(const char *text, bool expect_ok = true) {
  gc::Line g;
  const char *err = nullptr;
  bool ok = gc::parse(text, g, &err);
  TEST_ASSERT_EQUAL(expect_ok, ok);
  return g;
}

void test_a_plain_move(void) {
  gc::Line g = read("G1 A90 X120.5 Z6 F4200");
  TEST_ASSERT_EQUAL('G', g.kind);
  TEST_ASSERT_EQUAL(1, g.code);
  TEST_ASSERT_EQUAL_FLOAT(90, g.get('A'));
  TEST_ASSERT_EQUAL_FLOAT(120.5, g.get('X'));
  TEST_ASSERT_EQUAL_FLOAT(6, g.get('Z'));
  TEST_ASSERT_EQUAL_FLOAT(4200, g.get('F'));
  TEST_ASSERT_FALSE(g.has('Y'));
}

void test_case_and_spacing_do_not_matter(void) {
  gc::Line g = read("g1x10z2");
  TEST_ASSERT_EQUAL('G', g.kind);
  TEST_ASSERT_EQUAL(1, g.code);
  TEST_ASSERT_EQUAL_FLOAT(10, g.get('X'));
  TEST_ASSERT_EQUAL_FLOAT(2, g.get('Z'));
}

void test_comments_are_dropped(void) {
  gc::Line g = read("G1 X10 ; move in a bit");
  TEST_ASSERT_EQUAL_FLOAT(10, g.get('X'));

  g = read("(a whole line of nothing)");
  TEST_ASSERT_TRUE(g.empty);

  g = read("G1 (mid-line) X5");
  TEST_ASSERT_EQUAL_FLOAT(5, g.get('X'));
}

void test_an_empty_line_is_not_an_error(void) {
  gc::Line g = read("   \r\n");
  TEST_ASSERT_TRUE(g.empty);
  TEST_ASSERT_EQUAL(0, g.kind);
}

void test_a_bare_letter_stands_for_the_axis(void) {
  gc::Line g = read("G28 X Z");
  TEST_ASSERT_EQUAL(28, g.code);
  TEST_ASSERT_TRUE(g.has('X'));
  TEST_ASSERT_TRUE(g.has('Z'));
  TEST_ASSERT_FALSE(g.has('A'));
}

void test_negatives_and_decimals(void) {
  gc::Line g = read("G1 A-37.25 X0.5");
  TEST_ASSERT_EQUAL_FLOAT(-37.25, g.get('A'));
  TEST_ASSERT_EQUAL_FLOAT(0.5, g.get('X'));
}

void test_the_wrap_and_its_header(void) {
  gc::Line g = read("M700 P143");
  TEST_ASSERT_EQUAL('M', g.kind);
  TEST_ASSERT_EQUAL(700, g.code);
  TEST_ASSERT_EQUAL(143, g.getInt('P'));

  g = read("M701 R280.00 N288 H6.00 D3.00 O2.20 P0.00");
  TEST_ASSERT_EQUAL(701, g.code);
  TEST_ASSERT_EQUAL_FLOAT(280, g.get('R'));
  TEST_ASSERT_EQUAL(288, g.getInt('N'));
  TEST_ASSERT_EQUAL_FLOAT(2.2, g.get('O'));
}

void test_line_numbers_and_checksums_are_ignored(void) {
  gc::Line g = read("N42 G1 X10*71");
  TEST_ASSERT_EQUAL(1, g.code);
  TEST_ASSERT_EQUAL_FLOAT(10, g.get('X'));
  TEST_ASSERT_FALSE(g.has('N'));
}

void test_two_commands_on_one_line_are_refused(void) {
  gc::Line g;
  const char *err = nullptr;
  TEST_ASSERT_FALSE(gc::parse("G1 X10 M18", g, &err));
  TEST_ASSERT_NOT_NULL(err);
}

void test_rubbish_is_refused(void) {
  gc::Line g;
  const char *err = nullptr;
  TEST_ASSERT_FALSE(gc::parse("G1 X10 #nonsense", g, &err));
  TEST_ASSERT_NOT_NULL(err);
}

void test_a_missing_word_falls_back(void) {
  gc::Line g = read("G1 X10");
  TEST_ASSERT_EQUAL_FLOAT(6.5, g.get('Z', 6.5));
  TEST_ASSERT_EQUAL(-1, g.getInt('P', -1));
}

int main(int, char **) {
  UNITY_BEGIN();
  RUN_TEST(test_a_plain_move);
  RUN_TEST(test_case_and_spacing_do_not_matter);
  RUN_TEST(test_comments_are_dropped);
  RUN_TEST(test_an_empty_line_is_not_an_error);
  RUN_TEST(test_a_bare_letter_stands_for_the_axis);
  RUN_TEST(test_negatives_and_decimals);
  RUN_TEST(test_the_wrap_and_its_header);
  RUN_TEST(test_line_numbers_and_checksums_are_ignored);
  RUN_TEST(test_two_commands_on_one_line_are_refused);
  RUN_TEST(test_rubbish_is_refused);
  RUN_TEST(test_a_missing_word_falls_back);
  return UNITY_END();
}
