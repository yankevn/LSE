	cp	cam_x	numx
	cp	cam_y	numy
	cp	cam_scl	numscl
	cp	cam_mirr	nummirr
	call	cam_driver	cam_ra

x_max	be	dec_x	numx	w_max
x_min	be	inc_x	numx	zero
move_x	add	numx	numx	x_val
	cp	cam_x	numx
	be	y_max	0	0

y_max	be	dec_y	numy	h_max
y_min	be	inc_y	numy	zero
move_y	add	numy	numy	y_val
	cp	cam_y	numy
	call	cam_driver	cam_ra
	be	x_max	0	0

dec_x	cp	x_val	neg_one
	be	move_x	0	0
inc_x	cp	x_val	one
	be	move_x	0	0
dec_y	cp	y_val	neg_one
	be	move_y	0	0
inc_y	cp	y_val	one
	be	move_y	0	0

numx	0
numy	0
x_val	1
y_val	1
numscl	2
nummirr	0
min_ind	0
w_max	320
h_max	240
zero	0
one	1
neg_one	-1

#include cam_driver.e
