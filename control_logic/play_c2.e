//plays the distorted C-note as part of the siren
play_c2		cp	notelength_reached	num0
		

loop_c2		cpfa	sample	array_c2	siren_index	//copy array[i] to sample
		call	set	set_ra		//set command
	

		


wait_c2		call	get	get_ra		//get response
		be	wait_c2	ready	num0	//repeat if response is zero
		add	siren_index	siren_index	inc8	//increment i

		//notelength_reached determines if notelength is reached
		add	notelength_reached	notelength_reached	inc1
		blt	end_c2	notelength	notelength_reached	//if i = notelength go to end
		blt	reset_loop_c2	array_size	siren_index		
		
		be	loop_c2	0	0	
		
end_c2		cp	siren_index	num0
		ret	note_ra


reset_loop_c2		cp	siren_index	num0		//reset i to zero
		be	loop_c2	0	0
	

		


