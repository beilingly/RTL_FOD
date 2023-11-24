// task for simplify calc
task veractor_pro_x_xt;
    // pro [N,N] = x [N,1] * xt [1,N]
    input en;
    input real x [0:`Nx-1];
    output real pro [0:`Nx*`Nx-1];

    integer i, j;

    if (en) begin
        for (i=0; i<`Nx; i=i+1) begin
            for (j=0; j<`Nx; j=j+1) begin
                pro[i*`Nx+j] = x[i] * x[j];
            end
        end
    end else begin
        for (i=0; i<`Nx; i=i+1) begin
            for (j=0; j<`Nx; j=j+1) begin
                pro[i*`Nx+j] = 0;
            end
        end
    end
endtask

task veractor_pro_xt_y;
    // pro = xt [1,N] * y [N,1]
    input en;
    input real x [0:`Nx-1];
    input real y [0:`Nx-1];
    output real pro;

    integer i;

    if (en) begin
        pro = 0;
        for (i=0; i<`Nx; i=i+1) begin
            pro = pro + x[i] * y[i];
        end
    end else begin
        pro = 0;
    end
endtask

task veractor_pro_a_x;
    // pro = a * x [N,1]
    input en;
    input real a;
    input real x [0:`Nx-1];
    output real pro [0:`Nx-1];

    integer i;

    if (en) begin
        for (i=0; i<`Nx; i=i+1) begin
            pro[i] = a * x[i];
        end
    end else begin
        for (i=0; i<`Nx; i=i+1) begin
            pro[i] = 0;
        end
    end
endtask

task veractor_sum_x1_x2;
    // add [N,1] = x1 [N,1] + x2 [N,1]
    input en;
    input real x1 [0:`Nx-1];
    input real x2 [0:`Nx-1];
    output real sum [0:`Nx-1];

    integer i;

    if (en) begin
        for (i=0; i<`Nx; i=i+1) begin
            sum[i] = x1[i] + x2[i];
        end
    end else begin
        for (i=0; i<`Nx; i=i+1) begin
            sum[i] = 0;
        end
    end
endtask

task mat_pro_x_mat;
    // pro [N,N] = x * mat [N,N]
    input en;
    input real x;
    input real mat [0:`Nx*`Nx-1];
    output real pro [0:`Nx*`Nx-1];

    integer i;

    if (en) begin
        for (i=0; i<`Nx*`Nx; i=i+1) begin
            pro[i] = x * mat[i];
        end
    end else begin
        for (i=0; i<`Nx*`Nx; i=i+1) begin
            pro[i] = 0;
        end
    end
endtask

task mat_sum_m1_m2;
    // add [N,N] = m1 [N,N] + m2 [N,N]
    input en;
    input real m1 [0:`Nx*`Nx-1];
    input real m2 [0:`Nx*`Nx-1];
    output real sum [0:`Nx*`Nx-1];

    integer i;

    if (en) begin
        for (i=0; i<`Nx*`Nx; i=i+1) begin
            sum[i] = m1[i] + m2[i];
        end
    end else begin
        for (i=0; i<`Nx*`Nx; i=i+1) begin
            sum[i] = 0;
        end
    end
endtask

task veractor_absmax_x;
    // x[max_pi] = max(abs(x [N,1]))
    // max_pm = x[max_pi]
    input en;
    input real x [0:`Nx-1];
    output integer max_pi;
    output real max_pm;

    real x_abs;
    integer i;

    if (en) begin 
        max_pi = 0;
        max_pm = x[max_pi];
        for (i=0; i<`Nx; i=i+1) begin
            // abs
            if (x[i] < 0) begin
                x_abs = -x[i];
            end else begin
                x_abs = x[i];
            end
            // find the larger one
            if (x_abs > max_pm) begin
                max_pm = x_abs;
                max_pi = i;
            end
        end
    end else begin
        max_pi = 0;
        max_pm = 0;
    end
endtask

function real sign;
    input real x;
    
    if (x>0)
        sign = 1;
    else
        sign = -1;
endfunction