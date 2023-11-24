`timescale 1ps/1ps

module teset;

reg [3:0] a;

initial begin
    a = 1;
    $display("%b", a);
end

initial begin
    #10;
    $finish;
end

endmodule