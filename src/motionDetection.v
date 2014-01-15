`define X_WIDTH 9
`define Y_WIDTH 8
`define IMAGE_H 240
`define IMAGE_W 320
`define COLOUR_WIDTH 3

module motionDetection(
	input           CLOCK_50,               //  On Board 50 MHz
	input           CLOCK_27,

	input   [3:0]   KEY,

	output          VGA_CLK,                //  VGA Clock
	output          VGA_HS,                 //  VGA H_SYNC
	output          VGA_VS,                 //  VGA V_SYNC
	output          VGA_BLANK,              //  VGA BLANK
	output          VGA_SYNC,               //  VGA SYNC
	output  [9:0]   VGA_R,                  //  VGA Red[9:0]
	output  [9:0]   VGA_G,                  //  VGA Green[9:0]
	output  [9:0]   VGA_B,                  //  VGA Blue[9:0]

	input   [7:0]   TD_DATA,                //  TV Decoder Data bus 8 bits
	input           TD_HS,                  //  TV Decoder H_SYNC
	input           TD_VS,                  //  TV Decoder V_SYNC
	output          TD_RESET,               //  TV Decoder Reset

	output          I2C_SCLK,
	inout           I2C_SDAT,
	input [17:0]SW,
	output [17:0] LEDR
	);



	wire pixelIn_en;
	wire [4:0] pixelIn_r, pixelIn_b;
	wire [5:0] pixelIn_g;
	wire [2:0] pixelIn_colour = {pixelIn_r[4], pixelIn_g[5], pixelIn_b[4]};
	wire [8:0] pixelIn_x;
	wire [7:0] pixelIn_y;

	wire vga_plot;
	wire [8:0] vga_x;
	wire [7:0] vga_y;

	wire vga_colour;
	reg enableClock;

	assign LEDR[5] = 1;

	Video_In vin(
		.CLOCK_50       (CLOCK_50),
		.CLOCK_27       (CLOCK_27),
		.TD_RESET       (TD_RESET),
		.reset          (~KEY[0]),

		.TD_DATA        (TD_DATA),
		.TD_HS          (TD_HS),
		.TD_VS          (TD_VS),

		.waitrequest    (0),

		.x              (pixelIn_x),
		.y              (pixelIn_y),
		.red            (pixelIn_r),
		.green          (pixelIn_g),
		.blue           (pixelIn_b),
		.pixel_en       (pixelIn_en)
	);

	avconf avc(
		.I2C_SCLK       (I2C_SCLK),
		.I2C_SDAT       (I2C_SDAT),
		.CLOCK_50       (CLOCK_50),
		.reset          (~KEY[0])
	);

	vga_adapter VGA(
				.resetn(KEY[0]),
				.clock(CLOCK_50),
				// .colour({pixelIn_r[4], pixelIn_g[5], pixelIn_b[4]}),
				.colour(vga_colour),
				// .colour(prev_image_data_out[displayChanel]),
				// .colour(prev_image_data_in[displayChanel]),
				.x(vga_x),
				.y(vga_y),
				.plot(vga_plot),
				.VGA_R(VGA_R),
				.VGA_G(VGA_G),
				.VGA_B(VGA_B),
				.VGA_HS(VGA_HS),
				.VGA_VS(VGA_VS),
				.VGA_BLANK(VGA_BLANK),
				.VGA_SYNC(VGA_SYNC),
				.VGA_CLK(VGA_CLK)
	);
			defparam VGA.RESOLUTION = "320x240";
			defparam VGA.MONOCHROME = "TRUE";
			defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;


	wire [2:0]  prev_image_data_in;
	wire [16:0] prev_image_rdaddress;
	wire [16:0] prev_image_wraddress;
	wire        prev_image_wr_en;
	wire [2:0]  prev_image_data_out;

	prev_image_ram prev_image(
		.data(prev_image_data_in),
		.rdaddress(prev_image_rdaddress),
		.rdclock(CLOCK_50),
		.wraddress(prev_image_wraddress),
		.wrclock(CLOCK_50),
		.wren(prev_image_wr_en),
		.q(prev_image_data_out)
	);

	wire        bdiff_data_in;
	wire [16:0] bdiff_rdaddress;
	wire [16:0] bdiff_wraddress;
	wire        bdiff_wr_en;
	wire        bdiff_data_out;

	bdiff_image bdi(
		.data(bdiff_data_in),
		.rdaddress(bdiff_rdaddress),
		.rdclock(CLOCK_50),
		.wraddress(bdiff_wraddress),
		.wrclock(CLOCK_50),
		.wren(bdiff_wr_en),
		.q(bdiff_data_out)
	);

	difference_engine de(
		.clock(CLOCK_50),

		.pixelIn_en(pixelIn_en),
		.pixelIn_colour(pixelIn_colour),
		.pixelIn_x(pixelIn_x),
		.pixelIn_y(pixelIn_y),

		.displayChanel(SW[1:0]),
		.enable_diff(SW[2]),

		.prev_image_data_in(prev_image_data_in),
		.prev_image_wraddress(prev_image_wraddress),
		.prev_image_wr_en(prev_image_wr_en),
		.prev_image_rdaddress(prev_image_rdaddress),
		.prev_image_data_out(prev_image_data_out),

		.bdiff_data_in(bdiff_data_in),
		.bdiff_wraddress(bdiff_wraddress),
		.bdiff_wr_en(bdiff_wr_en)
	);

	display disp(
		.vga_plot(vga_plot),
		.vga_colour(vga_colour),
		.vga_x(vga_x),
		.vga_y(vga_y),
		.bdiff_rdaddress(bdiff_rdaddress),
		.bdiff_data_out(bdiff_data_out),
		.enable_smoothing(SW[3]),
		.show_history(SW[4]),
		.clock(CLOCK_50),
		.vga_vsync(VGA_VS),
		.state_out(LEDR[4:0])
	);

endmodule


module difference_engine (
		input clock,

		input pixelIn_en,
		input [`COLOUR_WIDTH-1:0] pixelIn_colour,
		input [`X_WIDTH-1:0] pixelIn_x,
		input [`Y_WIDTH-1:0] pixelIn_y,

		input [1:0] displayChanel,
		input enable_diff,

		output reg [2:0]  prev_image_data_in,
		output reg [16:0] prev_image_wraddress,
		output reg        prev_image_wr_en,
		output reg [16:0] prev_image_rdaddress,
		input      [2:0]  prev_image_data_out,

		output reg	       bdiff_data_in,
		output reg	[16:0] bdiff_wraddress,
		output reg	       bdiff_wr_en
	);

always @(posedge clock)
	begin
		prev_image_data_in <= pixelIn_colour;

		prev_image_wraddress <= prev_image_rdaddress;
		prev_image_rdaddress <= pixelIn_y*`IMAGE_W + pixelIn_x;
		bdiff_wraddress <= pixelIn_y*`IMAGE_W + pixelIn_x;

		if(pixelIn_en)
		begin
			bdiff_wr_en <= 1;
			prev_image_wr_en <=1;
			if(enable_diff)
			begin
				if(prev_image_data_out != pixelIn_colour) begin
					bdiff_data_in <= 1;
				end
				else
				begin
					bdiff_data_in <= 0;
				end
			end
			else
			begin
				bdiff_data_in <= prev_image_data_out[displayChanel];
			end
		end
		else
		begin
			bdiff_wr_en <= 0;
			prev_image_wr_en <= 0;
		end
	end
endmodule

module display (
		output reg vga_plot,
		output reg vga_colour,
		output reg [`X_WIDTH-1:0] vga_x,
		output reg [`Y_WIDTH-1:0] vga_y,
		output reg [16:0] bdiff_rdaddress,
		input bdiff_data_out,
		input enable_smoothing,
		input show_history,
		input clock,
		input vga_vsync,
		output [4:0]state_out
	);
	localparam STATE_WAIT_FOR_FRAME     = 0;
	localparam STATE_LOAD_CURRENT 	    = 1;
	localparam STATE_LOAD_BELOW 	    = 2;
	localparam STATE_LOAD_ABOVE 	    = 3;
	localparam STATE_UPDATE_INDICES     = 4;
	localparam STATE_DISPLAY 		    = 5;
	localparam STATE_CALCULATE_CENTROID = 6;
	localparam STATE_DRAW_CENTROID 	    = 7;
	localparam STATE_DRAW_HIST          = 8;

	localparam DIFFERENCE_THRESHOLD = 400;

	localparam HISTORY_DIM_DIVISOR = 4; // be sure to update the LOG2 version
	localparam LOG2_HISTORY_DIM_DIVISOR = 2; // = log_2(HISTORY_DIM_DIVISOR)
	localparam CENTROID_IMAGE_DIM = 8;


	assign state_out[4:0] = draw_state;
	reg [4:0] draw_state;
	reg [2:0] row_above;
	reg [2:0] row_curr;
	reg [2:0] row_below;

	reg [8:0] bdiff_read_x;
	reg [7:0] bdiff_read_y;

	reg checkColour;
	reg [23:0] x_total;
	reg [23:0] y_total;
	reg [16:0] diff_count;
	reg [`X_WIDTH-1:0] x_average;
	reg [`Y_WIDTH-1:0] y_average;

	wire [`X_WIDTH-1:0] new_centroid_x;
	wire [`Y_WIDTH-1:0] new_centroid_y;
	wire done_calculating_centroid;

	calculate_centroid cc(
		.clock_in(clock),
		.enable(draw_state == STATE_CALCULATE_CENTROID),
		.total_x(x_total),
		.total_y(y_total),
		.diff_count(diff_count),
		.centroid_x(new_centroid_x),
		.centroid_y(new_centroid_y),
		.done(done_calculating_centroid)
	);

	wire [3:0] x_draw_centroid_offset;
	wire [3:0] y_draw_centroid_offset;
	wire draw_centroid_colour_out;
	wire done_drawing_centroid;

	draw_centroid dc (
		.clock(clock),
		.enable(draw_state == STATE_DRAW_CENTROID),
		.output_x(x_draw_centroid_offset),
		.output_y(y_draw_centroid_offset),
		.colour_out(draw_centroid_colour_out),
		.done(done_drawing_centroid)
	);
	defparam dc.CENTROID_IMAGE_DIM = CENTROID_IMAGE_DIM;

	wire [`X_WIDTH-1:0] hist_x_offset;
	wire [`Y_WIDTH-1:0] hist_y_offset;
	wire hist_done;

	draw_history dh(
		.clock(clock),
		.enable(draw_state == STATE_DRAW_HIST),
		.centroid_in_x(x_average),
		.centroid_in_y(y_average),
		.offset_x(hist_x_offset),
		.offset_y(hist_y_offset),
		.done(hist_done)
	);
	defparam dh.LOG2_HISTORY_DIM_DIVISOR = LOG2_HISTORY_DIM_DIVISOR;

	reg [`X_WIDTH*2-1:0] x_hold;
	reg [`Y_WIDTH*2-1:0] y_hold;

	reg set_row_address;

	always @(posedge clock)
	begin
		if(draw_state == STATE_WAIT_FOR_FRAME) begin
			vga_plot <= 0;
			if (!vga_vsync) begin
				draw_state <= STATE_UPDATE_INDICES;
			end
		end
		else if(draw_state == STATE_UPDATE_INDICES)
		begin
			if (bdiff_read_x >= `IMAGE_W - 2 && bdiff_read_y >= `IMAGE_H - 2)
			begin
				if(diff_count < DIFFERENCE_THRESHOLD)
				begin
					draw_state <= STATE_DISPLAY;
					x_total <= 0;
					y_total <= 0;
					diff_count <= 0;
				end
				else
				begin
					draw_state <= STATE_CALCULATE_CENTROID;
				end

				bdiff_read_y <= 0;
				bdiff_read_x <= 0;
			end
			else if(bdiff_read_x >= `IMAGE_W - 1)
			begin
				bdiff_read_x <= 0;
				bdiff_read_y <= bdiff_read_y + 1;
				draw_state <= STATE_DISPLAY;
			end
			else
			begin
				bdiff_read_x <= bdiff_read_x +1;
				draw_state <= STATE_DISPLAY;
			end

			vga_plot <= 0;

		end
		else if(draw_state == STATE_DISPLAY)
		begin

			//prevent drawing over the centroid
			if(!enable_smoothing || (
				  (x_hold[`X_WIDTH*2-1:`X_WIDTH] < x_average
				|| x_hold[`X_WIDTH*2-1:`X_WIDTH] >= x_average + CENTROID_IMAGE_DIM)

				|| (y_hold[`Y_WIDTH*2-1:`Y_WIDTH] < y_average
				|| y_hold[`Y_WIDTH*2-1:`Y_WIDTH] >= y_average + CENTROID_IMAGE_DIM))
			) begin
				// if not smoothings
				vga_plot <= 1;
			end

			vga_x <= x_hold[`X_WIDTH*2-1:`X_WIDTH];
			vga_y <= y_hold[`Y_WIDTH*2-1:`Y_WIDTH];

			x_hold <= {x_hold[`X_WIDTH-1:0],bdiff_read_x};
			y_hold <= {y_hold[`Y_WIDTH-1:0],bdiff_read_y};


			if(enable_smoothing)
			begin
				if((x_hold[`X_WIDTH*2 - 1:`X_WIDTH] == (`IMAGE_W - `IMAGE_W/HISTORY_DIM_DIVISOR + 1)
				 || y_hold[`Y_WIDTH*2 - 1:`Y_WIDTH] ==  `IMAGE_H - `IMAGE_H/HISTORY_DIM_DIVISOR + 1) &&
					show_history && x_hold[`X_WIDTH*2 - 1:`X_WIDTH] > (`IMAGE_W - `IMAGE_W/HISTORY_DIM_DIVISOR)
								 && y_hold[`Y_WIDTH*2 - 1:`Y_WIDTH] >  `IMAGE_H - `IMAGE_H/HISTORY_DIM_DIVISOR) begin
					vga_colour <= 1;
				end
				else if ( row_above[0] & row_above[1] & row_above[2]
						&  row_curr[0] &  row_curr[1] &  row_curr[2]
						& row_below[0] & row_below[1] & row_below[2]) begin

					if (show_history && x_hold[`X_WIDTH*2 - 1:`X_WIDTH] > (`IMAGE_W - `IMAGE_W/HISTORY_DIM_DIVISOR)
									 && y_hold[`Y_WIDTH*2 - 1:`Y_WIDTH] >  `IMAGE_H - `IMAGE_H/HISTORY_DIM_DIVISOR) begin
							vga_colour <= 0;
					end
					else begin
						vga_colour <= 1;
					end

					diff_count <= diff_count + 1;
					x_total <= x_total + vga_x;
					y_total <= y_total + vga_y;
				end
				else vga_colour <=0;
			end
			else
			begin
				vga_colour <= row_curr[1];
			end

			draw_state <= STATE_LOAD_CURRENT;
		end
		else if (draw_state == STATE_CALCULATE_CENTROID) begin
			if(done_calculating_centroid) begin
				draw_state <= STATE_DRAW_CENTROID;
				x_average <= new_centroid_x;
				y_average <= new_centroid_y;
				x_total <= 0;
				y_total <= 0;
				diff_count <= 0;
			end
		end
		else if (draw_state == STATE_DRAW_CENTROID) begin

			vga_plot <= 1;

			if (done_drawing_centroid) begin
				if (show_history) begin
					draw_state <= STATE_DRAW_HIST;
				end else begin
					draw_state <= STATE_WAIT_FOR_FRAME;
				end
			end

			vga_x <= x_average + x_draw_centroid_offset;
			vga_y <= y_average + y_draw_centroid_offset;

			vga_colour <= draw_centroid_colour_out;

		end
		else if (draw_state == STATE_DRAW_HIST) begin

			vga_plot <= 1;

			if(hist_done) draw_state <= STATE_WAIT_FOR_FRAME;

			vga_x <= `IMAGE_W - (`IMAGE_W/HISTORY_DIM_DIVISOR) + hist_x_offset;
			vga_y <= `IMAGE_H - (`IMAGE_H/HISTORY_DIM_DIVISOR) + hist_y_offset;

			vga_colour <= 1;

		end
		else
		begin
			vga_plot <= 0;

			if(draw_state == STATE_LOAD_CURRENT)
			begin
				if (!set_row_address) begin
					bdiff_rdaddress <= bdiff_read_y*`IMAGE_W + bdiff_read_x;
					set_row_address <= 1;
				end else begin
					row_curr <= {row_curr[1:0], bdiff_data_out};
					draw_state <= STATE_LOAD_BELOW;
					set_row_address <= 0;
				end
			end

			else if(draw_state == STATE_LOAD_BELOW)
			begin
				if (!set_row_address) begin
					bdiff_rdaddress <= bdiff_rdaddress + `IMAGE_W*2 ;
					set_row_address <= 1;
				end else begin
					row_below <= {row_below[1:0], bdiff_data_out};
					draw_state <= STATE_LOAD_ABOVE;
					set_row_address <= 0;
				end
			end

			else if(draw_state == STATE_LOAD_ABOVE)
			begin
				if (!set_row_address) begin
					bdiff_rdaddress <= bdiff_rdaddress - `IMAGE_W + 1;
					set_row_address <= 1;
				end else begin
					row_above <= {row_above[1:0], bdiff_data_out};
					draw_state <= STATE_UPDATE_INDICES;
					set_row_address <= 0;
				end
			end
		end
	end
endmodule

/*
 * Works at a slower clock, and calculates the centroid.
 */
module calculate_centroid (
	input clock_in,
	input enable,
	input [23:0] total_x,
	input [23:0] total_y,
	input [16:0] diff_count,
	output reg [`X_WIDTH-1:0] centroid_x,
	output reg [`Y_WIDTH-1:0] centroid_y,
	output reg done
	);

	wire slow_clock;

	quarter_speed_clock qsc(
		.clock_in(clock_in),
		.clock_out(slow_clock)
	);

	always @(posedge slow_clock) begin
		if (enable) begin

			centroid_y <= (centroid_y*10 + 6*total_y/diff_count)/16;
			centroid_x <= (centroid_x*10 + 6*total_x/diff_count)/16;
			done <= 1;

		end else begin
			done <= 0;
		end
	end

 endmodule

module quarter_speed_clock(input clock_in, output reg clock_out);

	reg [1:0]clockCount;

	always @(posedge clock_in) begin
		clockCount <= clockCount + 1;

		if(clockCount[1] & clockCount[0]) begin
			clock_out <= !clock_out;
		end
	end

endmodule


/*
 * Reads a square icon from a ROM, and outputs the offset and colour.
 */
module draw_centroid (
	input clock,
	input enable,
	output reg [3:0] output_x,
	output reg [3:0] output_y,
	output reg colour_out,
	output reg done
	);

	parameter CENTROID_IMAGE_DIM;

	reg	[5:0] image_rom_rdaddress;
	wire      image_rom_data_out;

	reg [7:0] x_hold;
	reg [7:0] y_hold;
	reg [3:0] x_offset;
	reg [3:0] y_offset;

	centroid_target_image_rom ctim(
		.address(image_rom_rdaddress),
		.clock(clock),
		.q(image_rom_data_out)
	);

	always @(posedge clock) begin
		if(enable) begin
			if (x_offset < CENTROID_IMAGE_DIM - 1) begin
				done <= 0;
				x_offset <= x_offset + 1;
				image_rom_rdaddress <= image_rom_rdaddress + 1;
			end else begin
				if(y_offset < CENTROID_IMAGE_DIM - 1) begin
					done <= 0;
					x_offset <= 0;
					y_offset <= y_offset + 1;
					image_rom_rdaddress <= image_rom_rdaddress + 1;
				end else begin
					y_offset <= 0;
					x_offset <= 0;
					done <= 1;
					image_rom_rdaddress <= 0;
				end
			end
			output_x <= x_hold[7:4];
			output_y <= y_hold[7:4];

			// offset the position output, to make it line up with the colour output,
			// as there is a 3 clock cycle delay between request and retreival
			x_hold <= {x_hold[3:0],x_offset};
			y_hold <= {y_hold[3:0],y_offset};

			colour_out <= image_rom_data_out;
			// colour_out <= 1;
		end
	end
endmodule

/*
 * Saves a NUM_HISTORY_POINTS of previous, scaled down, centroids,
 * and outputs them as offsets from some orgin, one at a time.
 */
module draw_history(
	input clock,
	input enable,
	input [`X_WIDTH-1:0] centroid_in_x,
	input [`Y_WIDTH-1:0] centroid_in_y,
	output reg [X_OFFSET_WIDTH-1:0] offset_x,
	output reg [Y_OFFSET_WIDTH-1:0] offset_y,
	output reg done
	);

	localparam NUM_HISTORY_POINTS = 20;// be sure to update the conuter size.
	localparam HISTORY_POINTS_COUNTER_SIZE = 5;//needs to hold NUM_HISTORY_POINTS + 1

	parameter LOG2_HISTORY_DIM_DIVISOR;
	localparam X_OFFSET_WIDTH = `X_WIDTH - LOG2_HISTORY_DIM_DIVISOR;
	localparam Y_OFFSET_WIDTH = `Y_WIDTH - LOG2_HISTORY_DIM_DIVISOR;

	// the old centroids
	reg [X_OFFSET_WIDTH*NUM_HISTORY_POINTS - 1:0] old_xes;
	reg [Y_OFFSET_WIDTH*NUM_HISTORY_POINTS - 1:0] old_ys;
	// the state conuter
	reg [HISTORY_POINTS_COUNTER_SIZE-1:0] counter;

	// first shift in the new centroid (divided by 2^LOG2_HISTORY_DIM_DIVISOR)
	// then on the next NUM_HISTORY_POINTS clocks, display each of the saved centroids.
	always @(posedge clock) begin
		if (enable) begin
			if (counter == NUM_HISTORY_POINTS+1) begin
				counter <= 0;
				done <= 1;
			end else begin
				done <= 0;
				if (counter == 0) begin
					old_xes <= old_xes<<X_OFFSET_WIDTH;
					old_xes [X_OFFSET_WIDTH-1:0] <= centroid_in_x>>2;
					 old_ys <= old_ys<<Y_OFFSET_WIDTH;
					 old_ys [Y_OFFSET_WIDTH-1:0] <= centroid_in_y>>2;
				end else begin
					// read an (X|Y)_OFFSET_WIDTH number of bits from each shift register
					offset_x <= old_xes[X_OFFSET_WIDTH*(counter-1) +:X_OFFSET_WIDTH];
					offset_y <=  old_ys[Y_OFFSET_WIDTH*(counter-1) +:Y_OFFSET_WIDTH];
				end
				counter <= counter + 1;
			end
		end
	end

endmodule