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
	output reg [17:0] LEDR
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
		.clock(CLOCK_50)
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
		input clock
	);
	localparam DIFFERENCE_THRESHOLD = 400;
	reg [3:0] loadLoc; //3 load, 0,1,2 shift, 4 display, 5 draw centroid
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

	reg [2:0] x_draw_centroid_counter = 0, y_draw_centroid_counter = 0;
	always @(posedge clock)
	begin
		if(loadLoc == 3)
		begin
			if (bdiff_read_x >= `IMAGE_W - 1 && bdiff_read_y >= `IMAGE_H - 1)
			begin
				if(diff_count < DIFFERENCE_THRESHOLD)
				begin
					loadLoc <= 4;
				end
				else
				begin
					y_average <= (y_average*14 + 2*y_total/diff_count)/16;
					x_average <= (x_average*14 + 2*x_total/diff_count)/16;
					loadLoc <= 5;
				end

				bdiff_read_y <= 1;
				bdiff_read_x <= 1;
				// bdiff_read_x <= bdiff_read_x +1;
				x_total <= 0;
				y_total <= 0;
				diff_count <= 0;
			end
			else if(bdiff_read_x >= `IMAGE_W - 1)
			begin
				bdiff_read_x <= 1;
				bdiff_read_y <= bdiff_read_y + 1;
				loadLoc <= 4;
				// LEDR[0] <= !LEDR[0];
			end
			else
			begin
				bdiff_read_x <= bdiff_read_x +1;
				loadLoc <= 4;
			end

			vga_plot <= 0;
			bdiff_rdaddress <= bdiff_read_y*`IMAGE_W + bdiff_read_x;

		end
		else if(loadLoc == 4)
		begin

			vga_plot <= 1;
			vga_x <= bdiff_read_x;
			vga_y <= bdiff_read_y;
			// vga_colour <= bdiff_data_out;
			if(enable_smoothing)
			begin
				if (row_curr[1] & row_above[0]
										  & row_above[1]
										  & row_above[2]
										  & row_below[0]
										  & row_below[1]
										  & row_below[2]
										  & row_curr[0]
										  & row_curr[2] )
				begin
					vga_colour <= 1;
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

			// checkColour <= !checkColour;
			bdiff_rdaddress <= bdiff_read_y*`IMAGE_W + bdiff_read_x;
			loadLoc <= 0;
		end

		else if (loadLoc == 5) begin
			vga_plot <= 1;
			if (x_draw_centroid_counter < 4 && vga_x <= `IMAGE_W) begin
				x_draw_centroid_counter <= x_draw_centroid_counter +1;
			end else begin
				x_draw_centroid_counter <= 0;
				if(y_draw_centroid_counter < 4 && vga_y <= `IMAGE_H)
					y_draw_centroid_counter <= y_draw_centroid_counter + 1;
				else begin
					y_draw_centroid_counter <= 0;
					x_draw_centroid_counter <= 0;
					loadLoc <= 0;
				end
			end
			vga_colour <= 1;
			vga_x <= x_average + x_draw_centroid_counter;
			vga_y <= y_average + y_draw_centroid_counter;
		end
		// if(SW[5])LEDR[0] <= 0;
		else
		begin
			vga_plot <= 0;

			if(loadLoc == 0)
			begin
				row_curr <= {row_curr[1:0], bdiff_data_out};
				loadLoc <= 1;
				bdiff_rdaddress <= bdiff_rdaddress - `IMAGE_W;
			end

			else if(loadLoc == 1)
			begin
				row_above <= {row_above[1:0], bdiff_data_out};
				loadLoc <= 2;
				bdiff_rdaddress <= bdiff_rdaddress + `IMAGE_W*2;
			end

			else if(loadLoc == 2)
			begin
				loadLoc <= 3;
				row_below <= {row_below[1:0], bdiff_data_out};

			end

		end

	end

endmodule