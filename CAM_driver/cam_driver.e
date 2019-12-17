// cam_driver
// inputs: x, y coords, scale, mirror
// outputs: none

cam_driver	cp	0x800000b2	cam_x
	cp	0x800000b3	cam_y
	cp	0x800000b4	cam_scl
	cp	0x800000b5	cam_mirr
c_start	cp	0x800000b0	num1
r_start	be	c_end	0x800000b1	num1
	be	r_start	0	0
c_end	cp	0x800000b0	num0
r_end	be	cam_end	0x800000b1	num0
	be	r_end	0	0
cam_end	ret	cam_ra

num0	0
num1	1
cam_ra	0
cam_x	0
cam_y	0
cam_scl	0
cam_mirr	0

