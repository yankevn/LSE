//vga driver
//inputs: write, x0. y0, x1, y1 (rectangle upper left corner), x2, y2 (rectangle lower right corner), color_write
//outputs: color_read
//x1 and y1 must ALWAYS be <= x2 and y2

//if write = 0, read from x0 and y0
//if write = 1, write to the rectangle denoted by (x1, y1) and (x2, y2)

driver	cp	0x80000062	write
	
	be	write0	zero	write
	be	write1	one	write

return	ret	callvga

write0	cp	0x80000063	x0
	cp	0x80000064	y0
	cp	0x80000060	one

resp0	be	com_off0	0x80000061	one
	be	resp0	0	0

com_off0	cp	color_read	0x80000068
	cp	0x80000060	zero

res_off0	be	return	0x80000061	zero
	be	res_off0	0	0



write1	cp	0x80000063	x1
	cp	0x80000064	y1
	cp	0x80000065	x2
	cp	0x80000066	y2
	cp	0x80000067	color_write
	cp	0x80000060	one

resp1	be	com_off1	0x80000061	one
	be	resp1	0	0

com_off1	cp	0x80000060	zero

res_off1	be	return	0x80000061	zero
	be	res_off0	0	0






write	0
x0	0
y0	0
x1	0
y1	0
x2	0
y2	0
color_write	0
zero	0
one	1
color_read	0
callvga	0
