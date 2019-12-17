set		cp		0x80000042		sample
		cp		0x80000040		num1
		ret		set_ra

get		cp		ready			0x80000041
		be		not_ready		ready			num0
		cp		0x80000040		num0
not_ready	ret		get_ra


