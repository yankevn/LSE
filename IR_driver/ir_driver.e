start	cp	start_time	0x80000005
	sr	0x80000004	0x80000110	num16
	cp	0x80000003	0x80000110
checked	sub	lapsed	0x80000005	start_time
	blt	start	limit	lapsed
	be	checked	0	0

start_time	0
lapsed	0
limit	1000
num16	16
