clc; clear; close all;

%% ========== (A) 셀 리스트 및 기본 경로 설정 ==========

cell_list = {'W3','W4','W5','W7','W8','W9','W10','G1','V4','V5'};
base_path = 'G:\공유 드라이브\BSL_Onori\Cycling_tests';


%% ========== (B) DRT_input 구조체 생성 ==========

% 기존 'Trips'라는 필드 대신, Trips_1 ~ Trips_10 각 필드를 미리 정의
DRT_input = struct( ...
    'cell_name', {}, ...
    'cycle_number', {}, ...
    'Trips_1', {}, ...
    'Trips_2', {}, ...
    'Trips_3', {}, ...
    'Trips_4', {}, ...
    'Trips_5', {}, ...
    'Trips_6', {}, ...
    'Trips_7', {}, ...
    'Trips_8', {}, ...
    'Trips_9', {}, ...
    'Trips_10', {}, ...
    'OCV', {}, ...
    'Q_OCV', {}, ...
    'Driving_high_SOC', {}, ...
    'DRT_high_SOC', {}, ...
    'Driving_mid_SOC', {}, ...
    'DRT_mid_SOC', {}, ...
    'Driving_low_SOC', {}, ...
    'DRT_low_SOC', {}, ...
    'DRT_feature', {});

count = 0;

% 최대 cycle 14까지 순회
for cycle_idx = 1:14
    folder_name = sprintf('Processed_%d', cycle_idx);
    folder_path = fullfile(base_path, folder_name);
    
    % 폴더 안의 *.mat 파일 목록
    mat_info = dir(fullfile(folder_path, '*.mat'));
    
    % 파일명(확장자 제외)만 추출
    mat_names_no_ext = cell(size(mat_info));
    for k = 1:numel(mat_info)
        [~, fname, ~] = fileparts(mat_info(k).name);
        mat_names_no_ext{k} = fname;
    end
    
    % cell_list와 교집합되는 파일(존재하는 셀)만 골라냄
    present_cells = intersect(cell_list, mat_names_no_ext);
    
    % 존재하는 셀마다 구조체 엔트리 생성
    for c = 1:numel(present_cells)
        count = count + 1;
        
        DRT_input(count).cell_name    = present_cells{c};
        DRT_input(count).cycle_number = cycle_idx;
        
        % Trips_1~Trips_10 필드를 빈 배열로 초기화
        for tnum = 1:10
            fieldName = sprintf('Trips_%d', tnum);
            DRT_input(count).(fieldName) = []; 
        end
        
        % OCV/Q_OCV 등 필요한 나머지 필드도 초기화
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


%% ========== (C) cell_list 순서 + cycle_number 순서로 정렬 ==========

all_cell_names = {DRT_input.cell_name};
all_cycles     = [DRT_input.cycle_number];

[~, idx_in_list] = ismember(all_cell_names, cell_list);
[~, sorted_idx]  = sortrows([idx_in_list(:), all_cycles(:)]);

DRT_input = DRT_input(sorted_idx);


%% ========== (D) 실제 파일 로드 및 UDDS 파싱 => Nx3 double로 변환해서 저장 ==========

for i = 1:length(DRT_input)
    cyc       = DRT_input(i).cycle_number;
    cell_name = DRT_input(i).cell_name;
    
    folder_name = sprintf('Processed_%d', cyc);
    mat_path    = fullfile(base_path, folder_name, sprintf('%s.mat', cell_name));
    
    if exist(mat_path, 'file')
        % 1) 파일 로드
        load(mat_path, '-mat');  
        %   여기서 t_full_vec_M1_NMC25degC, I_full_vec_M1_NMC25degC, ...
        %   V_full_vec_M1_NMC25degC, Step_Index_full_vec_M1_NMC25degC 등이 있다고 가정
        
        % 2) UDDS 파싱
        time      = t_full_vec_M1_NMC25degC;
        curr      = I_full_vec_M1_NMC25degC;
        volt      = V_full_vec_M1_NMC25degC;
        step_arbi = Step_Index_full_vec_M1_NMC25degC;
        
        trips_parsed = parseUDDS(time, curr, volt, step_arbi);
        % trips_parsed는 (N×1 struct), 각 element에 .t, .I, .V, .time_reset, .step 등이 있음
        
        % 3) 최대 10개 트립만 Nx3 double로 변환하여 DRT_input(i)에 저장
        maxTrips = 10;
        nSub     = length(trips_parsed);
        
        for j = 1:maxTrips
            fieldName = sprintf('Trips_%d', j);
            
            if j <= nSub
                % [t, I, V] 열벡터로 만듦 => Nx3
                t_j = trips_parsed(j).t(:);
                I_j = trips_parsed(j).I(:);
                V_j = trips_parsed(j).V(:);
                
                data_j = [t_j, I_j, V_j];   % Nx3
            else
                data_j = [];               % 존재 안 하면 빈 배열
            end
            
            DRT_input(i).(fieldName) = data_j;
        end
        
        % (필요하다면 여기서 OCV, Q_OCV 등 다른 분석도 수행 후 저장)
        
    else
        warning('파일이 존재하지 않습니다: %s', mat_path);
    end
end


%% ========== (E) 최종 DRT_input2.mat로 저장 ==========

save_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\Stanford_DRT';
save(fullfile(save_path, 'DRT_input.mat'), 'DRT_input', '-v7.3');

disp('=== 모든 셀/사이클 파싱 완료 & DRT_input2.mat 저장 완료 ===');


%% ========== 부록: UDDS 파싱 함수 (이전과 동일) ==========

function trips = parseUDDS(time, curr, volt, step_arbin)
    %{
      parseUDDS 함수: UDDS 파싱하여 trips라는 N×1 struct 배열을 반환
      각 요소: .t, .I, .V, .step, .time_reset 등
      (아래는 질문에서 제시된 코드를 그대로 함수화한 예시입니다.)
    %}
    
    % -------------------------------
    % 1) 구조체 및 step 구간 분할
    % -------------------------------
    data_raw.V    = volt;
    data_raw.I    = curr;
    data_raw.t    = time;
    data_raw.step = step_arbin;

    change_indices = [1; find(diff(step_arbin) ~= 0)+1; length(step_arbin)+1];
    num_segments   = length(change_indices) - 1;
    
    data_line = struct('V', [], 'I', [], 't', [], 'step', [], 'time_reset', []);
    data = repmat(data_line, num_segments, 1);
    
    for iSeg = 1:num_segments
        idx_start = change_indices(iSeg);
        idx_end   = change_indices(iSeg+1)-1;
        range     = idx_start:idx_end;
        
        data(iSeg).V    = data_raw.V(range);
        data(iSeg).I    = data_raw.I(range);
        data(iSeg).t    = data_raw.t(range);
        data(iSeg).step = data_raw.step(idx_start);
        data(iSeg).time_reset = data(iSeg).t - data(iSeg).t(1);
    end
    
    % -------------------------------
    % 2) 14번째 스텝 + 바로 앞 2개 스텝 => trips(1..3)
    % -------------------------------
    aging_cycle = 14;
    indices_with_step14 = find([data.step] == aging_cycle);
    if isempty(indices_with_step14)
        % 14번째 구간이 없다면 그대로 data 전체를 반환
        trips = data;
        return;
    end
    
    first_index_14 = indices_with_step14(1);
    if first_index_14 <= 2
        % 14번째 step 앞에 2개 step이 없다면 그대로 반환
        trips = data;
        return;
    end
    
    front_indices   = (first_index_14 - 2) : (first_index_14 - 1);
    desired_indices = [front_indices, first_index_14];
    
    trips_3 = data(desired_indices);
    
    % -------------------------------
    % 3) trips(1)+trips(2)+trips(3)에서 음의 피크 탐색
    % -------------------------------
    t_total = vertcat(trips_3(:).t);
    I_total = vertcat(trips_3(:).I);
    
    minPeakHeight   = 4.0;
    minPeakDistance = 200;
    [negPeaks, locs] = findpeaks(-I_total, ...
        'MinPeakHeight',   minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    negPeaks = -negPeaks;  % 실제 음수 값
    
    peakTimes  = t_total(locs);
    peakValues = I_total(locs);
    
    % -------------------------------
    % 4) 14번째 스텝(trips(3)) 내에서 홀수 피크 기반 세분화
    % -------------------------------
    t_start_14 = trips_3(3).t(1);
    t_end_14   = trips_3(3).t(end);
    
    in14_mask     = (peakTimes >= t_start_14) & (peakTimes <= t_end_14);
    peakTimes_14  = peakTimes(in14_mask);
    peakValues_14 = peakValues(in14_mask);
    
    numPeaks_14 = length(peakTimes_14);
    if numPeaks_14 < 2
        % 피크가 2개 미만이면 분할 없이 사용
        subTrips = trips_3(3);
    else
        % (a) 홀수 피크 인덱스
        odd_idx_14   = 1:2:numPeaks_14;
        odd_times_14 = peakTimes_14(odd_idx_14);
        
        % (b) 홀수 피크 간 시간차
        timeDiffs_14_odd = diff(odd_times_14);
        
        % (c) 경계시간 = t_start_14 + [0; cumulative sum]
        boundaryTimes = t_start_14 + [0; cumsum(timeDiffs_14_odd)];
        if boundaryTimes(end) < t_end_14
            boundaryTimes(end+1) = t_end_14;
        end
        
        % (d) 서브 트립 구간 분할
        template_sub = trips_3(3);
        template_sub.V = [];
        template_sub.I = [];
        template_sub.t = [];
        template_sub.time_reset = [];
        
        num_subBound = length(boundaryTimes);
        subTrips = repmat(template_sub, num_subBound-1, 1);
        
        for iSub = 1:(num_subBound - 1)
            tStart = boundaryTimes(iSub);
            tEnd   = boundaryTimes(iSub+1);

            idxRange = (trips_3(3).t >= tStart) & (trips_3(3).t < tEnd);
            if iSub == (num_subBound - 1)
                idxRange = (trips_3(3).t >= tStart) & (trips_3(3).t <= tEnd);
            end
            
            subTrips(iSub).V = trips_3(3).V(idxRange);
            subTrips(iSub).I = trips_3(3).I(idxRange);
            subTrips(iSub).t = trips_3(3).t(idxRange);
            
            if ~isempty(subTrips(iSub).t)
                subTrips(iSub).time_reset = subTrips(iSub).t - subTrips(iSub).t(1);
            else
                subTrips(iSub).time_reset = [];
            end
        end
    end
    
    % -------------------------------
    % 5) 최종 trips = [ trips(1:2); subTrips ]
    % -------------------------------
    trips = [trips_3(1:2); subTrips];
end
