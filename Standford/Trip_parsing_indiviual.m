clc; clear; close all;

%% (0) 로드 경로 지정 및 파일 경로에서 제목 문자열 생성
loadPath = 'G:\공유 드라이브\BSL_Onori\Cycling_tests\Processed_1\W7.mat';
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

% 기본 템플릿( indx 없이 )
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

%% (2) 14번째 스텝 + 바로 앞 2개 스텝 => trips(1..3)
aging_cycle = 14;
indices_with_step14 = find([data.step] == aging_cycle);

if isempty(indices_with_step14)
    error('14번째 Aging cycle이 없습니다.');
end

first_index_14 = indices_with_step14(1);

if first_index_14 <= 2
    error('14번째 step 앞에 2개 step이 부족합니다.');
end

front_indices   = (first_index_14 - 2) : (first_index_14 - 1);
desired_indices = [front_indices, first_index_14];

% trips: 총 3개
trips = data(desired_indices);

%% (3) trips(1)+trips(2)+trips(3)을 이어붙여 음의 피크 찾기
t_total = vertcat(trips(:).t);
I_total = vertcat(trips(:).I);

minPeakHeight   = 4.0;    % |-4 A| 이상
minPeakDistance = 200;    % 최소 피크 간격
[negPeaks, locs] = findpeaks(-I_total, ...
    'MinPeakHeight',   minPeakHeight, ...
    'MinPeakDistance', minPeakDistance);
negPeaks = -negPeaks;  % 음수값

peakTimes  = t_total(locs);
peakValues = I_total(locs);

%% (4) 14번째 스텝(trips(3))만 홀수 피크 기반 세분화
t_start_14 = trips(3).t(1);
t_end_14   = trips(3).t(end);

% 14구간에 속하는 피크만 추출
in14_mask      = (peakTimes >= t_start_14) & (peakTimes <= t_end_14);
peakTimes_14   = peakTimes(in14_mask);
peakValues_14  = peakValues(in14_mask);

numPeaks_14 = length(peakTimes_14);
if numPeaks_14 < 2
    warning('14번째 구간 내 음의 피크 2개 미만 => 분할 불가, 그대로 사용');
    subTrips = trips(3);
else
    % (a) 홀수 피크 인덱스
    localPeakNo_14 = (1:numPeaks_14).';  %#ok<NASGU>
    odd_idx_14     = 1:2:numPeaks_14;
    odd_times_14   = peakTimes_14(odd_idx_14);

    % (b) 홀수 피크 간 시간차
    timeDiffs_14_odd = diff(odd_times_14);

    % (c) 경계시간 = t_start_14 + [0; cumsum(...)]
    boundaryTimes = t_start_14 + [0; cumsum(timeDiffs_14_odd)];
    % => 여기까지로 "홀수 피크들 사이" 구간이 형성됨

    % (d) 마지막 leftover (만약 boundaryTimes(end) < t_end_14)
    if boundaryTimes(end) < t_end_14
        boundaryTimes(end+1) = t_end_14;  % 마지막 구간(피크 이후~끝) 포함
    end

    num_subBound = length(boundaryTimes);

    % (e) subTrips(각 구간)
    template_sub = trips(3);
    template_sub.V = [];
    template_sub.I = [];
    template_sub.t = [];
    template_sub.time_reset = [];

    subTrips = repmat(template_sub, num_subBound-1, 1);

    for iSub = 1:(num_subBound - 1)
        tStart = boundaryTimes(iSub);
        tEnd   = boundaryTimes(iSub+1);

        % 범위(마지막은 <= 사용해도 됨)
        idxRange = (trips(3).t >= tStart) & (trips(3).t < tEnd);
        if (iSub == num_subBound - 1)
            % 마지막 구간은 [tStart <= t <= tEnd] 로 할 수도 있음
            idxRange = (trips(3).t >= tStart) & (trips(3).t <= tEnd);
        end

        subTrips(iSub).V = trips(3).V(idxRange);
        subTrips(iSub).I = trips(3).I(idxRange);
        subTrips(iSub).t = trips(3).t(idxRange);

        if ~isempty(subTrips(iSub).t)
            subTrips(iSub).time_reset = subTrips(iSub).t - subTrips(iSub).t(1);
        else
            subTrips(iSub).time_reset = [];
        end
    end
end

%% (5) 최종 trips = [ trips(1:2); subTrips ]
if isstruct(subTrips)
    trips = [trips(1:2); subTrips];
else
    % 혹시 subTrips가 빈 경우 대비
    trips = [trips(1:2); subTrips];
end

% 확인
disp('=== 최종 trips 정보 ===');
for k = 1:length(trips)
    fprintf('Trip%d: t=%.2f ~ %.2f, length=%d\n', ...
        k, min(trips(k).t), max(trips(k).t), length(trips(k).t));
end

%% (6) 플롯: 전체 파란색 + 음의 피크 빨간색 + Trip 경계 검정 점선
figure('Name','Final UDDS Parsing','Color','w');
plot(t_total, I_total, 'b'); 
hold on; grid on;

% 음의 피크 표시
plot(peakTimes, peakValues, 'ro', 'MarkerSize',8, 'LineWidth',1.5);

xlabel('시간 (s)');
ylabel('전류 (A)');
title(plotTitle, 'Interpreter','none');

% Trip 경계 (trips(i).t(1) 위치)
YL = ylim;
for iTrip = 3:length(trips)
    x_val = trips(iTrip).t(1);
    xline(x_val, 'k--', 'LineWidth',1.5);

    % Trip라벨을 위쪽에
    % Trip 라벨을 조금 오른쪽으로 이동
    shift_x = 1300;  % 50초 정도 오른쪽으로 (필요에 따라 조정)
    x_text  = x_val + shift_x;
    y_text  = YL(2)*0.95;
    
    text(x_text, y_text, sprintf('Trip%d', iTrip-2), ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','top', ...
        'FontSize',9, 'Color','k', 'FontWeight','bold');

end

%legend({'전체 전류','음의 피크'}, 'Location','best');
hold off;

