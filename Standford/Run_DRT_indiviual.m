clear; clc; close all;

% (1) 데이터 불러오기
load('G:\공유 드라이브\Battery Software Lab\Projects\DRT\Stanford_DRT\DRT_input.mat'); 
% -> DRT_input라는 변수(구조체 배열)가 있다고 가정

load('G:\공유 드라이브\BSL_Onori\Diagnostic_tests\_processed_mat\capacity_test.mat'); 
% -> cap, vcell 등이 있다고 가정

% (2) 셀 이름과 열(column) 인덱스를 매핑
cellMap = {'W3','W4','W5','W7','W8','W9','W10','G1','V4','V5'};

% (3) DRT_input 순회하면서 OCV/Q_OCV 채워넣기
for i = 1:length(DRT_input)
    % (a) 이 구조체 요소의 셀 이름 / 사이클 번호
    thisCell  = DRT_input(i).cell_name;    % 예: 'W3'
    thisCycle = DRT_input(i).cycle_number; % 예: 2
    
    % (b) cellMap에서 몇 번째 열인지 찾기
    cIdx = find(strcmp(cellMap, thisCell));
    
    % 해당 셀 이름이 cellMap에 없다면 건너뜀
    if isempty(cIdx)
        fprintf('Cell name "%s"를 cellMap에서 찾을 수 없습니다.\n', thisCell);
        DRT_input(i).OCV   = [];
        DRT_input(i).Q_OCV = NaN;
        continue
    end
    
    % 사이클 번호가 cap, vcell 크기를 넘어가면 건너뜀(에러 방지)
    if thisCycle > size(cap, 1)
        fprintf('Cycle number %d가 cap/vcell 범위를 초과합니다. (cell: %s)\n', thisCycle, thisCell);
        DRT_input(i).OCV   = [];
        DRT_input(i).Q_OCV = NaN;
        continue
    end

    % (c) cap, vcell에서 데이터 추출
    capArray = cap{thisCycle, cIdx};
    vArray   = vcell{thisCycle, cIdx};
    
    % 만약 데이터가 비어있거나 NaN으로만 되어 있으면 건너뜀
    if isempty(capArray) || all(isnan(capArray))
        fprintf('capArray가 비어있거나 NaN입니다. (cell: %s, cycle: %d)\n', thisCell, thisCycle);
        DRT_input(i).OCV   = [];
        DRT_input(i).Q_OCV = NaN;
        continue
    end
    
    % (d) Q_OCV는 capArray의 마지막 값
    Q_OCV = capArray(end);
    
    % (e) SOC와 OCV 생성
    SOC = 1 - capArray / Q_OCV;    % (N x 1) 형태
    OCV = [SOC, vArray];       % (N x 2) -> [SOC, 전압]
    
    % (f) 구조체에 저장
    DRT_input(i).OCV   = OCV;
    DRT_input(i).Q_OCV = Q_OCV;
end

% (4) 결과를 다시 mat 파일로 저장 (필요 시)
save('G:\공유 드라이브\Battery Software Lab\Projects\DRT\Stanford_DRT\DRT_input_OCV.mat', 'DRT_input');
