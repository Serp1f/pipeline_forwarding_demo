module tb_pipeline_forwarding_demo (
);

    parameter   DEPTH = 8;
    parameter   WIDTH = 16;

    logic   clk;
    logic   rstn;

    logic   ivalid;
    logic   [$clog2(DEPTH)-1:0] addr;
    logic   [WIDTH-1:0] ins;

    logic   ovalid;
    logic   [WIDTH-1:0] data;

    logic   [DEPTH-1:0][WIDTH-1:0]  test_mem={{WIDTH{1'b0}}};
    int test_queue[$];   // pipeline的结果有延迟，用队列保序

    always 
    #5  clk = ~clk;

    initial begin
        clk = 0;
        rstn = 0;
        ivalid = 0;
        addr = 0;
        ins = 0;
    #30 rstn = 1;
    end

    initial begin
    #50 @(posedge clk) #1;
    //     for(int i=0;i<DEPTH;i=i+1) begin
    //         write_in(i,i);
    //     end
    // $stop();
    #20 @(posedge clk) #1;
        for(int i=0;i<100;i=i+1) begin
            write_in($urandom() % DEPTH,$urandom());
            repeat($urandom() %3) begin
                @(posedge clk) #1;
            end
        end
    $stop();
    end

    pipeline_forwarding_demo #(DEPTH,WIDTH) u_pipe
    (
        .clk(clk),
        .rstn(rstn),

        .ivalid(ivalid),
        .addr(addr),
        .ins(ins),

        .ovalid(ovalid),
        .data(data)
        
    );


    task automatic write_in(
        input  [$clog2(DEPTH)-1:0]  wr_addr,
        input   [WIDTH-1:0] wr_ins
    );
    begin
        ivalid = 1;
        addr = wr_addr;
        ins = wr_ins;
        test_mem[wr_addr] = test_mem[wr_addr] + wr_ins;
        test_queue.push_back(test_mem[wr_addr]);
        @(posedge clk) #1;
        ivalid = 0;
        addr = 0;
        ins = 0;
    end
    endtask //automatic

    int qdata;
    always_ff @(posedge  clk) begin
        if(ovalid) begin
            qdata = test_queue.pop_front();
            if(qdata != data)
                $error(" wrong number, expect %d but given %d",qdata,data);
        end
    end

endmodule