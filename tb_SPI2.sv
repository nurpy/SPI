
class transaction;


rand bit [31:0] msg;
rand bit [1:0] i_rst;
bit o_data_valid;


bit [31:0] msg_received;


constraint reset_to_packet {i_rst dist {0:=1, 1:=6, 2:=3};}
//constraint reset_to_packet {i_rst dist {0:=1, 1:=6};}

/*
          logic i_MOSI;
          logic i_CS; //UNSUSED
          logic i_SCLK;
          logic i_rst;
          logic i_MISO;
	  logic o_data_valid;
	  logic [31:0] o_reg_config;
	  logic [31:0] o_data;
*/




endclass










class generator;

transaction tr;
mailbox #(transaction) mbx;

int count = 0 ; 
int i = 0 ;

event next_transaction;
event done_simulation;


function new(mailbox #(transaction) mbx);
	this.mbx = mbx;
	tr=new();

endfunction;



task run();


	repeat(count)
	begin
		assert(tr.randomize) else $error("Transaction Randomization failed");
		i++;
		mbx.put(tr);
		
		$display("Generated Trnasaction %d ",i);
		@(next_transaction);
	end
	->done_simulation;
endtask;
endclass







class driver;


	transaction data;
	mailbox #(transaction) mbx;
	mailbox #(transaction) drvdone;
	virtual SPI_intf SPI_if; 

	event driving_done;


	function new(mailbox #(transaction) mbx,mailbox #(transaction) drvdone);
		this.mbx = mbx;
		this.drvdone = drvdone;
	endfunction;


	task startReset();

	endtask



	task toggle_clk();
		#10
		SPI_if.i_SCLK = ~SPI_if.i_SCLK;
		#10
		SPI_if.i_SCLK = ~SPI_if.i_SCLK;
	endtask
	//reset sequence
	task reset();
		@(posedge SPI_if.i_SCLK);
		SPI_if.i_rst=1'b1;	
		@(posedge SPI_if.i_SCLK);
		SPI_if.i_rst=1'b0;	
		@(posedge SPI_if.i_SCLK);
		for(int i = 31 ; i >= 0 ; i--)
		begin
			SPI_if.i_MOSI = data.msg[i];	
			@(posedge SPI_if.i_SCLK);
		end
	endtask

	//write sequence
	task write();
		@(posedge SPI_if.i_SCLK);
		for(int i = 31 ; i >= 0 ; i--)
		begin
			SPI_if.i_MOSI = data.msg[i];	
			@(posedge SPI_if.i_SCLK);
		end

	endtask

	task waitTime();
		#53
		$display("temp");
	endtask







	task run();
		forever begin
			mbx.get(data);
			if(data.i_rst == 2'd0) 
			begin
				$display("Driving Rst");
				reset();	
			end
			else if (data.i_rst == 2'd1)
			begin
				$display("Driving Write");
				write();	
			end
			else 
			begin
				$display("wait");
				waitTime();
			end
			drvdone.put(data);
			->driving_done;
		end
	endtask
endclass


class monitor;

	mailbox #(transaction) mbx;
	mailbox #(transaction) drvdone;
	transaction tr;
	virtual SPI_intf SPI_if; 
	event driving_done;

	function new( mailbox #(transaction) mbx,mailbox #(transaction) drvdone);
		this.mbx=mbx;
		this.drvdone=drvdone;
	endfunction

	task run();
		tr=new();

		forever begin
		    //mbx.get(tr);
		@(driving_done);
		drvdone.get(tr);
		@(posedge SPI_if.i_SCLK);
			
		@(posedge SPI_if.o_data_valid);
			if(tr.i_rst == 2'd0)
				tr.msg_received = SPI_if.o_reg_config; 
			if(tr.i_rst == 2'd1)
				tr.msg_received = SPI_if.o_data; 
		mbx.put(tr);
		end
	endtask



endclass



class scoreboard;

	mailbox #(transaction) mbx;
	transaction tr;
	
	event next;
	int error=0;

	function new( mailbox #(transaction) mbx);
		this.mbx=mbx;
	endfunction


	task check_reset();
		$display("Reset Check");
		$display("%d | %d",tr.msg,tr.msg_received);
		if(tr.msg == tr.msg_received)
		begin
			$display("Reset Succesful");
		end
		else  
		begin
			$display("Reset Failed");
			error++;
		end
	endtask

	task check_msg();
		$display("Write Check");
		$display("%d | %d",tr.msg,tr.msg_received);
		if(tr.msg == tr.msg_received)
		begin
			$display("Write Succesful");
		end
		else
		begin
			$display("Write Failed");
			error++;
		end
	endtask

	task run();
		forever begin
			mbx.get(tr);
		$display("Next");
			if(tr.i_rst == 2'd1)
			begin
				check_msg();
			end
			else if(tr.i_rst == 2'd0)
			begin
				check_reset();
			end
		$display("Next");
		->next;
		end
	endtask



endclass











class environment;
	generator gen;
	driver drv;

	monitor mon;
	scoreboard score;


	mailbox #(transaction) gendrv;
	mailbox #(transaction) monscore;
	mailbox #(transaction) drvmon;

	event next;
	event driving_done;

	virtual SPI_intf SPI_if;


	function new(virtual SPI_intf SPI_if);

		drvmon=new();
		gendrv=new();
		gen=new(gendrv);
		drv=new(gendrv,drvmon);

		monscore=new();
		//mon=new(gendrv);
		//score=new(gendrv);
		mon=new(monscore,drvmon);
		score=new(monscore);

		this.SPI_if = SPI_if;

		drv.SPI_if = this.SPI_if;
		mon.SPI_if = this.SPI_if;

		gen.next_transaction = next;
		score.next = next;
		drv.driving_done = driving_done;
		mon.driving_done = driving_done;
	endfunction


	task run();
		pre_test();
		test();
		post_test();
	endtask


	task pre_test();
		@(posedge SPI_if.i_SCLK);
		SPI_if.i_rst=1'b1;	
		@(posedge SPI_if.i_SCLK);
		SPI_if.i_rst=1'b0;	
		for(int i = 0 ; i < 32 ; i++)
		begin
			SPI_if.i_MOSI = 0;	
			@(posedge SPI_if.i_SCLK);
		end
		@(posedge SPI_if.o_data_valid);

	endtask

	task test();
	//run tests
	fork 
		gen.run();
		drv.run();
		mon.run();
		score.run();
	join_any
	endtask

	task post_test();
	wait(gen.done_simulation.triggered);
	$display("-------------------------");
	$display("Number of errors: %d", score.error);
	$display("-------------------------");


	if(score.error ==0) begin
		$display("\n");
		$display("            ██████╗  █████╗ ███████╗███████╗                ");
		$display("            ██╔══██╗██╔══██╗██╔════╝██╔════╝                ");
		$display("            ██████╔╝███████║███████╗███████╗                ");
		$display("            ██╔═══╝ ██╔══██║╚════██║╚════██║                ");
		$display("            ██║     ██║  ██║███████║███████║                ");
		$display("            ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝                ");
		$display("              ✅  T E S T   P A S S E D  ✅        ");
		$display("\n");
	end
	else begin
		$display("\n");
		$display("            ███████╗ █████╗ ██╗██╗                          ");
		$display("            ██╔════╝██╔══██╗██║██║                          ");
		$display("            █████╗  ███████║██║██║                          ");
		$display("            ██╔══╝  ██╔══██║██║██║                          ");
		$display("            ██║     ██║  ██║██║███████╗                     ");
		$display("            ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝                     ");
		$display("\n              ❌ TEST FAILED ❌       \n");
	end

	$finish();

	endtask


endclass


module tb;

		//inst dut

	SPI DUT(
		  .i_MOSI(SPI_if.i_MOSI),
		  .i_CS(SPI_if.i_CS), //UNSUSED
		  .i_SCLK(SPI_if.i_SCLK),
		  .i_rst(SPI_if.i_rst),
		  .i_MISO(SPI_if.i_MISO),
		  .o_data_valid(SPI_if.o_data_valid),
		  .o_reg_config(SPI_if.o_reg_config),
		  .o_data(SPI_if.o_data)
		  );

		//create interface
	SPI_intf SPI_if();



	always begin
		SPI_if.i_SCLK = ~SPI_if.i_SCLK;
		#10;
	end



		environment env;

		initial begin
			#50
			SPI_if.i_SCLK = 1'b0;
			$display("Sim Started");
			env = new(SPI_if);
			env.gen.count = 10;
			env.run();
		end

		initial begin
		$dumpfile("dump.vcd");
		$dumpvars;
		end


endmodule
