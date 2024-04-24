clear;
clc;

% 说明
% .\RTL用于存放待综合verilog
% .\PINARRANGE存放中间生成规则pin信息文件、输出pin_arrangement文件
% fname verilog文件名
% 规则pin信息文件内容
% 'portname', 'p_dir', 'w1', 'w2', 'offset0'/6, 'pitch'/1, 'm_lev'/3,
% 'offset0'表示初始位置，后续端口若为0表示延续上一个端口的位置
% 'width'/0.3, 'depth'/0.31, 'side' /1 for input, 3 for output
% w1/w2端口bit数信息 port [w1:w2] portname;
% p_dir (+/-1)：多bit端口排列顺序，+1 offset由小到大pin端口自w1到w2排列，反之自w2到w1排列
% 确认修改规则pin信息文件后继续执行程序，生成最终的pin_arrangement文件

% dir define
fdir = 'D:\Project\MFOD\RTL\v2p0\synthesis\synth';
fname = 'DTCDCDER';

% open file
fprintf('*************************************TEXT LOAD IN************************************************\n');
fp = fopen([fdir '\RTL\' fname '.v'], 'rt');

% read text
tline = fgetl(fp);
list_cell = {tline};

while ischar(tline)
    disp(tline);
    tline = fgetl(fp);
    list_cell = [list_cell; tline];
end

% lose file
fclose(fp);
fprintf('*************************************TEXT LOAD IN DONE**********************************************\n');


% recognize port
fprintf('*************************************PORT DEFINE**********************************************\n');
input_num = 0;
output_num = 0;
input_list = {};
input_width = [];
output_list = {};
output_width = [];

for i = 1:length(list_cell)
    % input port
    if strfind(list_cell{i}, 'input')==1
        disp(list_cell{i});
        input_num = input_num + 1;
        ind0 = strfind(list_cell{i}, 'input');
        ind0 = ind0(1);
        ind00 = strfind(list_cell{i}(ind0:end), 'reg');
        if length(ind00)
            ind0 = ind0 + 4;
        end
        ind00 = strfind(list_cell{i}(ind0:end), 'wire');
        if length(ind00)
            ind0 = ind0 + 5;
        end
        ind1 = strfind(list_cell{i}, '[');
        ind2 = strfind(list_cell{i}, ':');
        ind3 = strfind(list_cell{i}, ']');
        ind4 = strfind(list_cell{i}, ';');
        ind4 = ind4(1);
        if length(ind1)&&length(ind2)&&length(ind3)
            ind1 = ind1(1);
            ind2 = ind2(1);
            ind3 = ind3(1);
            if (ind1<ind2)&&(ind2<ind3)&&(ind3<ind4)
                input_list = [input_list strtrim(list_cell{i}(ind3+1:ind4-1))];
                w1 = str2num(strtrim(list_cell{i}(ind1+1:ind2-1)));
                w2 = str2num(strtrim(list_cell{i}(ind2+1:ind3-1)));
                input_width = [input_width [w1; w2]];
            else
                fprintf('ERROR!!! --INPUT PORT-- check the declatation of port width\n');
            end
        else
            input_list = [input_list strtrim(list_cell{i}(ind0+6:ind4-1))];
            input_width = [input_width [0;0]];
        end
    end
    % output port
    if strfind(list_cell{i}, 'output')==1
        disp(list_cell{i});
        output_num = output_num + 1;
        ind0 = strfind(list_cell{i}, 'output');
        ind0 = ind0(1);
        ind00 = strfind(list_cell{i}(ind0:end), 'reg');
        if length(ind00)
            ind0 = ind0 + 4;
        end
        ind00 = strfind(list_cell{i}(ind0:end), 'wire');
        if length(ind00)
            ind0 = ind0 + 5;
        end
        ind1 = strfind(list_cell{i}, '[');
        ind2 = strfind(list_cell{i}, ':');
        ind3 = strfind(list_cell{i}, ']');
        ind4 = strfind(list_cell{i}, ';');
        ind4 = ind4(1);
        if length(ind1)&&length(ind2)&&length(ind3)
            ind1 = ind1(1);
            ind2 = ind2(1);
            ind3 = ind3(1);
            if (ind1<ind2)&&(ind2<ind3)&&(ind3<ind4)
                output_list = [output_list strtrim(list_cell{i}(ind3+1:ind4-1))];
                w1 = str2num(strtrim(list_cell{i}(ind1+1:ind2-1)));
                w2 = str2num(strtrim(list_cell{i}(ind2+1:ind3-1)));
                output_width = [output_width [w1; w2]];
            else
                fprintf('ERROR!!! --OUTPUT PORT-- check the declatation of port width\n');
            end
        else
            output_list = [output_list strtrim(list_cell{i}(ind0+6:ind4-1))];
            output_width = [output_width [0;0]];
        end
    end
end

% write format port define file
foname = [fdir '\PINARRANGE\' fname '_formatpin' '.xlsx'];

fcell = {'portname', 'p_dir', 'w1', 'w2', 'offset0', 'pitch', 'm_lev', 'width', 'depth', 'side'};
for i = 1:length(input_list)
    fcell = [fcell; [input_list(i), {'1'}, {num2str(input_width(1,i))} {num2str(input_width(2,i))} {'6'} {'1'} {'3'} {'0.3'} {'0.31'} {'1'}]];
end

for i = 1:length(output_list)
    fcell = [fcell; [output_list(i), {'1'}, {num2str(output_width(1,i))} {num2str(output_width(2,i))} {'6'} {'1'} {'3'} {'0.3'} {'0.31'} {'3'}]];
end

xlswrite(foname, fcell, 1, 'A1');

% arrange pin date, wait for correct format pin file
a = input('check format file done?');

pin_data = readcell(foname);

text_line = [];
offset = 0;
offset1 = 0;
offset2 = 0;
offset3 = 0;
offset4 = 0;
for i = 2:size(pin_data, 1)
    portname = pin_data{i, 1};
    p_dir = pin_data{i, 2};
    w1 = pin_data{i, 3};
    w2 = pin_data{i, 4};
    offset0 = pin_data{i, 5};
    pitch = pin_data{i, 6};
    m_lev = pin_data{i, 7};
    width = pin_data{i, 8};
    depth = pin_data{i, 9};
    side = pin_data{i, 10};

    if p_dir > 0
        portbit = w1;
    else
        portbit = w2;
    end
    
    % arrangement sentence for a single port
    for j = 1: abs(w1-w2)+1
        % decide side
        % side 1
        if side==1
            if (offset0 ~= 0) && (j == 1)
                offset1 = offset0;
            else
                offset1 = offset1 + pitch;
            end
            offset = offset1;
        end
        % side 2
        if side==2
            if (offset0 ~= 0) && (j == 1)
                offset2 = offset0;
            else
                offset2 = offset2 + pitch;
            end
            offset = offset2;
        end
        % side 3
        if side==3
            if (offset0 ~= 0) && (j == 1)
                offset3 = offset0;
            else
                offset3 = offset3 + pitch;
            end
            offset = offset3;
        end
        % side 4
        if side==4
            if (offset0 ~= 0) && (j == 1)
                offset4 = offset0;
            else
                offset4 = offset4 + pitch;
            end
            offset = offset4;
        end
        
        if w1==w2
            % 1 bit width
            text_line = [text_line 'set_pin_physical_constraints -pin_name {' portname '}' ' -offset ' num2str(offset) ' -layers {M' num2str(m_lev) '} -width ' num2str(width) ' -depth ' num2str(depth) ' -side ' num2str(side) '\n'];
        else
            % multi-bit width
            text_line = [text_line 'set_pin_physical_constraints -pin_name {' portname '[' num2str(portbit) ']}' ' -offset ' num2str(offset) ' -layers {M' num2str(m_lev) '} -width ' num2str(width) ' -depth ' num2str(depth) ' -side ' num2str(side) '\n'];
        end
        
        % update port bit
        portbit = portbit - p_dir;
    end
end

% generate pin arrangement file
fpname = [fdir '\PINARRANGE\' 'Pin_arrangement_' fname '.tcl'];
fp = fopen(fpname, 'wt');
fprintf(fp, text_line);
fclose(fp);
