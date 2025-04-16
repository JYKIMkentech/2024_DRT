clc; clear; close all;

%% 1) 데이터 로드
load('G:\공유 드라이브\BSL_WC\cell_059_data.mat');
nSteps = numel(data);

%% 2) 배터리 용량(5000mAh=5Ah) 가정하고 C-rate → 실제 전류[A] 변환
Capacity_Ah = 5;  % 5000mAh
for i = 1:nSteps
    % 만약 data(i).current가 'C-rate' 단위라면: 실제 전류[A] = current * Capacity_Ah
    data(i).I = data(i).current * Capacity_Ah;
end

%% 3) 스텝별 평균 전류(avgI) 계산
for i = 1:nSteps
    data(i).avgI = mean(data(i).I);  % 실제 전류 I의 평균
end

%% 4) (옵션) OCV 스텝 찾기 & SoC–OCV 계산
% 예) 방전 OCV 스텝은 -0.025C 근처(= -0.125A)로 가정
target    = -0.025;
tolerance = 0.0001;
ocvIdx = [];

for i = 1:nSteps
    if abs(data(i).avgI - (target * Capacity_Ah)) < tolerance
        ocvIdx(end+1) = i; %#ok<SAGROW>
    end
end

% marker 필드 초기화 후 OCV 스텝에만 1 부여
[data.marker] = deal([]);
for iOCV = ocvIdx
    data(iOCV).marker = 1;
end

% SoC–OCV 계산 예시
soc_ocv_cell = cell(numel(ocvIdx), 1);
for k = 1:numel(ocvIdx)
    iStep = ocvIdx(k);

    t = data(iStep).time;      % [s]
    I = data(iStep).I;         % [A]
    v = data(iStep).voltage;   % [V]

    % 전류 적분(A·s). (Ah 단위 필요하면 /3600)
    Q = cumtrapz(t, I);
    Qend = Q(end);

    % 방전 스텝 가정 → SoC = 1 - Q/Qend
    SoC = 1 - Q/Qend;

    % SoC–OCV 구성
    soc_ocv_cell{k} = [SoC(:), v(:)];
end

% (옵션) SoC–OCV 그래프
figure('Name','SoC–OCV Plot'); hold on;
for k = 1:length(soc_ocv_cell)
    plot(soc_ocv_cell{k}(:,1), soc_ocv_cell{k}(:,2), ...
         'DisplayName', sprintf('OCV Step %d', ocvIdx(k)));
end
xlabel('SoC'); ylabel('OCV [V]');
title('SoC vs OCV (All OCV Steps)');
legend('show'); grid on;
hold off;

%% 5) 드라이빙 스텝 탐색 (조건: length(state)>1 & step=7 or 9)
drivingIdx = [];
for i = 1:nSteps
    data(i).driving_marker = [];  % 초기화
    
    if (length(data(i).state) > 1) && ismember(data(i).step, [7, 9])
        data(i).driving_marker = 2;
        drivingIdx(end+1) = i; %#ok<SAGROW>
    end
end
drivingIdx = drivingIdx';  % 확인용

%% 6) 전체 전류 파형 그래프 + 드라이빙 스텝 "최대 전류 지점" 표시
% (a) 전체 전류 파형(파란색 실선)
t_all = vertcat(data(:).time);
I_all = vertcat(data(:).I);

figure('Name','Full I vs. Time');
plot(t_all, I_all, 'b-');
hold on; grid on;
xlabel('Time [s]'); ylabel('Current [A]');
title('Full Current (blue) + Driving Step Max Current (red o)');

% (b) 드라이빙 스텝 중 "I의 최댓값" 지점만 빨간 원으로 표시
t_driveMax = [];
I_driveMax = [];

for i = 1:nSteps
    if ~isempty(data(i).driving_marker) && (data(i).driving_marker == 2)
        % 최대 전류 및 그 인덱스
        [maxVal, idxMax] = max(data(i).I);
        
        t_driveMax(end+1,1) = data(i).time(idxMax);
        I_driveMax(end+1,1) = maxVal;
    end
end

plot(t_driveMax, I_driveMax, 'ro', 'MarkerSize',8, 'LineWidth',1.2);
legend('All Data','Driving Step Max Current','Location','best');
hold off;

%% 7) 드라이빙 스텝 "cycle"별로 묶어서 Parsing
% (a) drivingIdx에 해당하는 cycle 목록
drivingCycles = arrayfun(@(x) data(x).cyc, drivingIdx);  % ex) [3;3;3;3;30;30; ...]
uniqueCycles  = unique(drivingCycles);                   % ex) [3; 30; 31; ...]

% (b) cycle별로 드라이빙 스텝 인덱스 묶음 저장
drivingGroups = cell(numel(uniqueCycles),1);
for c = 1:numel(uniqueCycles)
    cycVal = uniqueCycles(c);  % 특정 cycle번호
    % 이 cycle에 해당하는 드라이빙 스텝만 추출
    idxThisCycle = drivingIdx(drivingCycles == cycVal);
    
    drivingGroups{c} = idxThisCycle;
end

% [원한다면 cycle과 함께 구조체로 저장할 수도 있음]
% 예) cycleDataGroups(c).cycID = cycVal;
%     cycleDataGroups(c).stepIdx = idxThisCycle;
%     cycleDataGroups(c).stepData = data(idxThisCycle);

%% 8) (옵션) 결과 저장
save('soc_ocv_table.mat', 'soc_ocv_cell');



