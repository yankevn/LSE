//LSE MAIN DRIVER
//Set initial motor conditions
	cp	pwm_period	num5000
	call	line_init	line_init_ra

//Check environment
main	call	line_check	line_check_ra
	call	pwm_driver	pwm_ra
	sr	0x80000004	0x80000110	num16
	cp	0x80000003	0x80000110

// Delay for PWM
	call	delay	delay_ra

	call	camera_check	camera_check_ra
	blt	detected	max_camera	total	
	be	main	0	0

//loop until total < max_camera
detected	cp	pwm_high_right	num0
	cp	pwm_high_left	num0
	call	pwm_driver	pwm_ra
	call	siren_begin	siren_ra

// Delay for PWM
	call	delay	delay_ra

	call	camera_check	camera_check_ra
	blt	main	total	max_camera
	be	detected	0	0

//delay function
delay	cp	start_time	0x80000005
checked	sub	elapsed	0x80000005	start_time
	blt	next	limit	elapsed
	be	checked	0	0
next	ret	delay_ra


#include LSE_main_var_names.e
#include line_follower_check.e
#include pwm_driver.e
#include camera_check.e
#include cam_driver.e
#include vga_driver.e
#include siren_and_wait.e
#include speaker_driver.e
