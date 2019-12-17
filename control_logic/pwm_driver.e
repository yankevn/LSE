// pwm_driver
// inputs: period, high
// outputs: none

pwm_driver	cp	0x800000f2	pwm_period
	cp	0x800000f3	pwm_high_right
	cp	0x800000f4	pwm_high_left
	cp	0x800000f0	num1
re_start	be	co_end	0x800000f1	num1
	be	re_start	0	0
co_end	cp	0x800000f0	num0
re_end	be	pwm_end	0x800000f1	num0
	be	re_end	0	0
pwm_end	ret	pwm_ra



