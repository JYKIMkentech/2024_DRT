clc; clear; close all;

% 1. 셀 리스트 정의 (원하는 순서)
cell_list = {'W3','W4','W5','W7','W8','W9','W10','G1','V4','V5'};

% 2. 기본 경로 지정
base_path = 'G:\공유 드라이브\BSL_Onori\Cycling_tests';

% 3. 결과를 담을 구조체 초기화
DRT_input = struct('cell_name',{}, ...
                   'cycle_number',{}, ...
                   'Trips',{}, ...
                   'OCV',{}, ...
                   'Q_OCV',{}, ...
                   'Driving_high_SOC',{}, ...
                   'DRT_high_SOC',{}, ...
                   'Driving_mid_SOC',{}, ...
                   'DRT_mid_SOC',{}, ...
                   'Driving_low_SOC',{}, ...
                   'DRT_low_SOC',{}, ...
                   'DRT_feature',{});

% 4. Processed_1 ~ Processed_14 폴더를 순회
count = 0;
for cycle_idx = 1:14
    
    folder_name = sprintf('Processed_%d', cycle_idx);
    folder_path = fullfile(base_path, folder_name);
    
    % 폴더 안의 .mat 파일 정보를 읽는다
    mat_info = dir(fullfile(folder_path,'*.mat'));
    
    % 파일명에서 확장자를 제외한 부분만 추출
    mat_names_no_ext = cell(size(mat_info));
    for k = 1:numel(mat_info)
        [~, fname, ~] = fileparts(mat_info(k).name); 
        mat_names_no_ext{k} = fname;
    end
    
    % cell_list와 교집합되는 파일(즉, 존재하는 셀 이름) 찾기
    present_cells = intersect(cell_list, mat_names_no_ext);
    
    % 존재하는 셀마다 빈 구조체 엔트리 추가
    for c = 1:numel(present_cells)
        count = count + 1;
        
        DRT_input(count).cell_name        = present_cells{c};
        DRT_input(count).cycle_number     = cycle_idx;
        DRT_input(count).Trips            = [];
        DRT_input(count).OCV              = [];
        DRT_input(count).Q_OCV            = [];
        DRT_input(count).Driving_high_SOC = [];
        DRT_input(count).DRT_high_SOC     = [];
        DRT_input(count).Driving_mid_SOC  = [];
        DRT_input(count).DRT_mid_SOC      = [];
        DRT_input(count).Driving_low_SOC  = [];
        DRT_input(count).DRT_low_SOC      = [];
        DRT_input(count).DRT_feature      = [];
    end
end

%% 5. 만든 구조체를 cell_list 순서대로 정렬
%    - 먼저 구조체의 cell_name을 이용해 cell_list에서의 위치(인덱스)를 구한다
%    - 그 다음 cycle_number를 기준으로 2차 정렬하여 같은 셀 내에서는 사이클순 오름차순
all_cell_names = {DRT_input.cell_name};         % 구조체에서 추출한 cell_name들
all_cycles     = [DRT_input.cycle_number];      % 구조체에서 추출한 cycle_number

% cell_list에서의 위치 인덱스를 구한다 (ismember와 유사)
[~, idx_in_list] = ismember(all_cell_names, cell_list);

% 2열짜리 행렬 [셀인덱스, 사이클번호]로 sortrows
[~, sorted_idx] = sortrows([idx_in_list(:), all_cycles(:)]);

% 정렬 적용
DRT_input = DRT_input(sorted_idx);

% 결과 확인
disp(DRT_input);
