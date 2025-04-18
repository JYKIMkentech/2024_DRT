clear;clc;close all;

% CSV 파일을 table 형식으로 불러오기
data = readtable('G:\공유 드라이브\BSL_WC\Publishing_data_raw_data_cell_059.csv');

time = data.Test_Sec_;
voltage = data.Volts;
current = data.NormalizedCurrent_C_rate_;

figure;
yyaxis left
plot(time, voltage, 'b-');
ylabel('Voltage (V)');

yyaxis right
plot(time, current, 'r-');
ylabel('Current (C-rate)');

xlabel('Time (s)');
title('Voltage and Current vs. Time');

%xlim([0 1000000])
xlim([650000 880000]);