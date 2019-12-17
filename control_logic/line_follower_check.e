	//initialize midpoint
line_init	add	mid	right_edge	left_edge
	div	mid	mid	num2
	ret	line_init_ra

//BEGIN LINE CHECK FUNCTION
line_check	cp	sensor_data	0x80000110
	sub	error	sensor_data	mid
	div	proportion	error	k_p
	
	be	first	count	num0
	
	sub	error_change	error	last_error
	sub	dt	0x80000005	last_error_time
	div	error_change	error_change	dt
	cp	last_error	error
	cp	last_error_time	0x80000005		
	be	derivative	0	0

first	cp	last_error	error
	cp	last_error_time	0x80000005
	cp	error_change	num0

//derivative control commented out, need to adjust to use measured dt
derivative	div	error_change	error_change	k_d
	add	proportion	proportion	error_change		
	add	left	straight	proportion
	sub	right	straight	proportion

	blt	pos_left	num25	left
	blt	neg_left	left	neg25
	be	zero_left	0	0

pos_left	mult	left	left	num2
	div	left	left	num5
	add	left	left	num3000
	be	right_scale	0	0

zero_left	cp	left	zerolf
	be	right_scale	0	0

neg_left	mult	left	left	num2
	div	left	left	num5
	sub	left	left	num3000
	be	right_scale	0	0

right_scale	blt	pos_right	num25	right
	blt	neg_right	right	neg25
	be	zero_right	0	0

pos_right	mult	right	right	num2
	div	right	right	num5
	add	right	right	num3000
	be	assign	0	0

zero_right	cp	right	zerolf
	be	assign	0	0

neg_right	mult	right	right	num2
	div	right	right	num5
	sub	right	right	num3000
	be	assign	0	0

assign	cp	pwm_high_right	right
	cp	pwm_high_left	left
	ret	line_check_ra


