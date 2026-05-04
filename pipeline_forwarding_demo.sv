module pipeline_forwarding_demo #(
    parameter   DEPTH = 32,
    parameter   WIDTH = 16
) (
    input       clk,
    input       rstn,

    input   ivalid,     // 操作使能，
    input   [$clog2(DEPTH)-1:0] addr,
    input   [WIDTH-1:0] ins,

    output  ovalid,
    output  [WIDTH-1:0] data
);

    logic [WIDTH-1:0]   ins_p1;
    logic [$clog2(DEPTH)-1:0]   addr_p1,addr_p2;
    logic [WIDTH-1:0]   data_p1,data_p2;
    logic [WIDTH-1:0]   bp_data_p1;    // 因为无法直接修改ram的rdata而对wdata进行打拍
    logic [3:0] mux_sel_p0;
    logic [3:0] mux_sel_p1;
    logic [DEPTH-1:0]   addr_accessed;
    logic pipe_valid_p0,pipe_valid_p1,pipe_valid_p2;
    logic ram_wen,ram_ren;
    logic [$clog2(DEPTH)-1:0]   ram_waddr,ram_raddr;
    logic [WIDTH-1:0]   ram_wdata,ram_rdata;
    logic [DEPTH-1:0]   addr_accessed_set_mask;
    logic bypass1,bypass2;
    logic  addr_p0p2_eq;
    logic  addr_p0p1_eq;
    logic cur_access;

    assign pipe_valid_p0 = ivalid;

// ================ ram ================== //

    assign  ram_wen = pipe_valid_p2;
    assign  ram_waddr = addr_p2;
    assign  ram_wdata = data_p2;
    assign  ram_ren = pipe_valid_p0 && addr_accessed[addr] && ~(bypass1 | bypass2);   // ram的该地址已被初始化并且不需要bypass才用读ram
    assign  ram_raddr = addr;

    ram_2p #(DEPTH,WIDTH)   u_ram
    (
        .clk(clk),
        
        .wen(ram_wen),
        .waddr(ram_waddr),
        .wdata(ram_wdata),
        .ren(ram_ren),
        .raddr(ram_raddr),
        .rdata(ram_rdata)
    );

// =============== pipeline ============= //

    always_ff @( posedge clk ) begin
        if(~rstn) begin
            pipe_valid_p1 <= 1'b0;
            pipe_valid_p2 <= 1'b0;
        end
        else begin
            pipe_valid_p1 <= pipe_valid_p0;
            pipe_valid_p2 <= pipe_valid_p1;
        end
    end

    always_ff @( posedge clk ) begin 
        if(~rstn)
            addr_p1 <= {$clog2(DEPTH){1'b0}};
        else if(pipe_valid_p0)
            addr_p1 <= addr;
    end

    always_ff @(posedge clk) begin
        if(~rstn)
            addr_p2 <= {$clog2(DEPTH){1'b0}};
        else if(pipe_valid_p1)
            addr_p2 <= addr_p1;
    end

    always_ff @(posedge clk ) begin
        if(~rstn)
            bp_data_p1 <= {WIDTH{1'b0}};
        else if(pipe_valid_p0 && mux_sel_p0[3])  // 只有检测到raddr == waddr时才使用此bp_data
            bp_data_p1 <= ram_wdata;
    end

    always_ff @(posedge clk) begin
        if(~rstn)
            ins_p1 <= {WIDTH{1'b0}};
        else if(pipe_valid_p0)
            ins_p1 <= ins;
    end

    mux_one_hot #(4,WIDTH) u_mux (
        .mux_in({bp_data_p1,data_p2,ram_rdata,{WIDTH{1'b0}}}),
        .sel(mux_sel_p1),
        .mux_out(data_p1)
    );

    always_ff @(posedge clk) begin
        if(~rstn)
            data_p2 <= {WIDTH{1'b0}};
        else if(pipe_valid_p1)
            data_p2 <= data_p1 + ins_p1; 
    end

// ============ forwarding ============== //

    assign  addr_p0p2_eq = addr == addr_p2;
    assign  addr_p0p1_eq = addr == addr_p1;
    assign  bypass1 = addr_p0p1_eq && pipe_valid_p0 && pipe_valid_p1;
    assign  bypass2 = addr_p0p2_eq && pipe_valid_p0 && pipe_valid_p2;

    assign  mux_sel_p0[0] = ~addr_accessed[addr];   // ram的数据未初始化，无效为0
    assign  mux_sel_p0[1] = ~(bypass1 || bypass2) && addr_accessed[addr];     //  不做forwarding
    assign  mux_sel_p0[2] = bypass1;      // 当前请求和前面第1个请求做forwarding
    assign  mux_sel_p0[3] = bypass2 && ~bypass1;        // 当前请求和前面第2个请求做forwarding

    always_ff @(posedge clk) begin
        if(~rstn)
            mux_sel_p1 <= 4'd0;
        else if(pipe_valid_p0)
            mux_sel_p1 <= mux_sel_p0; 
    end

// ============ ram_accessed ============ //

    assign  addr_accessed_set_mask = 1 << addr;
    always_ff @(posedge clk ) begin
        if(~rstn)
            addr_accessed <= {DEPTH{1'b0}};
        else if(pipe_valid_p0 && ~addr_accessed[addr])     // 访问了未使用的才更新
            addr_accessed <= addr_accessed | addr_accessed_set_mask;
    end

// ============== output ================//

    assign  ovalid = pipe_valid_p2;
    assign  data = data_p2;

endmodule
