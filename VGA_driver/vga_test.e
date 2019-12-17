//read-only vga
//BASED ON CAMERA SCALE 0: 80 x 60
//
//
//
//pseudocode:
//for(x = 0; x < 80; x++) {
//	for(y = 0; y < 60; y++) {
//		read from color_read
//	}
//}
//go back to beginning




begin	call	cam_driver	cam_ra
	cp	write	zero
	cp	x0	zero
	cp	y0	zero
	//write total to hexdigits
	cp	0x80000003	total
	cp	total	zero

loopx	cp	y0	zero

loopy	
	//read shit here
run	call	driver	callvga
	
	
	//green is in the middle 8 bits
	//right shift 8 bits
	//and with 8 1s or 255
	sr	green	color_read	eight
	and	green	green	twofives

	sr	red	color_read	sixteen
	and	red	red	twofives

	and	blue	color_read	twofives
	
	//if color_read > 150, add 1 to total
	blt	write_black	green	green_min
	blt	write_black	red_max	red
	blt	write_black	blue_max	blue
	add	total	total	one

	//write white = bigolboi
	cp	x2	x0
	add	x2	x2	eighty
	cp	x1	x2
	cp	y2	y0
	cp	y1	y2
	cp	write	one
	cp	color_write	bigolboi
	call	driver	callvga
	cp	write	zero

after	be	checky	0	0




checkx	be	begin	x0	sevennine
incx	add	x0	one	x0
	be	loopx	0	0


checky	be	checkx	y0	fivenine
incy	add	y0	one	y0
	be	loopy	0	0



write_black
	cp	x2	x0
	add	x2	x2	eighty
	cp	x1	x2
	cp	y2	y0
	cp	y1	y2
	cp	write	one
	cp	color_write	zero
	call	driver	callvga
	cp	write	zero
	be	after	0	0


	
//vga values
twofives	255
eight	8
sixteen	16
total	0
twoten	210
sevennine	79
eighty	80
fivenine	59

//cam values
scale	0
green	0
red	0
blue	0
green_min	20
green_max	100
red_max	20
red_min	0
blue_max	20
blue_min	0

bigolboi	16777215

#include vga_driver.e
#include cam_driver.e
