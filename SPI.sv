
module SPI(
          input i_MOSI,
          input i_CS, //UNSUSED
          input i_SCLK,
          input i_rst,
          output i_MISO,
	  output o_data_valid,
	  output [31:0] o_reg_config,
	  output [31:0] o_data
          );

reg [31:0] reg_config_valid;
assign o_reg_config = reg_config_valid;
assign o_data = out_data; 
assign o_data_valid = valid_data;

reg [31:0] configReg;
reg [3:0] state;
reg [3:0] next_state;
reg [31:0] inData;
reg [6:0] size;
reg [6:0] next_size;

localparam CONFIG=4'd3;
localparam READ=4'd1;
localparam VALID=4'd2;

//Next state logic
always @(posedge i_SCLK or posedge i_rst) begin
	if(i_rst) begin
	next_size <= 0;
	end
	else begin
		case(state)
			CONFIG: begin
				if(next_size == 32) begin
					state <= VALID;
				end
				else begin
					state <= CONFIG;
				end
				
				 next_size <= next_size + 1;
			end
			READ: begin
				if(next_size == 32) begin
					state <= VALID;
				end
				else begin
					state <= READ;
				end
				 next_size <= next_size + 1;
			end
			VALID: begin
				 state <= READ;
				next_size <= 0;
			end
		endcase
	end

end

// state logic
always @(posedge i_SCLK or posedge i_rst) begin
	if(i_rst) begin
	state <= CONFIG;
	size <= 0;
	end
	else begin
	size <= next_size;
	end
end


reg [31:0] data;


reg [31:0] out_data;
reg valid_data;
//Read logic
always @(posedge i_SCLK or posedge i_rst) begin
	if(i_rst) begin
	data <= 0;
	valid_data <= 0;
	end
	else begin
		case(state)
			CONFIG:  begin
				configReg <= {configReg[30:0],i_MOSI};				
				valid_data <=0;
			end
			READ:  begin
				data <= {data[30:0],i_MOSI};
				valid_data <= 0;
			end
			VALID: begin
				out_data <= data;
				valid_data <= 1;
				reg_config_valid <= configReg;
			end
				
		endcase

	end
end




endmodule

interface SPI_intf;
          logic i_MOSI;
          logic i_CS; //UNSUSED
          logic i_SCLK;
          logic i_rst;
          logic i_MISO;
	  logic o_data_valid;
	  logic [31:0] o_reg_config;
	  logic [31:0] o_data;
endinterface
