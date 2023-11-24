module test;

reg [3:0] a;
reg signed [3:0] b;
reg [3:0] c;

initial begin
    a = 4'b1101;
    b = 4'b0010;
    c = a >>> b;
    $display("%b", c);
end

endmodule