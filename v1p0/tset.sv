`timescale 1ps/1ps

module test;

reg signed [3:0] a;
reg [3:0] b;
reg [5:0] c;

initial begin
    a = 4'b1111; // -1, 15
    b = 4'b0010; // 2
    c = a >>> b; // -2
    $display("%b", c);
end

endmodule