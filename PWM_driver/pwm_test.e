	cp	read_duty	0x80000000
	blt	within_range	read_duty	max
	cp	read_duty	max
within_range	mult	numhigh	numperiod	read_duty
	div	numhigh	numhigh	max
	cp	pwm_period	numperiod
	cp	pwm_high_left	numhigh
	mult	pwm_high_right	numhigh	.data -1
run	call	pwm_driver	pwm_ra
	halt

numperiod	5000
numhigh	0
max	10
read_duty	0
negone	-1

#include pwm_driver.e
