clc; clear; close all;

% 72가 chgOCV step
% 100 부터 주행부하1 시작
% 125 부터 주행부하2 시작
% 742 부터 RPT2 시작 

%% 1) 데이터 불러오기
% cell_059_data.mat을 불러와서 'data' 라는 구조체 배열이 있다고 가정
load('G:\공유 드라이브\BSL_WC\cell_059_data.mat'); 

%% 2) 각 스텝별 평균 전류(avgI) 계산
nSteps = numel(data);  % 스텝 개수
for i = 1:nSteps
    % 각 스텝에 대한 평균 전류
    data(i).avgI = mean(data(i).current);
end

%% 3) OCV 스텝 찾기
% 기준값과 허용오차 설정 (필요에 따라 수정)
target    = 0.025;   % 목표 전류(OCV 스텝 기준)
tolerance = 0.0001;  % 허용 오차

ocvIdx = [];  % OCV 스텝 인덱스 저장용
for i = 1:nSteps
    if abs(data(i).avgI - target) < tolerance
        ocvIdx(end+1) = i; %#ok<SAGROW>
    end
end

%% 4) marker 필드 생성: 기본값 = [], OCV 스텝 = 0
% 구조체 배열에 'marker' 필드 추가/초기화
[data.marker] = deal([]);
if ~isempty(ocvIdx)
    for iOCV = ocvIdx
        data(iOCV).marker = 0;
    end
end

%% 5) 첫 번째 OCV 스텝을 실선 그래프로 표시 (마커 없이)
if ~isempty(ocvIdx)
    firstOCVstep = ocvIdx(1);  % 첫 번째로 찾아진 OCV 스텝 번호
    
    % 그래프 생성
    figure('Name','First OCV Step (Line Only)');
    
    % (1) 전류
    yyaxis left
    plot(data(firstOCVstep).time, data(firstOCVstep).current, ...
         '-', 'LineWidth', 0.5, 'Color','b');   % 실선 스타일
    ylabel('Current (A)');

    % (2) 전압
    yyaxis right
    plot(data(firstOCVstep).time, data(firstOCVstep).voltage, ...
         '-', 'LineWidth', 0.5, 'Color','r');   % 실선 스타일
    ylabel('Voltage (V)');

    % 기타 표시
    xlabel('Time');
    title(sprintf('First OCV Step: Step #%d (avgI = %.5f A)', ...
        firstOCVstep, data(firstOCVstep).avgI));
    grid on;
else
    warning('OCV 스텝(전류=%.4f ± %.4f A)를 만족하는 스텝이 없습니다.', ...
            target, tolerance);
end
