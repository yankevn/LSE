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


camera_check

begin	call	cam_driver	cam_ra
	cp	vga_write	num0
	cp	x0	num0
	cp	y0	num0
	//write total to hexdigits
	cp	0x80000003	total
	cp	total	num0

loopx	cp	y0	num0

loopy	
	//read array here
run	call	vga_driver	vga_ra
	
	
	//green is in the middle 8 bits
	//right shift 8 bits
	//and with 8 1s or 255
	sr	green	color_read	num8
	and	green	green	num255

	sr	red	color_read	num16
	and	red	red	num255

	and	blue	color_read	num255
	
	//if color_read > 150, add 1 to total
	blt	write_black	green	green_min
	blt	write_black	red_max	red
	blt	write_black	blue_max	blue
	add	total	total	num1

	//writes white where an object is detected
	//can be viewed on the vga for debugging the camera
	cp	x2	x0
	add	x2	x2	num80
	cp	x1	x2
	cp	y2	y0
	cp	y1	y2
	cp	vga_write	num1
	cp	color_write	write_white
	call	vga_driver	vga_ra
	cp	vga_write	num0
	
	//go see if y has reached its max value
after	be	checky	0	0



	//checks if max x-value is reached
checkx	be	ret_vga	x0	num79
incx	add	x0	num1	x0
	be	loopx	0	0

	//checks if max y-value is reached
checky	be	checkx	y0	num59
incy	add	y0	num1	y0
	be	loopy	0	0


	//writes black to pixels that do not pass the thresholding
write_black
	cp	x2	x0
	add	x2	x2	num80
	cp	x1	x2
	cp	y2	y0
	cp	y1	y2
	cp	vga_write	num1
	cp	color_write	num0
	call	vga_driver	vga_ra
	cp	vga_write	num0
	be	after	0	0


//go back to main
ret_vga	ret	camera_check_ra

	

