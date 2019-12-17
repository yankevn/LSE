//vga driver
//inputs: vga_write, x0. y0, x1, y1 (rectangle upper left corner), x2, y2 (rectangle lower right corner), color_vga_write
//outputs: color_read
//x1 and y1 must ALWAYS be <= x2 and y2

//if vga_write = 0, read from x0 and y0
//if vga_write = 1, vga_write to the rectangle denoted by (x1, y1) and (x2, y2)

vga_driver	cp	0x80000062	vga_write
	
	be	vga_write0	num0	vga_write
	be	vga_write1	num1	vga_write

vga_return	ret	vga_ra

	//reading phase (write = 0)
vga_write0	cp	0x80000063	x0
	cp	0x80000064	y0
	cp	0x80000060	num1

vga_resp0	be	vga_com_off0	0x80000061	num1
	be	vga_resp0	0	0

vga_com_off0	cp	color_read	0x80000068
	cp	0x80000060	num0

vga_res_off0	be	vga_return	0x80000061	num0
	be	vga_res_off0	0	0


	//writing phase (write = 1)
	//we use this primarily for debugging the thresholding
vga_write1	cp	0x80000063	x1
	cp	0x80000064	y1
	cp	0x80000065	x2
	cp	0x80000066	y2
	cp	0x80000067	color_write
	cp	0x80000060	num1

resp1	be	com_off1	0x80000061	num1
	be	resp1	0	0

com_off1	cp	0x80000060	num0

res_off1	be	vga_return	0x80000061	num0
	be	vga_res_off0	0	0







