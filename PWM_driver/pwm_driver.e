// pwm_driver
// inputs: period, high
// outputs: none

pwm_driver	cp	0x800000f2	pwm_period
	cp	0x800000f3	pwm_high_left
	cp	0x800000f4	pwm_high_right
c_start	cp	0x800000f0	num1
r_start	be	c_end	0x800000f1	num1
	be	r_start	0	0
c_end	cp	0x800000f0	num0
r_end	be	pwm_end	0x800000f1	num0
	be	r_end	0	0
pwm_end	ret	pwm_ra

num0	0
num1	1
pwm_ra	0
pwm_period	0
pwm_high_left	0
pwm_high_right	0
