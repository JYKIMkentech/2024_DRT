clc; clear; close all;

%% (0) 로드 경로 지정 및 파일 경로에서 제목 문자열 생성
loadPath = 'G:\공유 드라이브\BSL_Onori\Cycling_tests\Processed_3\W7.mat';
[folderPath, fileName, ~] = fileparts(loadPath);
[~, folderName] = fileparts(folderPath);
plotTitle = sprintf('%s_%s_UDDS', folderName, fileName);

%% (1) 데이터 로드 + 스텝 단위 분할
load(loadPath);

% (사용자 환경에 맞게 변수명 수정)
time       = t_full_vec_M1_NMC25degC;
curr       = I_full_vec_M1_NMC25degC;
volt       = V_full_vec_M1_NMC25degC;
step_arbin = Step_Index_full_vec_M1_NMC25degC;

% 구조체 (V, I, t, step)로 관리
data_raw.V    = volt;
data_raw.I    = curr;
data_raw.t    = time;
data_raw.step = step_arbin;

% step 변화 인덱스
change_indices = [1; find(diff(step_arbin) ~= 0)+1; length(step_arbin)+1];
num_segments   = length(change_indices) - 1;

% 기본 템플릿 (인덱스 없이)
data_line = struct('V', [], 'I', [], 't', [], 'step', [], 'time_reset', []);

data = repmat(data_line, num_segments, 1);
for i = 1:num_segments
    idx_start = change_indices(i);
    idx_end   = change_indices(i+1)-1;
    range     = idx_start:idx_end;
    
    data(i).V    = data_raw.V(range);
    data(i).I    = data_raw.I(range);
    data(i).t    = data_raw.t(range);
    data(i).step = data_raw.step(idx_start);
    data(i).time_reset = data(i).t - data(i).t(1);
end

