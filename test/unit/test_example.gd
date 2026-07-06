extends GutTest


func before_all():
	gut.p("Runs once before all tests")


func before_each():
	gut.p("Runs before each test.")


func after_each():
	gut.p("Runs after each test.")


func after_all():
	gut.p("Runs once after all tests")


func test_passes():
	# this test will pass because 1 does equal 1
	assert_eq(1, 1)
