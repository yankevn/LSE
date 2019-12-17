//plays the distorted A-note as part of the siren
play_a		cp	notelength_reached	num0
		

loop_a		cpfa	sample	array_a	siren_index	//copy array[i] to sample
		call	set	set_ra		//set command
	

		


wait_a		call	get	get_ra		//get response
		be	wait_a	ready	num0	//repeat if response is zero
		add	siren_index	siren_index	inc1	//increment i
		
		//notelength_reached determines if notelength is reached
		add	notelength_reached	notelength_reached	inc1
		blt	end_a	notelength	notelength_reached	//if i = notelength go to end
		blt	reset_loop_a	array_size	siren_index		
		
		be	loop_a	0	0	
		
end_a		cp	siren_index	num0
		ret	note_ra


reset_loop_a		cp	siren_index	num0		//reset i to zero
		be	loop_a	0	0
	


		

