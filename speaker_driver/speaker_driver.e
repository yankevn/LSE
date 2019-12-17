set		cp		0x80000042		sample
		cp		0x80000040		one
		ret		set_ra

get		cp		ready			0x80000041
		be		not_ready		ready			zero
		cp		0x80000040		zero
not_ready	ret		get_ra


sample		0
ready		0

zero		0
one		1

set_ra		0
get_ra		0
