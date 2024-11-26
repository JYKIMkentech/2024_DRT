clc; clear; close all;

%% 시드 설정
rng(1);

%% Font size settings
axisFontSize = 14;
titleFontSize = 16;
legendFontSize = 12;
labelFontSize = 14;

%% 1. 데이터 로드

% ECM 파라미터 (HPPC 테스트로부터)
load('optimized_params_struct_final_2RC.mat'); % 필드: R0, R1, C1, R2, C2, SOC, Crate

% DRT 파라미터 (gamma 및 tau 값)
load('theta_discrete.mat');
load('gamma_est_all.mat', 'gamma_est_all', 'SOC_mid_all');  % 수정된 부분: SOC_mid_all도 로드
load('R0_est_all.mat')

tau_discrete = exp(theta_discrete); % tau 값

% SOC-OCV 룩업 테이블 (C/20 테스트로부터)
load('soc_ocv.mat', 'soc_ocv'); % [SOC, OCV]
soc_values = soc_ocv(:, 1);     % SOC 값
ocv_values = soc_ocv(:, 2);     % 해당하는 OCV 값 [V]

% 주행 데이터 (17개의 트립)
load('udds_data.mat'); % 구조체 배열 'udds_data'로 V, I, t, Time_duration, SOC 필드 포함





