clear; clc; close all;

%% 1) 데이터 로드
load('G:\공유 드라이브\BSL_Data4\HNE_agedcell_2025_processed\Driving_parsed\NE_Driving_fresh_4_1.mat'); % 전체 주행 부하 
% → parsed_data : 1×352 struct

load('G:\공유 드라이브\BSL_Data4\HNE_agedcell_2025_processed\SIM_parsed\NE_Driving_fresh_4_1_SIM.mat '); % 전체 주행 부하 중 LOAD 만 따로 뺀 데이터

%% 2) 필드별로 세로(행) 방향으로 붙이기
all_time    = vertcat(parsed_data.time);     %  [∑Ni × 1]  시간
all_voltage = vertcat(parsed_data.voltage);  %  [∑Ni × 1]  전압
all_current = vertcat(parsed_data.current);  %  [∑Ni × 1]  전류
% 각 서브-벡터가 column-vector(ni×1)라면 길이가 달라도 문제없이 붙습니다.

%% 3) 통합 그래프 그리기 (전압-전류 2-축 예시)
figure('Color','w');
yyaxis left
plot(all_time, all_voltage, '-', 'LineWidth', 1);
ylabel('Voltage (V)');

yyaxis right
plot(all_time, all_current, '-', 'LineWidth', 1);
ylabel('Current (A)');

xlabel('Time (s)');
title('Entire Driving Data');
grid on
