clc; clear; close all;

% 폰트 크기 및 선 굵기 설정
axisFontSize = 14;      % 축의 숫자 크기
titleFontSize = 16;     % 제목의 폰트 크기
legendFontSize = 12;    % 범례의 폰트 크기
labelFontSize = 14;     % xlabel 및 ylabel의 폰트 크기
lineWidth = 3.0;        % 선 굵기

% Color matrix 설정
c_mat = lines();

% 실험 데이터 로드
% data = load('C:\Users\USER\Desktop\Panasonic 18650PF Data\Panasonic 18650PF Data\25degC\5 pulse disch\03-11-17_08.47 25degC_5Pulse_HPPC_Pan18650PF.mat');
data = load('G:\공유 드라이브\BSL_Data3\HPPC\03-11-17_08.47 25degC_5Pulse_HPPC_Pan18650PF.mat');

% 시간, 전압, 전류 데이터 추출
time = data.meas.Time;
voltage = data.meas.Voltage;
current = data.meas.Current;

data1.I = current;
data1.V = voltage;
data1.t = time;

% 전류 상태 구분
data1.type = char(zeros([length(data1.t), 1]));
data1.type(data1.I > 0) = 'C';
data1.type(data1.I == 0) = 'R';
data1.type(data1.I < 0) = 'D';

% 스텝 구분
data1_length = length(data1.t);
data1.step = zeros(data1_length, 1);
m = 1;
data1.step(1) = m;
for j = 2:data1_length
    if data1.type(j) ~= data1.type(j-1)
        m = m + 1;
    end
    data1.step(j) = m;
end

vec_step = unique(data1.step);
num_step = length(vec_step);

data_line = struct('V', zeros(1, 1), 'I', zeros(1, 1), 't', zeros(1, 1), 'indx', zeros(1, 1), 'type', char('R'), ...
    'steptime', zeros(1, 1), 'T', zeros(1, 1), 'SOC', zeros(1, 1));
data = repmat(data_line, num_step, 1);

for i_step = 1:num_step
    range = find(data1.step == vec_step(i_step));
    data(i_step).V = data1.V(range);
    data(i_step).I = data1.I(range);
    data(i_step).t = data1.t(range);
    data(i_step).indx = range;
    data(i_step).type = data1.type(range(1));
    data(i_step).steptime = data1.t(range);
    data(i_step).T = zeros(size(range)); % 온도 데이터가 없으므로 0으로 설정
end

% Discharge step 구하기
step_chg = [];
step_dis = [];

for i = 1:length(data)
    if strcmp(data(i).type, 'C')
        step_chg(end+1) = i;
    elseif strcmp(data(i).type, 'D')
        step_dis(end+1) = i;
    end
end

% deltaV 및 평균 전류 계산
for i = 1 : length(data)
    if i == 1
       data(i).deltaV = zeros(size(data(i).V));
    else
       data(i).deltaV = data(i).V - data(i-1).V(end);
    end
    data(i).avgI = mean(data(i).I);
end

% 1RC 및 2RC 모델에서 최적화된 파라미터 로드
load('optimized_params_struct_final_1RC.mat'); % 변수: optimized_params_struct_final_1RC
load('optimized_params_struct_final_2RC.mat'); % 변수: optimized_params_struct_final_2RC

% 1RC 데이터에서 Crate 값 추출
Crate_values_1RC = [optimized_params_struct_final_1RC.Crate];

% Crate가 약 0.5인 인덱스 찾기
tolerance = 1e-2;
indices_05C = abs(Crate_values_1RC - 0.5) < tolerance;
indices = find(indices_05C);

% 해당하는 스텝 가져오기
steps_05C = step_dis(indices);

% 플로팅 설정
num_steps = length(indices);
plots_per_fig = 9; % 한 Figure에 9개의 subplot
num_figures = ceil(num_steps / plots_per_fig);
fig_counter = 1;
subplot_idx = 1;

figure(fig_counter);
set(gcf, 'Units', 'pixels', 'Position', [100, 100, 1200, 800]);
sgtitle('Comparison of Experimental Data, 1RC Model, and 2RC Model for 0.5C Rate', 'FontSize', titleFontSize);

for idx = 1:num_steps
    % 1RC 모델에서의 인덱스
    idx_1RC = indices(idx);
    % 2RC 모델에서는 idx 사용
    % 'data'에서의 스텝 인덱스
    step_idx = steps_05C(idx);
    
    % 새로운 Figure가 필요한지 확인
    if subplot_idx > plots_per_fig
        fig_counter = fig_counter + 1;
        figure(fig_counter);
        set(gcf, 'Units', 'pixels', 'Position', [100, 100, 1200, 800]);
        sgtitle('Comparison of Experimental Data, 1RC Model, and 2RC Model for 0.5C Rate', 'FontSize', titleFontSize);
        subplot_idx = 1;
    end
    
    % Subplot 생성
    subplot(3, 3, subplot_idx);
    hold on;
    
    % 실험 데이터 추출
    deltaV_exp = data(step_idx).deltaV;
    time_exp = data(step_idx).t - data(step_idx).t(1); % 시간 0부터 시작하도록 조정
    avgI = data(step_idx).avgI;
    
    % 1RC 모델의 최적화된 파라미터 추출
    R0_1RC = optimized_params_struct_final_1RC(idx_1RC).R0;
    R1_1RC = optimized_params_struct_final_1RC(idx_1RC).R1;
    C1_1RC = optimized_params_struct_final_1RC(idx_1RC).C;
    m_1RC = optimized_params_struct_final_1RC(idx_1RC).m;
    
    % 2RC 모델의 최적화된 파라미터 추출
    R0_2RC = optimized_params_struct_final_2RC(idx).R0;
    R1_2RC = optimized_params_struct_final_2RC(idx).R1;
    C1_2RC = optimized_params_struct_final_2RC(idx).C1;
    R2_2RC = optimized_params_struct_final_2RC(idx).R2;
    C2_2RC = optimized_params_struct_final_2RC(idx).C2;
    
    % 모델 전압 계산
    % 1RC 모델
    voltage_1RC = model_func_1RC(time_exp, R0_1RC, R1_1RC, C1_1RC, avgI);
    
    % 2RC 모델
    voltage_2RC = model_func_2RC(time_exp, R0_2RC, R1_2RC, R2_2RC, C1_2RC, C2_2RC, avgI);
    
    % 실험 데이터 플로팅
    plot(time_exp, deltaV_exp, 'Color', c_mat(3,:), 'LineWidth', lineWidth, 'DisplayName', 'Experiment ');
    
    % 1RC 모델 데이터 플로팅
    plot(time_exp, voltage_1RC, '--', 'Color', c_mat(1,:), 'LineWidth', lineWidth, 'DisplayName', '1RC ');
    
    % 2RC 모델 데이터 플로팅
    plot(time_exp, voltage_2RC, '--', 'Color', c_mat(2,:), 'LineWidth', lineWidth, 'DisplayName', '2RC ');
    
    % 제목 및 레이블 설정
    soc = optimized_params_struct_final_2RC(idx).SOC;
    crate = optimized_params_struct_final_2RC(idx).Crate;
    title(sprintf('SOC: %.2f%% , C-rate: %.2f', soc * 100, crate), 'FontSize', titleFontSize);
    xlabel('Time (sec)', 'FontSize', labelFontSize);
    ylabel('Voltage drop (V)', 'FontSize', labelFontSize);
    legend('Location', 'best', 'FontSize', legendFontSize);
    set(gca, 'FontSize', axisFontSize);
    grid on;
    
    hold off;
    
    subplot_idx = subplot_idx + 1;
end

% 모델 함수 정의
function voltage = model_func_1RC(time, R0, R1, C1, I)
    voltage = I * (R0 + R1 * (1 - exp(-time / (R1 * C1))));
end

function voltage = model_func_2RC(time, R0, R1, R2, C1, C2, I)
    voltage = I * (R0 + R1 * (1 - exp(-time / (R1 * C1))) + R2 * (1 - exp(-time / (R2 * C2))));
end
