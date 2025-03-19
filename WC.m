clear;clc;close all;

% CSV 파일을 table 형식으로 불러오기
data = readtable('G:\공유 드라이브\BSL_WC\Publishing_data_raw_data_cell_031.csv');

% 불러온 데이터의 앞부분 확인
head(data)

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
